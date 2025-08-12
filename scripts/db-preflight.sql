-- Quick checks before ingest (run in SQL editor)
-- Pre-flight DB sanity (refs must exist)

-- Check core reference tables
SELECT COUNT(*) AS products FROM scout.products;
SELECT COUNT(*) AS stores   FROM scout.stores;

-- Ensure key indexes exist (no-op if already there)
CREATE INDEX IF NOT EXISTS idx_products_id ON scout.products(id);
CREATE INDEX IF NOT EXISTS idx_stores_id   ON scout.stores(id);

-- Create minimal seed data if tables are empty
INSERT INTO scout.stores (id, name, region, city, barangay) 
SELECT * FROM (VALUES 
  (1, 'SM North EDSA', 'NCR', 'Quezon City', 'North Triangle'),
  (2, 'Robinsons Ermita', 'NCR', 'Manila', 'Ermita'),
  (3, 'Ayala Center Cebu', 'Central Visayas', 'Cebu City', 'Business Park'),
  (4, 'SM Davao', 'Davao Region', 'Davao City', 'Quimpo Boulevard'),
  (5, 'Gaisano Cagayan', 'Northern Mindanao', 'Cagayan de Oro', 'Carmen')
) AS seed(id, name, region, city, barangay)
WHERE NOT EXISTS (SELECT 1 FROM scout.stores LIMIT 1);

INSERT INTO scout.brands (id, name, category) 
SELECT * FROM (VALUES 
  (1, 'Lucky Me', 'Food'),
  (2, 'San Miguel', 'Beverages'),
  (3, 'Magnolia', 'Dairy')
) AS seed(id, name, category)
WHERE NOT EXISTS (SELECT 1 FROM scout.brands LIMIT 1);

INSERT INTO scout.products (id, name, brand_id, category_id, unit) 
SELECT * FROM (VALUES 
  (1, 'Lucky Me Pancit Canton', 1, 1, 'pc'),
  (2, 'San Miguel Pale Pilsen', 2, 2, 'bottle'),
  (3, 'Magnolia Fresh Milk 1L', 3, 3, 'L'),
  (4, 'Century Tuna Flakes', 1, 1, 'can'),
  (5, 'Kopiko 3-in-1 Coffee', 2, 2, 'sachet'),
  (6, 'Chippy BBQ', 1, 1, 'pc'),
  (7, 'Tide Powder 1kg', 1, 4, 'kg'),
  (8, 'Safeguard Soap', 3, 5, 'pc'),
  (9, 'Argentina Corned Beef', 1, 1, 'can'),
  (10, 'Datu Puti Vinegar 1L', 2, 6, 'L')
) AS seed(id, name, brand_id, category_id, unit)
WHERE NOT EXISTS (SELECT 1 FROM scout.products LIMIT 1);

-- Verify seed data was inserted
SELECT 
  (SELECT COUNT(*) FROM scout.stores) AS stores,
  (SELECT COUNT(*) FROM scout.brands) AS brands,
  (SELECT COUNT(*) FROM scout.products) AS products;