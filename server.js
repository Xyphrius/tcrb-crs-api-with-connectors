require('./instrument.js');
// server.js
require('dotenv').config();
const app = require('./src/app'); // your express app module

// --- Sentry ---
const Sentry = require('@sentry/node');
const { nodeProfilingIntegration } = require('@sentry/profiling-node');
Sentry.init({
  dsn: process.env.SENTRY_DSN || undefined,
  tracesSampleRate: 0.1,            // adjust as needed
  profilesSampleRate: 0.1,          // optional profiling
  integrations: [nodeProfilingIntegration()],
  environment: process.env.NODE_ENV || 'development'
});

// --- Request ID + logging ---
const { v4: uuidv4 } = require('uuid');
const pino = require('pino');
const pinoHttp = require('pino-http');

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });
const httpLogger = pinoHttp({
  genReqId: (req, res) => {
    const hdr = req.headers['x-request-id'];
    const id = hdr && String(hdr).trim() ? hdr : uuidv4();
    res.setHeader('x-request-id', id);
    return id;
  },
  customProps: (req) => ({
    requestId: req.id,
  }),
  serializers: {
    req(req) { return { method: req.method, url: req.url, id: req.id }; },
    res(res) { return { statusCode: res.statusCode }; }
  },
  logger
});
app.use(httpLogger);

// make request id accessible in handlers
app.use((req, _res, next) => {
  req.requestId = req.id;
  Sentry.setTag('request_id', req.id);
  next();
});

// --- Security middleware ---
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
app.use(helmet());
app.use(rateLimit({ windowMs: 60 * 1000, max: 100 }));

// --- DB Pool ---
const { Pool } = require('pg');
const pool = new Pool({
  host: process.env.PGHOST,
  port: process.env.PGPORT,
  database: process.env.PGDATABASE,
  user: process.env.PGUSER,
  password: process.env.PGPASSWORD,
});

// --- Routes ---
const Joi = require('joi');

// Get product score endpoint
app.get('/v1/products/:id/score', async (req, res) => {
  const schema = Joi.object({ id: Joi.string().required() });
  const { error } = schema.validate(req.params);
  if (error) return res.status(400).json({ error: error.details[0].message });
  try {
    const { id } = req.params;
    const query = `
      SELECT 
        s.product_id,
        s.crs,
        s.confidence,
        s.reason_codes,
        s.feature_vector,
        s.version,
        s.computed_at,
        p.name as product_name,
        p.brand_id,
        b.name as brand_name
      FROM scores s
      JOIN products p ON s.product_id = p.id
      JOIN brands b ON p.brand_id = b.id
      WHERE s.product_id = $1
      ORDER BY s.computed_at DESC
      LIMIT 1
    `;
    const result = await pool.query(query, [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ 
        error: 'Product score not found',
        product_id: id 
      });
    }
    const score = result.rows[0];
    res.json({
      product_id: score.product_id,
      product_name: score.product_name,
      brand_name: score.brand_name,
      crs_score: parseFloat(score.crs),
      confidence: parseFloat(score.confidence),
      reason_codes: score.reason_codes,
      feature_vector: score.feature_vector,
      version: score.version,
      scored_at: score.computed_at
    });
  } catch (err) {
    logger.error({ err }, 'Error fetching product score');
    res.status(500).json({ error: 'Internal server error', message: err.message });
  }
});

// Get all products with scores
app.get('/v1/products', async (req, res) => {
  try {
    const query = `
      SELECT 
        p.id,
        p.name,
        p.category,
        p.strain,
        b.name as brand_name,
        s.crs,
        s.confidence
      FROM products p
      JOIN brands b ON p.brand_id = b.id
      LEFT JOIN scores s ON p.id = s.product_id
      ORDER BY p.name
    `;
    const result = await pool.query(query);
    res.json({
      products: result.rows.map(row => ({
        id: row.id,
        name: row.name,
        category: row.category,
        subcategory: row.strain,
        brand_name: row.brand_name,
        crs_score: row.crs ? parseFloat(row.crs) : null,
        confidence: row.confidence ? parseFloat(row.confidence) : null
      }))
    });
  } catch (err) {
    logger.error({ err }, 'Error fetching products');
    res.status(500).json({ error: 'Internal server error', message: err.message });
  }
});

// /metrics – lightweight JSON (safe for healthchecks)
app.get('/metrics', (_req, res) => {
  const m = process.memoryUsage();
  res.json({
    timestamp: new Date().toISOString(),
    uptime_seconds: Math.round(process.uptime()),
    memory: {
      rss_mb: +(m.rss / 1024 / 1024).toFixed(2),
      heap_used_mb: +(m.heapUsed / 1024 / 1024).toFixed(2),
      heap_total_mb: +(m.heapTotal / 1024 / 1024).toFixed(2),
      external_mb: +(m.external / 1024 / 1024).toFixed(2)
    },
    node_version: process.version,
    environment: process.env.NODE_ENV || 'development'
  });
});

// (Optional Prometheus text variant:)
app.get('/metrics/prom', (_req, res) => {
  const m = process.memoryUsage();
  res.set('Content-Type', 'text/plain; version=0.0.4');
  res.send(
`process_uptime_seconds ${Math.round(process.uptime())}
process_memory_rss_bytes ${m.rss}
process_memory_heap_used_bytes ${m.heapUsed}
process_memory_heap_total_bytes ${m.heapTotal}
app_info{node_version="${process.version}",env="${process.env.NODE_ENV||'development'}"} 1
`);
});

// Sentry error handler (must be before any custom error handler)
Sentry.setupExpressErrorHandler(app);

// Optional: your error handler
app.use((err, _req, res, _next) => {
  logger.error({ err }, 'Unhandled error');
  res.status(500).json({ error: 'internal_error' });
});

// Graceful shutdown
process.on('SIGINT', async () => {
  logger.info('Shutting down gracefully...');
  await pool.end();
  process.exit(0);
});

// Startup logs
const port = process.env.PORT || 8080;
const server = app.listen(port, () => {
  const base = `http://localhost:${port}`;
  logger.info(`TCRB CRS API server running on port ${port}`);
  logger.info(`Health check: ${base}/health`);
  logger.info(`Metrics:     ${base}/metrics`);
  logger.info(`Prometheus:  ${base}/metrics/prom`);
  logger.info(`Products:    ${base}/v1/products`);
  logger.info(`Product score: ${base}/v1/products/:id/score`);
});
