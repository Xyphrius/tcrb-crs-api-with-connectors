// src/notion/sync-scores.js
require('dotenv').config();
const { Client } = require('@notionhq/client');
const { Pool } = require('pg');

const notion = new Client({
  auth: process.env.NOTION_TOKEN,
});

const databaseId = process.env.NOTION_CRS_DATABASE_ID;

async function syncScoresToNotion() {
  const pool = new Pool({ 
    user: 'postgres', 
    host: 'localhost', 
    database: 'tcrb', 
    password: 'postgres', 
    port: 5432 
  });
  
  const client = await pool.connect();
  let syncCount = 0;
  
  try {
    // Query scores with product details
    const { rows: scores } = await client.query(`
      SELECT 
        s.product_id,
        p.name as product_name,
        p.source,
        p.price_cents,
        s.crs,
        s.confidence,
        s.computed_at,
        COUNT(pl.id) as listing_count
      FROM scores s
      JOIN products p ON s.product_id = p.id
      LEFT JOIN product_listings pl ON p.id = pl.product_id
      WHERE s.computed_at IS NOT NULL
      GROUP BY s.product_id, p.name, p.source, p.price_cents, s.crs, s.confidence, s.computed_at
      ORDER BY s.computed_at DESC
      LIMIT 100
    `);

    console.log(`Found ${scores.length} scores to sync`);

    for (const score of scores) {
      try {
        // Check if page already exists
        const existingPages = await notion.databases.query({
          database_id: databaseId,
          filter: {
            property: 'Product ID',
            rich_text: {
              equals: score.product_id
            }
          }
        });

        const pageData = {
          'Product Name': {
            title: [{ text: { content: score.product_name || 'Unknown Product' } }]
          },
          'Source': {
            select: { name: score.source || 'Unknown' }
          },
          'CRS Score': {
            number: score.crs
          },
          'Confidence (%)': {
            number: Math.round(score.confidence * 100)
          },
          'Price (¢)': {
            number: score.price_cents
          },
          'Listing Count': {
            number: score.listing_count
          },
          'Product ID': {
            rich_text: [{ text: { content: score.product_id } }]
          },
          'Computed At': {
            date: { start: score.computed_at.toISOString() }
          },
          'Sync Timestamp': {
            date: { start: new Date().toISOString() }
          }
        };

        if (existingPages.results.length > 0) {
          // Update existing page
          await notion.pages.update({
            page_id: existingPages.results[0].id,
            properties: pageData
          });
          console.log(`updated ${score.product_id}`);
        } else {
          // Create new page
          await notion.pages.create({
            parent: { database_id: databaseId },
            properties: pageData
          });
          console.log(`created ${score.product_id}`);
        }
        
        syncCount++;
      } catch (error) {
        console.error(`Error syncing ${score.product_id}:`, error.message);
      }
    }

    console.log(`synced ${syncCount} rows`);
    
  } catch (error) {
    console.error('Sync error:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

if (require.main === module) {
  syncScoresToNotion()
    .then(() => {
      console.log('Sync completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('Sync failed:', error);
      process.exit(1);
    });
}

module.exports = { syncScoresToNotion };
