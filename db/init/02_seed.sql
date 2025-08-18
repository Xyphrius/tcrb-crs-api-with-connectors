-- 02_seed.sql — minimal smoke data

INSERT INTO brands(name) VALUES ('Extract Masters')
ON CONFLICT (name) DO NOTHING;

INSERT INTO brands(name) VALUES ('Elevate Edibles')
ON CONFLICT (name) DO NOTHING;

-- upsert helper to avoid duplicates when you re-bootstrap fresh volumes
WITH b AS (
  SELECT id FROM brands WHERE name='Extract Masters'
),
p AS (
  INSERT INTO products(name, category, strain, brand_id)
  SELECT 'Demo OG 1g', 'Flower', 'OG Kush', b.id FROM b
  ON CONFLICT DO NOTHING
  RETURNING id
)
INSERT INTO scores(product_id, crs, confidence, reason_codes, feature_vector, version)
SELECT
  COALESCE((SELECT id FROM p),
           (SELECT id FROM products WHERE name='Demo OG 1g')),
  87.50, 0.92,
  ARRAY['GOOD_COVERAGE','FAIR_PRICE'],
  '{"listing_count":3,"avg_price_cents":2999}'::jsonb,
  '1.0'
WHERE NOT EXISTS (
  SELECT 1 FROM scores
  WHERE product_id = (SELECT id FROM products WHERE name='Demo OG 1g')
);
