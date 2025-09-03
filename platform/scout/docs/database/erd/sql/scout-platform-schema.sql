-- =============================================================================
-- Scout Analytics Platform - Generated SQL Schema
-- =============================================================================
-- Generated from: scout-platform-schema.dbml
-- Timestamp: 2025-09-03 18:13:41
-- Database: PostgreSQL 15+
-- Architecture: Medallion (Bronze → Silver → Gold → Platinum)
-- =============================================================================

-- SQL dump generated using DBML (dbml.dbdiagram.io)
-- Database: PostgreSQL
-- Generated at: 2025-09-03T10:13:40.964Z

CREATE SCHEMA "scout";

CREATE SCHEMA "scout_bronze";

CREATE SCHEMA "scout_silver";

CREATE SCHEMA "scout_gold";

CREATE SCHEMA "scout_platinum";

CREATE TABLE "scout"."schema_registry" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "schema_name" text UNIQUE NOT NULL,
  "purpose" text NOT NULL,
  "access_level" text NOT NULL,
  "data_classification" text NOT NULL,
  "retention_period_days" integer,
  "created_at" timestamptz DEFAULT (now()),
  "updated_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout"."table_metadata" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "schema_name" text NOT NULL,
  "table_name" text NOT NULL,
  "business_purpose" text,
  "data_source" text,
  "update_frequency" text,
  "data_owner" text,
  "steward_email" text,
  "quality_score" decimal(5,2),
  "last_quality_check" timestamptz,
  "record_count" bigint,
  "created_at" timestamptz DEFAULT (now()),
  "updated_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout"."data_lineage" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "source_schema" text NOT NULL,
  "source_table" text NOT NULL,
  "target_schema" text NOT NULL,
  "target_table" text NOT NULL,
  "transformation_type" text,
  "transformation_logic" text,
  "dependency_level" integer,
  "created_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout"."audit_log" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "schema_name" text NOT NULL,
  "table_name" text NOT NULL,
  "record_id" uuid,
  "operation_type" text NOT NULL,
  "old_values" jsonb,
  "new_values" jsonb,
  "changed_by" uuid,
  "changed_at" timestamptz DEFAULT (now()),
  "change_reason" text,
  "ip_address" inet,
  "user_agent" text
);

CREATE TABLE "scout"."psgc_codes" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "psgc_code" text UNIQUE NOT NULL,
  "region_name" text NOT NULL,
  "province_name" text NOT NULL,
  "city_municipality" text NOT NULL,
  "barangay_name" text,
  "geographic_level" text NOT NULL,
  "island_group" text NOT NULL,
  "population" integer,
  "land_area_sqkm" decimal(10,2),
  "is_urban" boolean DEFAULT false,
  "economic_zone" text,
  "created_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout"."philippine_holidays" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "holiday_date" date NOT NULL,
  "holiday_name" text NOT NULL,
  "holiday_type" text NOT NULL,
  "is_nationwide" boolean DEFAULT true,
  "affected_regions" text[],
  "business_impact" text,
  "created_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_bronze"."raw_transactions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "source_system" text NOT NULL,
  "external_transaction_id" text,
  "raw_payload" jsonb NOT NULL,
  "ingestion_timestamp" timestamptz DEFAULT (now()),
  "file_name" text,
  "batch_id" uuid,
  "validation_status" text DEFAULT 'PENDING',
  "validation_errors" jsonb,
  "processed_at" timestamptz
);

CREATE TABLE "scout_bronze"."raw_products" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "source_system" text NOT NULL,
  "external_product_id" text,
  "raw_payload" jsonb NOT NULL,
  "ingestion_timestamp" timestamptz DEFAULT (now()),
  "batch_id" uuid,
  "validation_status" text DEFAULT 'PENDING',
  "validation_errors" jsonb
);

CREATE TABLE "scout_bronze"."raw_customers" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "source_system" text NOT NULL,
  "external_customer_id" text,
  "raw_payload" jsonb NOT NULL,
  "ingestion_timestamp" timestamptz DEFAULT (now()),
  "batch_id" uuid,
  "validation_status" text DEFAULT 'PENDING',
  "validation_errors" jsonb,
  "pii_masked" boolean DEFAULT false
);

