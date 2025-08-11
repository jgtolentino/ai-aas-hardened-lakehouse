# Quick Start Guide

Get up and running with the AI-AAS Hardened Lakehouse in under 30 minutes. This guide will walk you through setting up a local development environment and deploying your first data pipeline.

## 🚀 Prerequisites

Before starting, ensure you have:

- **Docker Desktop** (4.0+ with Kubernetes enabled)
- **Node.js** (18+ LTS version)
- **Git** (latest version)
- **PostgreSQL Client** (psql command-line tool)
- **Supabase CLI** (latest version)

```bash
# Install required tools
npm install -g @supabase/supabase-js
curl -fsSL https://cli.supabase.com | sh

# Verify installations
docker --version
node --version
supabase --version
psql --version
```

## 📁 Project Setup

### 1. **Clone and Initialize**

```bash
# Clone the repository
git clone https://github.com/jgtolentino/ai-aas-hardened-lakehouse.git
cd ai-aas-hardened-lakehouse

# Install dependencies
npm install
cd docs-site && npm install && cd ..

# Set up environment variables
cp .env.example .env.local
```

### 2. **Environment Configuration**

Edit `.env.local` with your configuration:

```bash
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Database Configuration
DATABASE_URL=postgresql://postgres:password@localhost:54322/postgres

# MinIO Configuration (for local development)
MINIO_ENDPOINT=http://localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin

# Authentication
JWT_SECRET=your-jwt-secret-key

# External APIs
MAPBOX_API_KEY=pk.your_mapbox_token_here
```

## 🏗️ Local Development Setup

### 1. **Start Supabase Local Stack**

```bash
# Initialize Supabase project
supabase init

# Start local Supabase stack
supabase start

# This will start:
# - PostgreSQL database on port 54322
# - API Gateway on port 54321
# - Dashboard on http://localhost:54323
# - Edge Functions on port 54324
```

### 2. **Deploy Database Schema**

```bash
# Apply all migrations in order
supabase db reset

# Verify schema deployment
psql postgresql://postgres:postgres@localhost:54322/postgres -c "
  SELECT schemaname, tablename 
  FROM pg_tables 
  WHERE schemaname = 'scout' 
  ORDER BY tablename;"
```

### 3. **Load Sample Data**

```bash
# Load sample datasets
npm run data:load-samples

# Verify data loading
psql postgresql://postgres:postgres@localhost:54322/postgres -c "
  SELECT 
    'dim_store' as table_name, COUNT(*) as row_count 
  FROM scout.dim_store
  UNION ALL
  SELECT 
    'fact_transactions', COUNT(*) 
  FROM scout.fact_transactions;"
```

## 📊 Your First Query

### 1. **Connect to Database**

```bash
# Connect via psql
psql postgresql://postgres:postgres@localhost:54322/postgres

# Or use your preferred SQL client with connection details:
# Host: localhost
# Port: 54322
# Database: postgres
# Username: postgres
# Password: postgres
```

### 2. **Run Sample Queries**

```sql
-- Check available tables
\dt scout.*

-- Get store summary
SELECT 
    region,
    COUNT(*) as store_count,
    COUNT(*) FILTER (WHERE is_active = true) as active_stores
FROM scout.dim_store
GROUP BY region
ORDER BY store_count DESC;

-- Get recent transactions
SELECT 
    s.store_name,
    p.product_name,
    t.transaction_date,
    t.total_amount
FROM scout.fact_transactions t
JOIN scout.dim_store s ON t.store_id = s.store_id
JOIN scout.dim_product p ON t.product_id = p.product_id
ORDER BY t.transaction_date DESC
LIMIT 10;
```

### 3. **Test API Endpoints**

```bash
# Test health endpoint
curl http://localhost:54321/rest/v1/rpc/health_check \
  -H "apikey: YOUR_ANON_KEY"

# Get store data via REST API
curl "http://localhost:54321/rest/v1/dim_store?select=*&limit=5" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"

# Test Edge Function
curl -X POST http://localhost:54324/functions/v1/genie-query \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "Show me top 5 stores by revenue"}'
```

## 🎯 Deploy Your First Pipeline

### 1. **Create a Simple ETL Job**

