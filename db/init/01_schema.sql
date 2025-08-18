-- 01_schema.sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- brands (optional but useful)
CREATE TABLE IF NOT EXISTS brands (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text UNIQUE NOT NULL
);

-- products
CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  category text,
  strain text,
  brand_id uuid REFERENCES brands(id) ON DELETE SET NULL
);

-- scores
CREATE TABLE IF NOT EXISTS scores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  crs numeric(5,2) NOT NULL,
  confidence numeric(4,2),
  reason_codes text[],
  feature_vector jsonb,
  computed_at timestamptz DEFAULT now(),
  version text NOT NULL
);

-- indexes
CREATE INDEX IF NOT EXISTS idx_scores_productid_computedat
  ON scores (product_id, computed_at DESC);

CREATE INDEX IF NOT EXISTS idx_products_name
  ON products (name);