CREATE TABLE "scout_silver"."transactions" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "bronze_source_id" uuid,
  "transaction_id" text UNIQUE NOT NULL,
  "store_id" uuid NOT NULL,
  "customer_id" uuid,
  "transaction_date" timestamptz NOT NULL,
  "subtotal" decimal(15,2) NOT NULL,
  "tax_amount" decimal(15,2) DEFAULT 0,
  "discount_amount" decimal(15,2) DEFAULT 0,
  "total_amount" decimal(15,2) NOT NULL,
  "payment_method" text,
  "currency" text NOT NULL DEFAULT 'PHP',
  "receipt_number" text,
  "pos_terminal_id" text,
  "cashier_id" text,
  "transaction_status" text DEFAULT 'COMPLETED',
  "notes" text,
  "created_at" timestamptz DEFAULT (now()),
  "updated_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_silver"."transaction_items" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "transaction_id" uuid NOT NULL,
  "product_id" uuid NOT NULL,
  "product_sku" text NOT NULL,
  "product_name" text NOT NULL,
  "category" text,
  "brand" text,
  "quantity" decimal(10,2) NOT NULL,
  "unit_price" decimal(15,2) NOT NULL,
  "line_discount" decimal(15,2) DEFAULT 0,
  "line_total" decimal(15,2) NOT NULL,
  "cost_of_goods" decimal(15,2),
  "promotion_code" text,
  "created_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_silver"."stores" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "store_code" text UNIQUE NOT NULL,
  "store_name" text NOT NULL,
  "store_type" text,
  "region" text NOT NULL,
  "province" text NOT NULL,
  "city" text NOT NULL,
  "barangay" text,
  "address" text NOT NULL,
  "postal_code" text,
  "psgc_code" text,
  "latitude" decimal(10,8),
  "longitude" decimal(11,8),
  "mall_name" text,
  "floor_level" text,
  "store_size_sqm" decimal(10,2),
  "opening_date" date,
  "manager_name" text,
  "contact_phone" text,
  "status" text DEFAULT 'ACTIVE',
  "created_at" timestamptz DEFAULT (now()),
  "updated_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_silver"."products" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "product_sku" text UNIQUE NOT NULL,
  "product_name" text NOT NULL,
  "description" text,
  "category" text NOT NULL,
  "subcategory" text,
  "brand" text NOT NULL,
  "unit_of_measure" text DEFAULT 'PCS',
  "unit_cost" decimal(15,2),
  "suggested_retail_price" decimal(15,2),
  "wholesale_price" decimal(15,2),
  "weight_grams" decimal(10,2),
  "dimensions_cm" text,
  "barcode" text,
  "supplier_name" text,
  "country_of_origin" text DEFAULT 'Philippines',
  "is_active" boolean DEFAULT true,
  "launch_date" date,
  "discontinue_date" date,
  "created_at" timestamptz DEFAULT (now()),
  "updated_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_silver"."customers" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "customer_code" text UNIQUE,
  "email" text UNIQUE,
  "phone_number" text,
  "date_of_birth" date,
  "gender" text,
  "region" text,
  "province" text,
  "city" text,
  "signup_date" date,
  "preferred_language" text DEFAULT 'en',
  "loyalty_tier" text DEFAULT 'BRONZE',
  "total_lifetime_value" decimal(15,2) DEFAULT 0,
  "total_transactions" integer DEFAULT 0,
  "last_transaction_date" timestamptz,
  "customer_status" text DEFAULT 'ACTIVE',
  "acquisition_channel" text,
  "created_at" timestamptz DEFAULT (now()),
  "updated_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_gold"."kpi_daily_summary" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "date" date NOT NULL,
  "store_id" uuid,
  "total_revenue" decimal(15,2) NOT NULL,
  "total_transactions" integer NOT NULL,
  "unique_customers" integer NOT NULL,
  "average_transaction_value" decimal(15,2) NOT NULL,
  "items_sold" integer NOT NULL,
  "gross_margin" decimal(15,2) NOT NULL,
  "top_category" text,
  "top_product_sku" text,
  "weather_condition" text,
  "is_holiday" boolean DEFAULT false,
  "created_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_gold"."product_performance" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "product_sku" text NOT NULL,
  "product_name" text NOT NULL,
  "category" text NOT NULL,
  "brand" text NOT NULL,
  "time_period" text NOT NULL,
  "period_start" date NOT NULL,
  "period_end" date NOT NULL,
  "units_sold" integer NOT NULL,
  "gross_revenue" decimal(15,2) NOT NULL,
  "gross_margin" decimal(15,2) NOT NULL,
  "margin_percentage" decimal(5,2) NOT NULL,
  "inventory_turns" decimal(10,2),
  "stockout_days" integer DEFAULT 0,
  "velocity_rank" integer,
  "abc_classification" text,
  "created_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_gold"."customer_segments" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "customer_id" uuid NOT NULL,
  "segment_name" text NOT NULL,
  "segment_score" decimal(5,2) NOT NULL,
  "lifetime_value" decimal(15,2) NOT NULL,
  "recency_days" integer NOT NULL,
  "frequency_score" integer NOT NULL,
  "monetary_score" integer NOT NULL,
  "rfm_segment" text NOT NULL,
  "predicted_next_purchase_date" date,
  "churn_probability" decimal(5,4),
  "recommended_actions" jsonb,
  "segment_date" date NOT NULL,
  "created_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_gold"."store_performance" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "store_id" uuid NOT NULL,
  "time_period" text NOT NULL,
  "period_start" date NOT NULL,
  "period_end" date NOT NULL,
  "total_revenue" decimal(15,2) NOT NULL,
  "revenue_growth_percentage" decimal(5,2),
  "total_transactions" integer NOT NULL,
  "transaction_growth_percentage" decimal(5,2),
  "average_basket_size" decimal(15,2) NOT NULL,
  "conversion_rate" decimal(5,4),
  "customer_satisfaction_score" decimal(3,2),
  "staff_productivity_score" decimal(5,2),
  "region_rank" integer,
  "performance_tier" text,
  "created_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_gold"."market_basket_analysis" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "product_a_sku" text NOT NULL,
  "product_b_sku" text NOT NULL,
  "support_count" integer NOT NULL,
  "confidence" decimal(5,4) NOT NULL,
  "lift" decimal(10,4) NOT NULL,
  "conviction" decimal(10,4),
  "analysis_period_start" date NOT NULL,
  "analysis_period_end" date NOT NULL,
  "minimum_support_threshold" decimal(5,4) NOT NULL,
  "is_significant" boolean DEFAULT false,
  "created_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_platinum"."demand_forecast" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "product_sku" text NOT NULL,
  "store_id" uuid NOT NULL,
  "forecast_date" date NOT NULL,
  "predicted_demand" integer NOT NULL,
  "confidence_interval_lower" integer NOT NULL,
  "confidence_interval_upper" integer NOT NULL,
  "model_accuracy" decimal(5,4),
  "seasonality_factor" decimal(8,4) NOT NULL,
  "trend_factor" decimal(8,4) NOT NULL,
  "external_factors" jsonb,
  "model_version" text NOT NULL,
  "forecast_generated_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_platinum"."price_optimization" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "product_sku" text NOT NULL,
  "store_id" uuid NOT NULL,
  "current_price" decimal(15,2) NOT NULL,
  "recommended_price" decimal(15,2) NOT NULL,
  "price_elasticity" decimal(8,4) NOT NULL,
  "demand_at_current_price" integer NOT NULL,
  "demand_at_recommended_price" integer NOT NULL,
  "revenue_impact" decimal(15,2) NOT NULL,
  "margin_impact" decimal(15,2) NOT NULL,
  "competitor_price_avg" decimal(15,2),
  "market_share_impact" decimal(5,4),
  "recommendation_confidence" decimal(5,4) NOT NULL,
  "valid_from" date NOT NULL,
  "valid_until" date NOT NULL,
  "model_version" text NOT NULL,
  "created_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_platinum"."customer_lifetime_value" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "customer_id" uuid NOT NULL,
  "predicted_clv" decimal(15,2) NOT NULL,
  "historical_clv" decimal(15,2) NOT NULL,
  "clv_percentile" integer NOT NULL,
  "predicted_tenure_months" integer NOT NULL,
  "churn_risk_score" decimal(5,4) NOT NULL,
  "next_purchase_probability" decimal(5,4) NOT NULL,
  "recommended_marketing_spend" decimal(15,2) NOT NULL,
  "customer_stage" text NOT NULL,
  "key_value_drivers" jsonb,
  "model_version" text NOT NULL,
  "prediction_date" date NOT NULL,
  "created_at" timestamptz DEFAULT (now())
);

