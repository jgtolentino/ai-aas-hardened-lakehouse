-- Retail Insights Dashboard Schema for AI-aaS Hardened Lakehouse
-- Complete schema including Scout enhancements and SKU catalog

-- =====================================================
-- CORE TABLES
-- =====================================================

-- Stores table
CREATE TABLE IF NOT EXISTS stores (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  location VARCHAR(255),
  city VARCHAR(100),
  region VARCHAR(100),
  barangay VARCHAR(100),
  coordinates JSONB,
  store_type VARCHAR(30) DEFAULT 'sari-sari',
  size_category VARCHAR(20) DEFAULT 'small',
  monthly_avg_transactions INT,
  avg_daily_revenue DECIMAL(10,2),
  has_iot_device BOOLEAN DEFAULT FALSE,
  has_device BOOLEAN DEFAULT FALSE,
  device_installation_date TIMESTAMP,
  tier INTEGER DEFAULT 3,
  network_type VARCHAR(20) DEFAULT 'wifi',
  power_backup BOOLEAN DEFAULT FALSE,
  operating_hours_start TIME DEFAULT '06:00:00',
  operating_hours_end TIME DEFAULT '22:00:00',
  peak_hours JSONB,
  manager_contact VARCHAR(100),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  last_updated TIMESTAMP DEFAULT NOW()
);

-- Brands table with TBWA tracking
CREATE TABLE IF NOT EXISTS brands (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL UNIQUE,
  external_id VARCHAR(50) UNIQUE,
  manufacturer VARCHAR(200),
  is_tbwa_client BOOLEAN DEFAULT FALSE,
  is_tbwa BOOLEAN DEFAULT FALSE,
  category VARCHAR(100),
  brand_tier VARCHAR(20) DEFAULT 'standard',
  market_share_ph DECIMAL(5,2),
  competitor_level VARCHAR(20),
  local_preference_score DECIMAL(3,2),
  price_tier VARCHAR(20),
  cultural_affinity DECIMAL(3,2),
  substitution_likelihood DECIMAL(3,2),
  is_telco BOOLEAN DEFAULT FALSE,
  client_priority VARCHAR(20) DEFAULT 'standard',
  last_catalog_update TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  last_updated TIMESTAMP DEFAULT NOW()
);

-- Products table with comprehensive metadata
CREATE TABLE IF NOT EXISTS products (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  brand_id INTEGER REFERENCES brands(id),
  sku VARCHAR(100),
  barcode VARCHAR(50),
  external_product_key INTEGER,
  category VARCHAR(100),
  category_id VARCHAR(50),
  price DECIMAL(10,2),
  list_price DECIMAL(10,2),
  min_price DECIMAL(10,2),
  max_price DECIMAL(10,2),
  price_range_min DECIMAL(8,2),
  price_range_max DECIMAL(8,2),
  pack_size VARCHAR(100),
  unit_type VARCHAR(50),
  typical_unit VARCHAR(20),
  is_active BOOLEAN DEFAULT TRUE,
  halal_certified BOOLEAN DEFAULT FALSE,
  description TEXT,
  price_source VARCHAR(100),
  is_telco_product BOOLEAN DEFAULT FALSE,
  load_denomination INTEGER,
  data_allocation_mb INTEGER,
  validity_days INTEGER,
  local_name VARCHAR(200),
  seasonal_demand JSONB,
  cultural_significance VARCHAR(100),
  substitute_products TEXT[],
  monitoring_priority VARCHAR(20) DEFAULT 'standard',
  last_catalog_update TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  last_updated TIMESTAMP DEFAULT NOW()
);

-- Customers table
CREATE TABLE IF NOT EXISTS customers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  email VARCHAR(255),
  phone VARCHAR(50),
  age INTEGER,
  gender VARCHAR(20),
  location VARCHAR(255),
  preferred_language VARCHAR(20) DEFAULT 'tagalog',
  family_size INT,
  income_bracket VARCHAR(20),
  shopping_frequency VARCHAR(20),
  payment_preference VARCHAR(30),
  loyalty_level VARCHAR(20) DEFAULT 'regular',
  cultural_preferences JSONB,
  regional_dialect VARCHAR(30),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Transactions table with Scout enhancements
