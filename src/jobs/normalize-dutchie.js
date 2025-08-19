const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.PGUSER || 'postgres',
  host: process.env.PGHOST || 'localhost',
  database: process.env.PGDATABASE || 'tcrb',
  password: process.env.PGPASSWORD || 'password',
  port: process.env.PGPORT || 5432,
});

async function normalizeDutchie() {
  const client = await pool.connect();
  
  try {
    console.log('Starting Dutchie normalization...');
    
    // Get all staging records
    const { rows } = await client.query('SELECT id, payload FROM staging_sources WHERE source = $1', ['dutchie']);
    
    let count = 0;
    for (const row of rows) {
      const p = row.payload;
      
      // Upsert brand
      const brandId = await upsertBrand(client, p.brand);
      
      // Upsert dispensary  
      const dispensaryId = await upsertDispensary(client, p.dispensary);
      
      // Upsert product
      const productId = await upsertProduct(client, p, brandId, dispensaryId);
      
      // Upsert listing
      await upsertListing(client, productId, dispensaryId);
      
      count++;
    }
    
    console.log(`Normalized ${count} dutchie rows`);
    
  } finally {
    client.release();
    await pool.end();
  }
}

async function upsertBrand(client, brandName) {
  const result = await client.query(
    'INSERT INTO brands (name) VALUES ($1) ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name RETURNING id',
    [brandName]
  );
  return result.rows[0].id;
}

async function upsertDispensary(client, dispensaryName) {
  const result = await client.query(
    'INSERT INTO dispensaries (name) VALUES ($1) ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name RETURNING id',
    [dispensaryName]
  );
  return result.rows[0].id;
}

async function upsertProduct(client, payload, brandId, dispensaryId) {
  const result = await client.query(
    'INSERT INTO products (name, category, subcategory, brand_id, external_refs) VALUES ($1, $2, $3, $4, $5) ON CONFLICT (name, brand_id) DO UPDATE SET category = EXCLUDED.category, subcategory = EXCLUDED.subcategory, external_refs = EXCLUDED.external_refs RETURNING id',
    [payload.name, payload.category, payload.subcategory, brandId, JSON.stringify({ dutchie_id: payload.id })]
  );
  return result.rows[0].id;
}

async function upsertListing(client, productId, dispensaryId) {
  await client.query(
    'INSERT INTO listings (product_id, dispensary_id, price, available, external_refs) VALUES ($1, $2, $3, $4, $5) ON CONFLICT (product_id, dispensary_id) DO UPDATE SET price = EXCLUDED.price, available = EXCLUDED.available, external_refs = EXCLUDED.external_refs',
    [productId, dispensaryId, 25.00, true, JSON.stringify({ source: 'dutchie' })]
  );
}

normalizeDutchie().catch(e => { console.error(e); process.exit(1); });