CREATE TABLE "scout_platinum"."anomaly_detection" (
  "id" uuid PRIMARY KEY DEFAULT (gen_random_uuid()),
  "anomaly_type" text NOT NULL,
  "entity_type" text NOT NULL,
  "entity_id" uuid NOT NULL,
  "anomaly_score" decimal(5,4) NOT NULL,
  "expected_value" decimal(15,2),
  "actual_value" decimal(15,2),
  "deviation_percentage" decimal(8,4),
  "detection_timestamp" timestamptz NOT NULL,
  "is_confirmed" boolean DEFAULT false,
  "root_cause" text,
  "resolution_action" text,
  "resolved_at" timestamptz,
  "model_version" text NOT NULL,
  "additional_context" jsonb
);

CREATE UNIQUE INDEX ON "scout"."table_metadata" ("schema_name", "table_name");

CREATE INDEX ON "scout"."audit_log" ("schema_name", "table_name", "changed_at");

CREATE INDEX ON "scout"."audit_log" ("changed_by", "changed_at");

CREATE INDEX ON "scout"."audit_log" ("changed_at");

CREATE INDEX ON "scout"."psgc_codes" ("region_name", "province_name", "city_municipality");

CREATE INDEX ON "scout"."psgc_codes" ("psgc_code");

CREATE INDEX ON "scout"."psgc_codes" ("island_group");