CREATE TABLE IF NOT EXISTS transactions (
  id SERIAL PRIMARY KEY,
  transaction_date TIMESTAMP DEFAULT NOW(),
  store_id INTEGER REFERENCES stores(id),
  customer_id INTEGER REFERENCES customers(id),
  total_amount DECIMAL(10,2),
  items_count INTEGER DEFAULT 0,
  customer_age INTEGER,
  customer_gender VARCHAR(20),
  customer_location VARCHAR(255),
  payment_method VARCHAR(20) DEFAULT 'cash',
  checkout_time TIMESTAMPTZ DEFAULT NOW(),
  checkout_seconds INTEGER DEFAULT 45,
  request_type VARCHAR(50) DEFAULT 'branded',
  transcription_text TEXT,
  suggestion_offered BOOLEAN DEFAULT FALSE,
  suggestion_accepted BOOLEAN DEFAULT FALSE,
  substitution_occurred BOOLEAN DEFAULT FALSE,
  -- Scout additions
  device_id VARCHAR(50),
  facial_id VARCHAR(100),
  emotional_state VARCHAR(20),
  audio_quality_score DECIMAL(3,2),
  session_confidence DECIMAL(3,2),
  local_language_used VARCHAR(20),
  cultural_context JSONB,
  validation_status VARCHAR(20) DEFAULT 'valid',
  data_quality_score DECIMAL(3,2) DEFAULT 1.00,
  nlp_processed BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Transaction items
CREATE TABLE IF NOT EXISTS transaction_items (
  id SERIAL PRIMARY KEY,
  transaction_id INTEGER REFERENCES transactions(id) ON DELETE CASCADE,
  product_id INTEGER REFERENCES products(id),
  brand_id INTEGER REFERENCES brands(id),
  quantity INTEGER DEFAULT 1,
  price DECIMAL(10,2),
  unit_price DECIMAL(8,2),
  subtotal DECIMAL(10,2),
  total_price DECIMAL(8,2),
  discount_amount DECIMAL(8,2) DEFAULT 0,
  local_term_used VARCHAR(200),
  request_method VARCHAR(50),
  created_at TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- SCOUT DEVICE MANAGEMENT TABLES
-- =====================================================

-- Devices table with MAC-based unique IDs
CREATE TABLE IF NOT EXISTS devices (
  id SERIAL PRIMARY KEY,
  device_id VARCHAR(20) UNIQUE NOT NULL CHECK (device_id ~ '^PI5_[0-9]{4}_[a-f0-9]{6}$'),
  store_id INTEGER NOT NULL,
  mac_address VARCHAR(17) NOT NULL,
  device_type VARCHAR(50) DEFAULT 'Raspberry Pi 5',
  status VARCHAR(20) DEFAULT 'active',
  installed_date TIMESTAMP DEFAULT NOW(),
  last_heartbeat TIMESTAMP DEFAULT NOW(),
  ram_gb INTEGER,
  storage_gb INTEGER,
  network_type VARCHAR(10),
  monitoring_level VARCHAR(20),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Device health monitoring
CREATE TABLE IF NOT EXISTS device_health (
  id SERIAL PRIMARY KEY,
  device_id VARCHAR(20) REFERENCES devices(device_id),
  cpu_usage DECIMAL(5,2),
  memory_usage DECIMAL(5,2),
  storage_usage DECIMAL(5,2),
  network_latency_ms INTEGER,
  temperature_celsius DECIMAL(4,1),
  status VARCHAR(20),
  uptime_hours INTEGER,
  error_count_24h INTEGER DEFAULT 0,
  recorded_at TIMESTAMP DEFAULT NOW()
);

-- System alerts
CREATE TABLE IF NOT EXISTS system_alerts (
  id SERIAL PRIMARY KEY,
  alert_type VARCHAR(50) NOT NULL,
  severity VARCHAR(20) NOT NULL,
  device_id VARCHAR(20),
  store_id INTEGER,
  message TEXT,
  details JSONB,
  resolved BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  resolved_at TIMESTAMP
);

-- =====================================================
-- BEHAVIORAL ANALYTICS TABLES
-- =====================================================

-- Substitutions tracking
CREATE TABLE IF NOT EXISTS substitutions (
  id SERIAL PRIMARY KEY,
  substitution_id SERIAL UNIQUE,
  transaction_id INTEGER REFERENCES transactions(id) ON DELETE CASCADE,
  original_product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
  substituted_product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
  substitute_product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
  reason VARCHAR(100) DEFAULT 'out_of_stock',
  acceptance_rate DECIMAL(3,2) DEFAULT 0.70,
  customer_response VARCHAR(20),
  accepted BOOLEAN,
  price_difference DECIMAL(8,2),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Request behaviors
CREATE TABLE IF NOT EXISTS request_behaviors (
  id SERIAL PRIMARY KEY,
  behavior_id SERIAL UNIQUE,
  transaction_id INTEGER REFERENCES transactions(id) ON DELETE CASCADE,
  behavior_type VARCHAR(50) NOT NULL,
  request_type VARCHAR(50),
  product_mentioned VARCHAR(255),
  brand_mentioned VARCHAR(255),
  gesture_used BOOLEAN DEFAULT FALSE,
  language_used VARCHAR(20),
  gesture_type VARCHAR(30),
  politeness_level VARCHAR(20),
  cultural_context TEXT,
  local_terms_count INT DEFAULT 0,
  clarification_count INTEGER DEFAULT 0,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Sales interactions (IoT behavioral data)
CREATE TABLE IF NOT EXISTS sales_interactions (
  interaction_id VARCHAR(255) PRIMARY KEY,
  device_id VARCHAR(50),
  store_id INT REFERENCES stores(id),
  transaction_date TIMESTAMP DEFAULT NOW(),
  facial_id VARCHAR(100),
  gender VARCHAR(20),
  age INT,
  emotional_state VARCHAR(20),
  transcription_text TEXT,
  confidence_score DECIMAL(3,2),
  session_duration_seconds INT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- TELCO AND CATALOG TABLES
-- =====================================================

-- Telco products
CREATE TABLE IF NOT EXISTS telco_products (
  id SERIAL PRIMARY KEY,
  product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
  network_provider VARCHAR(50) NOT NULL,
  product_type VARCHAR(50) NOT NULL,
  denomination DECIMAL(10,2),
  data_mb INTEGER,
  call_minutes INTEGER,
  sms_count INTEGER,
  validity_days INTEGER,
  promo_code VARCHAR(20),
  ussd_code VARCHAR(50),
  description TEXT,
  terms_conditions TEXT,
  is_unlimited BOOLEAN DEFAULT FALSE,
  is_5g_compatible BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Product categories
CREATE TABLE IF NOT EXISTS product_categories (
  id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  parent_id VARCHAR(50) REFERENCES product_categories(id),
  level INTEGER DEFAULT 1,
  is_active BOOLEAN DEFAULT TRUE,
  display_order INTEGER,
  icon_name VARCHAR(50),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Barcode registry
CREATE TABLE IF NOT EXISTS barcode_registry (
  id SERIAL PRIMARY KEY,
  barcode VARCHAR(50) UNIQUE NOT NULL,
  product_id INTEGER REFERENCES products(id),
  product_name VARCHAR(255),
  brand_name VARCHAR(100),
  verified BOOLEAN DEFAULT FALSE,
  scan_count INTEGER DEFAULT 0,
  last_scanned TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Price history
CREATE TABLE IF NOT EXISTS price_history (
  id SERIAL PRIMARY KEY,
  product_id INTEGER REFERENCES products(id),
  price DECIMAL(10,2) NOT NULL,
  price_source VARCHAR(100),
  effective_date DATE NOT NULL,
  store_id INTEGER REFERENCES stores(id),
  promotion_id INTEGER,
  created_at TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- MASTER DATA TABLES
-- =====================================================

-- Device master
CREATE TABLE IF NOT EXISTS device_master (
  device_id VARCHAR(50) PRIMARY KEY,
  mac_address VARCHAR(17) UNIQUE NOT NULL,
  serial_number VARCHAR(50) UNIQUE,
  store_id INT REFERENCES stores(id),
  installation_date TIMESTAMP,
  installer_name VARCHAR(100),
  firmware_version VARCHAR(20),
  hardware_revision VARCHAR(10),
  network_config JSONB,
  device_type VARCHAR(50) DEFAULT 'RaspberryPi5',
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'maintenance', 'retired')),
  last_heartbeat TIMESTAMP,
  last_upload TIMESTAMP,
  total_transactions_recorded BIGINT DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Unbranded commodities (Local sari-sari store items)
CREATE TABLE IF NOT EXISTS unbranded_commodities (
  commodity_id SERIAL PRIMARY KEY,
  local_name VARCHAR(100),
  english_name VARCHAR(100),
  category VARCHAR(50),
  typical_unit VARCHAR(20),
  typical_price_range DECIMAL(10,2),
  regional_variations TEXT[],
  created_at TIMESTAMP DEFAULT NOW()
);

-- Local product terms mapping
CREATE TABLE IF NOT EXISTS local_product_terms (
  term_id SERIAL PRIMARY KEY,
  local_term VARCHAR(200),
  standard_product VARCHAR(200),
  brand_id INT,
  region VARCHAR(50),
  frequency_count INT DEFAULT 1,
  confidence DECIMAL(3,2),
  created_at TIMESTAMP DEFAULT NOW(),
  last_used TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Transaction indexes
CREATE INDEX IF NOT EXISTS idx_transactions_store_id ON transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_transactions_customer_id ON transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_transactions_device_id ON transactions(device_id);
CREATE INDEX IF NOT EXISTS idx_transactions_validation_status ON transactions(validation_status);
CREATE INDEX IF NOT EXISTS idx_transactions_quality_score ON transactions(data_quality_score);
CREATE INDEX IF NOT EXISTS idx_transactions_request_type ON transactions(request_type);
CREATE INDEX IF NOT EXISTS idx_transactions_payment_method ON transactions(payment_method);
CREATE INDEX IF NOT EXISTS idx_transactions_checkout_time ON transactions(checkout_time);

-- Product indexes
CREATE INDEX IF NOT EXISTS idx_products_brand_id ON products(brand_id);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_halal ON products(halal_certified);
CREATE INDEX IF NOT EXISTS idx_products_active ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_telco ON products(is_telco_product);
CREATE INDEX IF NOT EXISTS idx_products_external_key ON products(external_product_key);

-- Brand indexes
CREATE INDEX IF NOT EXISTS idx_brands_external_id ON brands(external_id);
CREATE INDEX IF NOT EXISTS idx_brands_manufacturer ON brands(manufacturer);
CREATE INDEX IF NOT EXISTS idx_brands_telco ON brands(is_telco);
CREATE INDEX IF NOT EXISTS idx_brands_tbwa ON brands(is_tbwa_client);

-- Device indexes
CREATE INDEX IF NOT EXISTS idx_devices_device_id ON devices(device_id);
CREATE INDEX IF NOT EXISTS idx_devices_store_id ON devices(store_id);
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices(status);
CREATE INDEX IF NOT EXISTS idx_device_health_device_id ON device_health(device_id);
CREATE INDEX IF NOT EXISTS idx_device_health_recorded_at ON device_health(recorded_at);
CREATE INDEX IF NOT EXISTS idx_device_health_status ON device_health(status);

-- Behavioral indexes
CREATE INDEX IF NOT EXISTS idx_substitutions_transaction_id ON substitutions(transaction_id);
CREATE INDEX IF NOT EXISTS idx_substitutions_original_product ON substitutions(original_product_id);
CREATE INDEX IF NOT EXISTS idx_request_behaviors_transaction_id ON request_behaviors(transaction_id);
CREATE INDEX IF NOT EXISTS idx_request_behaviors_type ON request_behaviors(behavior_type);

-- Alert indexes
CREATE INDEX IF NOT EXISTS idx_system_alerts_device_id ON system_alerts(device_id);
CREATE INDEX IF NOT EXISTS idx_system_alerts_severity ON system_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_system_alerts_resolved ON system_alerts(resolved);
CREATE INDEX IF NOT EXISTS idx_system_alerts_created_at ON system_alerts(created_at);

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================

GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================

SELECT 
  '✅ Retail Insights Schema Migration Complete' as status,
  'All tables, indexes, and permissions created' as message,
  COUNT(*) as total_tables_created
FROM information_schema.tables 
WHERE table_schema = 'public';