Create `my-first-pipeline.sql`:

```sql
-- Example: Daily sales summary pipeline
CREATE OR REPLACE FUNCTION scout.daily_sales_summary()
RETURNS void AS $$
BEGIN
    -- Create summary table if not exists
    CREATE TABLE IF NOT EXISTS scout.daily_sales_summary (
        summary_date DATE PRIMARY KEY,
        total_transactions INTEGER,
        total_revenue DECIMAL(12,2),
        unique_customers INTEGER,
        avg_transaction_value DECIMAL(10,2),
        top_store_id TEXT,
        created_at TIMESTAMP DEFAULT NOW()
    );
    
    -- Insert/Update today's summary
    INSERT INTO scout.daily_sales_summary (
        summary_date,
        total_transactions,
        total_revenue,
        unique_customers,
        avg_transaction_value,
        top_store_id
    )
    SELECT 
        CURRENT_DATE,
        COUNT(*) as total_transactions,
        SUM(total_amount) as total_revenue,
        COUNT(DISTINCT customer_id) as unique_customers,
        AVG(total_amount) as avg_transaction_value,
        (
            SELECT store_id 
            FROM scout.fact_transactions 
            WHERE transaction_date = CURRENT_DATE 
            GROUP BY store_id 
            ORDER BY SUM(total_amount) DESC 
            LIMIT 1
        ) as top_store_id
    FROM scout.fact_transactions
    WHERE transaction_date = CURRENT_DATE
    ON CONFLICT (summary_date) DO UPDATE SET
        total_transactions = EXCLUDED.total_transactions,
        total_revenue = EXCLUDED.total_revenue,
        unique_customers = EXCLUDED.unique_customers,
        avg_transaction_value = EXCLUDED.avg_transaction_value,
        top_store_id = EXCLUDED.top_store_id,
        created_at = NOW();
        
    RAISE NOTICE 'Daily sales summary updated for %', CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT scout.daily_sales_summary();

-- Verify results
SELECT * FROM scout.daily_sales_summary ORDER BY summary_date DESC LIMIT 5;
```

### 2. **Schedule the Pipeline**

```sql
-- Install pg_cron extension (if not already installed)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule daily ETL job at 1 AM
SELECT cron.schedule(
    'daily-sales-summary',
    '0 1 * * *',
    'SELECT scout.daily_sales_summary();'
);

-- Verify scheduled jobs
SELECT * FROM cron.job;
```

## 📈 Visualization Setup

### 1. **Start Apache Superset**

```bash
# Using Docker Compose
cd platform/visualization/superset
docker-compose up -d

# Wait for startup (may take 2-3 minutes)
docker-compose logs -f superset

# Access Superset at http://localhost:8088
# Default login: admin / admin
```

### 2. **Configure Database Connection**

In Superset dashboard:

1. Go to **Settings** → **Database Connections**
2. Click **+ Database**
3. Select **PostgreSQL**
4. Enter connection details:
   ```
   Host: host.docker.internal
   Port: 54322
   Database: postgres
   Username: postgres
   Password: postgres
   ```

### 3. **Create Your First Dashboard**

```sql
-- Create a view for Superset visualization
CREATE OR REPLACE VIEW scout.sales_dashboard_data AS
SELECT 
    s.region,
    s.store_name,
    DATE_TRUNC('month', t.transaction_date) as month,
    COUNT(*) as transaction_count,
    SUM(t.total_amount) as revenue,
    AVG(t.total_amount) as avg_transaction_value,
    COUNT(DISTINCT t.customer_id) as unique_customers
FROM scout.fact_transactions t
JOIN scout.dim_store s ON t.store_id = s.store_id
WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY s.region, s.store_name, DATE_TRUNC('month', t.transaction_date);
```

In Superset:
1. Go to **SQL Lab** → **SQL Editor**
2. Test query: `SELECT * FROM scout.sales_dashboard_data LIMIT 10;`
3. Go to **Charts** → **+ Chart**
4. Select your dataset and create visualizations

## 🔒 Security Setup

### 1. **Enable Row Level Security**