CREATE INDEX ON "scout"."philippine_holidays" ("holiday_date");

CREATE INDEX ON "scout"."philippine_holidays" ("holiday_type", "holiday_date");

CREATE INDEX ON "scout_bronze"."raw_transactions" ("source_system", "ingestion_timestamp");

CREATE INDEX ON "scout_bronze"."raw_transactions" ("external_transaction_id");

CREATE INDEX ON "scout_bronze"."raw_transactions" ("batch_id");

CREATE INDEX ON "scout_bronze"."raw_transactions" ("validation_status");

CREATE INDEX ON "scout_bronze"."raw_products" ("source_system", "external_product_id");

CREATE INDEX ON "scout_bronze"."raw_products" ("ingestion_timestamp");

CREATE INDEX ON "scout_bronze"."raw_customers" ("source_system", "external_customer_id");

CREATE INDEX ON "scout_bronze"."raw_customers" ("ingestion_timestamp");

CREATE INDEX ON "scout_silver"."transactions" ("store_id", "transaction_date");

CREATE INDEX ON "scout_silver"."transactions" ("customer_id", "transaction_date");

CREATE INDEX ON "scout_silver"."transactions" ("transaction_date");

CREATE INDEX ON "scout_silver"."transactions" ("transaction_status");

CREATE INDEX ON "scout_silver"."transaction_items" ("transaction_id");

CREATE INDEX ON "scout_silver"."transaction_items" ("product_id", "transaction_id");

CREATE INDEX ON "scout_silver"."transaction_items" ("product_sku");

CREATE INDEX ON "scout_silver"."stores" ("region", "province", "city");

CREATE INDEX ON "scout_silver"."stores" ("psgc_code");

CREATE INDEX ON "scout_silver"."stores" ("status");

CREATE INDEX ON "scout_silver"."products" ("category", "subcategory", "brand");

