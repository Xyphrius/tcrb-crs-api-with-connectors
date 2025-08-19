#!/usr/bin/env node

require('dotenv').config();
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

async function migrate() {
  const pool = new Pool({
    host: process.env.PGHOST || 'ep-calm-mouse-aedq8f1d-pooler.c-2.us-east-2.aws.neon.tech',
    port: process.env.PGPORT || 5432,
    user: process.env.PGUSER || 'neondb_owner',
    password: process.env.PGPASSWORD || 'npg_YC9v7gbDGIzd',
    database: process.env.PGDATABASE || 'neondb',
    ssl: process.env.PGSSLMODE === 'require' ? { rejectUnauthorized: false } : false
  });

  try {
    console.log('🔌 Connecting to database...');
    const client = await pool.connect();
    
    // Check current database info
    const dbInfo = await client.query('SELECT current_database(), current_user, version()');
    console.log('📊 Database Info:', dbInfo.rows[0]);
    
    console.log('📋 Running schema migration...');
    const schemaSQL = fs.readFileSync(path.join(__dirname, 'init/01_schema.sql'), 'utf8');
    console.log('Schema SQL length:', schemaSQL.length);
    console.log('First 100 chars:', schemaSQL.substring(0, 100));
    
    const schemaResult = await client.query(schemaSQL);
    console.log('Schema migration result:', schemaResult);
    
    console.log('🌱 Running seed data...');
    const seedSQL = fs.readFileSync(path.join(__dirname, 'init/02_seed.sql'), 'utf8');
    console.log('Seed SQL length:', seedSQL.length);
    
    const seedResult = await client.query(seedSQL);
    console.log('Seed migration result:', seedResult);
    
    console.log('✅ Database migration completed successfully!');
    
    // Verify tables exist
    const tables = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name
    `);
    
    console.log('📊 Tables created:', tables.rows.map(r => r.table_name).join(', '));
    
    client.release();
  } catch (err) {
    console.error('❌ Migration failed:', err.message);
    console.error('Full error:', err);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  migrate();
}