```sql
-- Enable RLS on sensitive tables
ALTER TABLE scout.dim_customer ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.fact_transactions ENABLE ROW LEVEL SECURITY;

-- Create basic access policy
CREATE POLICY "authenticated_access" ON scout.fact_transactions
  FOR ALL TO authenticated USING (true);

-- Create region-based policy (example)
CREATE POLICY "regional_access" ON scout.dim_store
  FOR SELECT TO authenticated
  USING (region = (auth.jwt() ->> 'region')::TEXT);
```

### 2. **Set Up API Authentication**

```javascript
// Example client-side authentication
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'http://localhost:54321',
  'your-anon-key'
)

// Sign up/in user
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'securepassword'
})

// Query with authentication
const { data: stores } = await supabase
  .from('dim_store')
  .select('*')
  .limit(10)
```

## 🧪 Testing Your Setup

### 1. **Run Data Quality Checks**

```sql
-- Test data integrity
SELECT scout.validate_transaction_data();

-- Check recent data loading
SELECT 
    MAX(transaction_date) as latest_date,
    COUNT(*) as recent_transactions
FROM scout.fact_transactions 
WHERE transaction_date >= CURRENT_DATE - INTERVAL '7 days';
```

### 2. **Performance Testing**

```sql
-- Test query performance
EXPLAIN (ANALYZE, BUFFERS) 
SELECT 
    s.region,
    SUM(t.total_amount) as revenue
FROM scout.fact_transactions t
JOIN scout.dim_store s ON t.store_id = s.store_id
WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY s.region;
```

### 3. **API Load Testing**

```bash
# Install Apache Bench
sudo apt-get install apache2-utils  # Ubuntu/Debian
brew install httpie                  # macOS

# Test API endpoint
ab -n 100 -c 10 \
  -H "apikey: YOUR_ANON_KEY" \
  "http://localhost:54321/rest/v1/dim_store?limit=10"
```

## 🚀 Next Steps

Now that you have a working setup:

### **Data Engineering**
- [Data Ingestion Guide](./data-ingestion.md) - Load real data from various sources
- [ETL Pipeline Development](../implementation/etl-pipelines.md) - Build production ETL jobs
- [Data Quality Monitoring](../operations/data-quality.md) - Implement data validation

### **Analytics & ML**
- [Advanced Analytics](../api-reference/advanced-analytics.md) - Complex analytical queries
- [ML Model Deployment](./ai-model-deployment.md) - Deploy machine learning models
- [Feature Store Setup](../implementation/feature-store.md) - ML feature management

### **Production Deployment**
- [Kubernetes Deployment](../implementation/k8s-deployment.md) - Production deployment
- [Security Hardening](../security/hardening-guide.md) - Enterprise security
- [Monitoring Setup](../operations/monitoring.md) - Observability stack

### **Visualization & Dashboards**
- [Advanced Superset](../tutorials/superset-advanced.md) - Custom visualizations
- [Embedded Analytics](../implementation/embedded-analytics.md) - Embed in your apps
- [Geographic Visualization](../tutorials/mapbox-integration.md) - Maps and spatial data

## 🆘 Troubleshooting

### **Common Issues**

#### **Supabase won't start**
```bash
# Check Docker status
docker ps

# Restart Supabase
supabase stop
supabase start

# Check logs
supabase status
```

#### **Database connection fails**
```bash
# Verify PostgreSQL is running
psql postgresql://postgres:postgres@localhost:54322/postgres -c "SELECT 1;"

# Check port availability
netstat -an | grep 54322
```

#### **Sample data not loading**
```bash
# Check migration status
supabase migration list

# Reset database
supabase db reset

# Verify table creation
psql postgresql://postgres:postgres@localhost:54322/postgres -c "\dt scout.*"
```

#### **API endpoints returning errors**
```bash
# Check Supabase logs
supabase logs

# Verify API key
curl http://localhost:54321/rest/v1/ -H "apikey: YOUR_ANON_KEY"

# Test basic connectivity
curl http://localhost:54321/health
```

### **Getting Help**

- **Documentation**: Check the [comprehensive docs](../overview.md)
- **GitHub Issues**: Report bugs and feature requests
- **Community**: Join our discussions and ask questions

Congratulations! You now have a fully functional AI-AAS Hardened Lakehouse environment running locally. 🎉