CREATE INDEX ON "scout_silver"."products" ("barcode");

CREATE INDEX ON "scout_silver"."products" ("is_active");

CREATE INDEX ON "scout_silver"."customers" ("region", "province", "city");

CREATE INDEX ON "scout_silver"."customers" ("loyalty_tier");

CREATE INDEX ON "scout_silver"."customers" ("customer_status");

CREATE INDEX ON "scout_silver"."customers" ("last_transaction_date");

CREATE UNIQUE INDEX ON "scout_gold"."kpi_daily_summary" ("date", "store_id");

CREATE INDEX ON "scout_gold"."kpi_daily_summary" ("date");

CREATE INDEX ON "scout_gold"."kpi_daily_summary" ("store_id");

CREATE INDEX ON "scout_gold"."product_performance" ("product_sku", "time_period", "period_start");

CREATE INDEX ON "scout_gold"."product_performance" ("category", "time_period", "period_start");

CREATE INDEX ON "scout_gold"."product_performance" ("velocity_rank", "time_period", "period_start");

CREATE INDEX ON "scout_gold"."customer_segments" ("customer_id", "segment_date");

CREATE INDEX ON "scout_gold"."customer_segments" ("segment_name", "segment_date");

CREATE INDEX ON "scout_gold"."customer_segments" ("churn_probability", "segment_date");

CREATE INDEX ON "scout_gold"."store_performance" ("store_id", "time_period", "period_start");

CREATE INDEX ON "scout_gold"."store_performance" ("performance_tier", "time_period", "period_start");

CREATE INDEX ON "scout_gold"."store_performance" ("region_rank", "time_period", "period_start");

CREATE UNIQUE INDEX ON "scout_gold"."market_basket_analysis" ("product_a_sku", "product_b_sku", "analysis_period_start");

CREATE INDEX ON "scout_gold"."market_basket_analysis" ("lift", "analysis_period_start");

CREATE INDEX ON "scout_gold"."market_basket_analysis" ("is_significant");

CREATE UNIQUE INDEX ON "scout_platinum"."demand_forecast" ("product_sku", "store_id", "forecast_date");

CREATE INDEX ON "scout_platinum"."demand_forecast" ("forecast_date", "model_accuracy");

CREATE INDEX ON "scout_platinum"."price_optimization" ("product_sku", "store_id", "valid_from");

CREATE INDEX ON "scout_platinum"."price_optimization" ("recommendation_confidence", "valid_from");

CREATE INDEX ON "scout_platinum"."customer_lifetime_value" ("customer_id", "prediction_date");

CREATE INDEX ON "scout_platinum"."customer_lifetime_value" ("churn_risk_score", "prediction_date");

CREATE INDEX ON "scout_platinum"."customer_lifetime_value" ("clv_percentile", "prediction_date");

CREATE INDEX ON "scout_platinum"."anomaly_detection" ("anomaly_type", "detection_timestamp");

CREATE INDEX ON "scout_platinum"."anomaly_detection" ("entity_type", "entity_id", "detection_timestamp");

CREATE INDEX ON "scout_platinum"."anomaly_detection" ("anomaly_score", "detection_timestamp");

CREATE INDEX ON "scout_platinum"."anomaly_detection" ("is_confirmed");

COMMENT ON TABLE "scout"."schema_registry" IS 'Central registry for all schemas in the Scout platform';

COMMENT ON COLUMN "scout"."schema_registry"."access_level" IS 'public, authenticated, internal, service';

COMMENT ON COLUMN "scout"."schema_registry"."data_classification" IS 'public, internal, confidential, restricted';

COMMENT ON TABLE "scout"."table_metadata" IS 'Metadata and governance information for all tables';

COMMENT ON COLUMN "scout"."table_metadata"."data_source" IS 'POS, API, File Import, Manual Entry';

COMMENT ON COLUMN "scout"."table_metadata"."update_frequency" IS 'Real-time, Hourly, Daily, Weekly';

COMMENT ON COLUMN "scout"."table_metadata"."quality_score" IS 'Quality score 0-100';

