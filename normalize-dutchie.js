const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'tcrb',
  password: 'password',
  port: 5432,
});

async function normalizeDutchieData() {
  const client = await pool.connect();
  
  try {
    console.log('Starting Dutchie data normalization...');
    
    // Get all dutchie records from staging
    const stagingResult = await client.query(
      'SELECT * FROM staging_sources WHERE source = $1',
      ['dutchie']
    );
    
    console.log(`Found ${stagingResult.rows.length} dutchie records to normalize`);
    
    for (const row of stagingResult.rows) {
      const data = row.data;
      
      // Insert/update brand
      const brandResult = await client.query(`
        INSERT INTO brands (name, external_refs)
        VALUES ($1, $2)
        ON CONFLICT (name) DO UPDATE SET
          external_refs = brands.external_refs || EXCLUDED.external_refs
        RETURNING id
      `, [data.brand || 'Unknown', { dutchie: { brand_id: data.brand_id } }]);
      
      const brandId = brandResult.rows[0].id;
      
      // Insert/update dispensary
      const dispensaryResult = await client.query(`
        INSERT INTO dispensaries (name, location, external_refs)
        VALUES ($1, $2, $3)
        ON CONFLICT (name) DO UPDATE SET
          location = EXCLUDED.location,
          external_refs = dispensaries.external_refs || EXCLUDED.external_refs
        RETURNING id
      `, [
        data.dispensary || 'Unknown',
        data.location || {},
        { dutchie: { dispensary_id: data.dispensary_id } }
      ]);
      
      const dispensaryId = dispensaryResult.rows[0].id;
      
      // Insert/update product
      const productResult = await client.query(`
        INSERT INTO products (name, brand_id, category, subcategory, external_refs)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (name, brand_id) DO UPDATE SET
          category = EXCLUDED.category,
          subcategory = EXCLUDED.subcategory,
          external_refs = products.external_refs || EXCLUDED.external_refs
        RETURNING id
      `, [
        data.name || 'Unknown Product',
        brandId,
        data.category || 'unknown',
        data.subcategory,
        { dutchie: { product_id: data.product_id } }
      ]);
      
      const productId = productResult.rows[0].id;
      
      // Insert/update listing
      const listingResult = await client.query(`
        INSERT INTO listings (product_id, dispensary_id, price, weight, external_refs)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (product_id, dispensary_id) DO UPDATE SET
          price = EXCLUDED.price,
          weight = EXCLUDED.weight,
          external_refs = listings.external_refs || EXCLUDED.external_refs
        RETURNING id
      `, [
        productId,
        dispensaryId,
        data.price ? parseFloat(data.price) : null,
        data.weight ? parseFloat(data.weight) : null,
        { dutchie: { listing_id: data.listing_id } }
      ]);
      
      const listingId = listingResult.rows[0].id;
      
      // Insert score if available
      if (data.score || data.rating) {
        await client.query(`
          INSERT INTO scores (listing_id, score, confidence, version, external_refs)
          VALUES ($1, $2, $3, $4, $5)
          ON CONFLICT (listing_id) DO UPDATE SET
            score = EXCLUDED.score,
            confidence = EXCLUDED.confidence,
            version = EXCLUDED.version,
            external_refs = scores.external_refs || EXCLUDED.external_refs
        `, [
          listingId,
          data.score ? parseFloat(data.score) : parseFloat(data.rating),
          data.confidence ? parseFloat(data.confidence) : 0.8,
          '1.0',
          { dutchie: { score_id: data.score_id } }
        ]);
      }
    }
    
    // Show final counts
    const counts = await Promise.all([
      client.query('SELECT COUNT(*) FROM brands'),
      client.query('SELECT COUNT(*) FROM dispensaries'),
      client.query('SELECT COUNT(*) FROM products'),
      client.query('SELECT COUNT(*) FROM listings'),
      client.query('SELECT COUNT(*) FROM scores')
    ]);
    
    console.log('Normalization complete!');
    console.log(`Brands: ${counts[0].rows[0].count}`);
    console.log(`Dispensaries: ${counts[1].rows[0].count}`);
    console.log(`Products: ${counts[2].rows[0].count}`);
    console.log(`Listings: ${counts[3].rows[0].count}`);
    console.log(`Scores: ${counts[4].rows[0].count}`);
    
  } catch (error) {
    console.error('Error during normalization:', error);
    throw error;
  } finally {
    client.release();
  }
}

// Run the normalization
normalizeDutchieData()
  .then(() => {
    console.log('Dutchie normalization completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Normalization failed:', error);
    process.exit(1);
  });