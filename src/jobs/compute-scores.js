// src/jobs/compute-scores.js
const { Pool } = require('pg');

function score(features) {
  // trivial scoring until you wire the real kernel
  const crs = Math.max(0, Math.min(100, 80 + (Math.random()*10 - 5)));
  const conf = 0.7 + Math.random()*0.2;
  return { crs: Number(crs.toFixed(2)), confidence: Number(conf.toFixed(2)), reason_codes: ['DATA_OK'], version: '1.0.0' };
}

(async () => {
  const pool = new Pool({ 
    user: process.env.PGUSER || 'postgres', 
    host: process.env.PGHOST || 'localhost', 
    database: process.env.PGDATABASE || 'tcrb', 
    password: process.env.PGPASSWORD || 'postgres', 
    port: process.env.PGPORT || 5433 
  });
  const client = await pool.connect();
  try {
    const { rows: prods } = await client.query(`select id from products limit 50`);
    for (const p of prods) {
      const s = score({});
      await client.query(
        `insert into scores(product_id, crs, confidence, reason_codes, feature_vector, version)
         values ($1,$2,$3,$4,$5,$6)`,
        [p.id, s.crs, s.confidence, s.reason_codes, { mock: true }, s.version]
      );
    }
    console.log(`Scored ${prods.length} products`);
  } finally {
    client.release();
    await pool.end();
  }
})();