COMMENT ON TABLE "scout"."data_lineage" IS 'Data lineage tracking across all transformation layers';

COMMENT ON COLUMN "scout"."data_lineage"."transformation_type" IS 'ETL, ELT, View, Function';

COMMENT ON COLUMN "scout"."data_lineage"."dependency_level" IS 'Depth in transformation chain';

COMMENT ON TABLE "scout"."audit_log" IS 'Complete audit trail for all data modifications';

COMMENT ON COLUMN "scout"."audit_log"."operation_type" IS 'INSERT, UPDATE, DELETE, TRUNCATE';

COMMENT ON COLUMN "scout"."audit_log"."changed_by" IS 'User ID from auth.users';

COMMENT ON TABLE "scout"."psgc_codes" IS 'Philippine Standard Geographic Classification for location standardization';

COMMENT ON COLUMN "scout"."psgc_codes"."geographic_level" IS 'REGION, PROVINCE, CITY, MUNICIPALITY, BARANGAY';

COMMENT ON COLUMN "scout"."psgc_codes"."island_group" IS 'LUZON, VISAYAS, MINDANAO';

COMMENT ON COLUMN "scout"."psgc_codes"."economic_zone" IS 'CBD, RESIDENTIAL, INDUSTRIAL, RURAL';

COMMENT ON TABLE "scout"."philippine_holidays" IS 'Philippine holidays for sales pattern analysis and forecasting';

COMMENT ON COLUMN "scout"."philippine_holidays"."holiday_type" IS 'NATIONAL, REGIONAL, RELIGIOUS, SPECIAL';

COMMENT ON COLUMN "scout"."philippine_holidays"."affected_regions" IS 'Array of regions if not nationwide';

COMMENT ON COLUMN "scout"."philippine_holidays"."business_impact" IS 'HIGH, MEDIUM, LOW based on shopping behavior';

COMMENT ON TABLE "scout_bronze"."raw_transactions" IS 'Raw transaction data from all sources before any processing';

COMMENT ON COLUMN "scout_bronze"."raw_transactions"."source_system" IS 'POS_SYSTEM, ECOMMERCE, MOBILE_APP';

COMMENT ON COLUMN "scout_bronze"."raw_transactions"."raw_payload" IS 'Original transaction data as received';

COMMENT ON COLUMN "scout_bronze"."raw_transactions"."file_name" IS 'Source file if batch import';

COMMENT ON COLUMN "scout_bronze"."raw_transactions"."batch_id" IS 'Batch processing identifier';

COMMENT ON COLUMN "scout_bronze"."raw_transactions"."validation_status" IS 'PENDING, VALIDATED, FAILED';

COMMENT ON TABLE "scout_bronze"."raw_products" IS 'Raw product catalog data from all sources';

COMMENT ON TABLE "scout_bronze"."raw_customers" IS 'Raw customer data with PII protection';

COMMENT ON TABLE "scout_silver"."transactions" IS 'Cleaned and validated transactions ready for analytics';

COMMENT ON COLUMN "scout_silver"."transactions"."payment_method" IS 'CASH, CARD, GCASH, PAYMAYA, INSTALLMENT';

COMMENT ON COLUMN "scout_silver"."transactions"."transaction_status" IS 'COMPLETED, VOIDED, REFUNDED, PARTIAL_REFUND';

COMMENT ON TABLE "scout_silver"."transaction_items" IS 'Individual line items from transactions';

COMMENT ON COLUMN "scout_silver"."transaction_items"."cost_of_goods" IS 'For margin calculations';

COMMENT ON TABLE "scout_silver"."stores" IS 'Philippine store locations with geographic and operational data';

COMMENT ON COLUMN "scout_silver"."stores"."store_type" IS 'FLAGSHIP, REGULAR, OUTLET, KIOSK';

COMMENT ON COLUMN "scout_silver"."stores"."region" IS 'NCR, LUZON, VISAYAS, MINDANAO';

COMMENT ON COLUMN "scout_silver"."stores"."psgc_code" IS 'Philippine Standard Geographic Code';

COMMENT ON COLUMN "scout_silver"."stores"."status" IS 'ACTIVE, INACTIVE, TEMPORARY_CLOSED';

COMMENT ON TABLE "scout_silver"."products" IS 'Product catalog with Philippine market specifications';

COMMENT ON COLUMN "scout_silver"."products"."dimensions_cm" IS 'LxWxH format';

COMMENT ON TABLE "scout_silver"."customers" IS 'Customer profiles with Philippine demographics and loyalty status';

COMMENT ON COLUMN "scout_silver"."customers"."gender" IS 'M, F, X, PREFER_NOT_TO_SAY';

COMMENT ON COLUMN "scout_silver"."customers"."region" IS 'Customer region for demographic analysis';

COMMENT ON COLUMN "scout_silver"."customers"."preferred_language" IS 'en, fil, ceb, ilo, war';

COMMENT ON COLUMN "scout_silver"."customers"."loyalty_tier" IS 'BRONZE, SILVER, GOLD, PLATINUM';

COMMENT ON COLUMN "scout_silver"."customers"."customer_status" IS 'ACTIVE, INACTIVE, CHURNED';

COMMENT ON COLUMN "scout_silver"."customers"."acquisition_channel" IS 'ORGANIC, REFERRAL, SOCIAL_MEDIA, ADVERTISING';

COMMENT ON TABLE "scout_gold"."kpi_daily_summary" IS 'Daily KPI summary for business intelligence dashboards';

COMMENT ON COLUMN "scout_gold"."kpi_daily_summary"."weather_condition" IS 'For correlation analysis';

COMMENT ON TABLE "scout_gold"."product_performance" IS 'Product performance analytics across different time periods';

COMMENT ON COLUMN "scout_gold"."product_performance"."time_period" IS 'DAILY, WEEKLY, MONTHLY, QUARTERLY';

COMMENT ON COLUMN "scout_gold"."product_performance"."abc_classification" IS 'A (Fast), B (Medium), C (Slow)';

COMMENT ON TABLE "scout_gold"."customer_segments" IS 'Customer segmentation and behavior analysis for marketing';

COMMENT ON COLUMN "scout_gold"."customer_segments"."segment_name" IS 'HIGH_VALUE, FREQUENT, OCCASIONAL, AT_RISK, CHURNED';

COMMENT ON COLUMN "scout_gold"."customer_segments"."recency_days" IS 'Days since last purchase';

COMMENT ON COLUMN "scout_gold"."customer_segments"."frequency_score" IS 'Transaction frequency score 1-5';

COMMENT ON COLUMN "scout_gold"."customer_segments"."monetary_score" IS 'Spending level score 1-5';

COMMENT ON COLUMN "scout_gold"."customer_segments"."rfm_segment" IS 'RFM analysis result';

COMMENT ON COLUMN "scout_gold"."customer_segments"."churn_probability" IS 'Probability of churn 0-1';

COMMENT ON COLUMN "scout_gold"."customer_segments"."recommended_actions" IS 'Marketing recommendations';

COMMENT ON TABLE "scout_gold"."store_performance" IS 'Store performance metrics and rankings for operational insights';

COMMENT ON COLUMN "scout_gold"."store_performance"."time_period" IS 'WEEKLY, MONTHLY, QUARTERLY, YEARLY';

COMMENT ON COLUMN "scout_gold"."store_performance"."conversion_rate" IS 'Transactions per customer visit';

COMMENT ON COLUMN "scout_gold"."store_performance"."customer_satisfaction_score" IS '1-5 rating';

COMMENT ON COLUMN "scout_gold"."store_performance"."performance_tier" IS 'TOP_PERFORMER, ABOVE_AVERAGE, AVERAGE, BELOW_AVERAGE, UNDERPERFORMER';

COMMENT ON TABLE "scout_gold"."market_basket_analysis" IS 'Market basket analysis for product recommendations and cross-selling';

COMMENT ON COLUMN "scout_gold"."market_basket_analysis"."support_count" IS 'Number of transactions with both products';

COMMENT ON COLUMN "scout_gold"."market_basket_analysis"."confidence" IS 'P(B|A) - probability of B given A';

COMMENT ON COLUMN "scout_gold"."market_basket_analysis"."lift" IS 'Strength of association';

COMMENT ON COLUMN "scout_gold"."market_basket_analysis"."conviction" IS 'How much more likely B is without A';

COMMENT ON COLUMN "scout_gold"."market_basket_analysis"."is_significant" IS 'Statistical significance flag';

COMMENT ON TABLE "scout_platinum"."demand_forecast" IS 'ML-powered demand forecasting for inventory optimization';

COMMENT ON COLUMN "scout_platinum"."demand_forecast"."model_accuracy" IS 'Model accuracy score 0-1';

COMMENT ON COLUMN "scout_platinum"."demand_forecast"."external_factors" IS 'Weather, holidays, promotions impact';

COMMENT ON TABLE "scout_platinum"."price_optimization" IS 'AI-driven price optimization recommendations';

COMMENT ON COLUMN "scout_platinum"."price_optimization"."price_elasticity" IS 'Price sensitivity coefficient';

COMMENT ON TABLE "scout_platinum"."customer_lifetime_value" IS 'ML-driven customer lifetime value predictions and risk assessment';

COMMENT ON COLUMN "scout_platinum"."customer_lifetime_value"."predicted_clv" IS 'Predicted Customer Lifetime Value';

COMMENT ON COLUMN "scout_platinum"."customer_lifetime_value"."historical_clv" IS 'Current CLV to date';

COMMENT ON COLUMN "scout_platinum"."customer_lifetime_value"."clv_percentile" IS 'Percentile rank 1-100';

COMMENT ON COLUMN "scout_platinum"."customer_lifetime_value"."churn_risk_score" IS '0 = low risk, 1 = high risk';

COMMENT ON COLUMN "scout_platinum"."customer_lifetime_value"."customer_stage" IS 'PROSPECT, NEW, DEVELOPING, ESTABLISHED, LOYAL, AT_RISK';

COMMENT ON COLUMN "scout_platinum"."customer_lifetime_value"."key_value_drivers" IS 'Factors that drive customer value';

COMMENT ON TABLE "scout_platinum"."anomaly_detection" IS 'ML-powered anomaly detection across all business entities';

COMMENT ON COLUMN "scout_platinum"."anomaly_detection"."anomaly_type" IS 'SALES_DROP, UNUSUAL_PATTERN, FRAUD_RISK, INVENTORY_ISSUE';

COMMENT ON COLUMN "scout_platinum"."anomaly_detection"."entity_type" IS 'STORE, PRODUCT, CUSTOMER, TRANSACTION';

COMMENT ON COLUMN "scout_platinum"."anomaly_detection"."anomaly_score" IS 'Severity score 0-1';

ALTER TABLE "scout_silver"."transactions" ADD FOREIGN KEY ("bronze_source_id") REFERENCES "scout_bronze"."raw_transactions" ("id");

ALTER TABLE "scout_silver"."transaction_items" ADD FOREIGN KEY ("transaction_id") REFERENCES "scout_silver"."transactions" ("id");

ALTER TABLE "scout_gold"."kpi_daily_summary" ADD FOREIGN KEY ("store_id") REFERENCES "scout_silver"."stores" ("id");

ALTER TABLE "scout_gold"."customer_segments" ADD FOREIGN KEY ("customer_id") REFERENCES "scout_silver"."customers" ("id");

ALTER TABLE "scout_gold"."store_performance" ADD FOREIGN KEY ("store_id") REFERENCES "scout_silver"."stores" ("id");

ALTER TABLE "scout_platinum"."demand_forecast" ADD FOREIGN KEY ("store_id") REFERENCES "scout_silver"."stores" ("id");

ALTER TABLE "scout_platinum"."price_optimization" ADD FOREIGN KEY ("store_id") REFERENCES "scout_silver"."stores" ("id");

ALTER TABLE "scout_platinum"."customer_lifetime_value" ADD FOREIGN KEY ("customer_id") REFERENCES "scout_silver"."customers" ("id");
