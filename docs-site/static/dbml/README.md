# Scout Analytics Platform - Database Schema Documentation

This directory contains the complete database schema documentation for the Scout Analytics Platform v5, implemented using DBML (Database Markup Language).

## 📁 Files

- **`scout-schema-complete.dbml`** - Complete database schema with inline data dictionary
- **`README.md`** - This file

## 🏗️ Schema Overview

The Scout platform implements a **Medallion Architecture** with four distinct layers:

### 🥉 Bronze Layer
- Raw data ingestion from multiple sources
- No transformation, maintains source format
- Short retention (90 days)
- Example: `scout.bronze_sales_raw`

### 🥈 Silver Layer  
- Cleaned, validated, and standardized data
- Business rules applied
- Medium retention (2 years)
- Example: `scout.silver_transactions`

### 🥇 Gold Layer
- Business-ready aggregated metrics
- Optimized for analytics and reporting
- Long retention (5 years)
- Examples: `scout.gold_txn_daily`, `scout.gold_product_mix`

### 💎 Platinum Layer
- ML-ready feature store
- Real-time recommendation features
- Rolling window aggregations
- Example: `scout.platinum_features_sales_7d`

## 📊 Key Schema Components

### Master Data (Dimensions)
- `dim_store` - Store/outlet master data with Philippine geographic hierarchy
- `dim_product` - Product catalog with categories and pricing
- `dim_customer` - Customer profiles with privacy-compliant PII handling
- `dim_campaign` - Marketing campaign definitions

### Fact Tables
- `fact_transactions` - Core transaction records (grain: receipt)
- `fact_transaction_items` - Line item details (grain: product per receipt)

### Analytics Views
- Transaction trends and patterns
- Product performance and Pareto analysis
- Market basket analysis and affinities
- Customer segmentation and behavior
- Store performance metrics

### ML Features
- 7-day and 28-day rolling windows
- Store vitality scores
- Customer segment features
- Recommendation candidates

## 🔒 Security Features

### Row-Level Security (RLS)
- Implemented on all tables
- Role-based access control
- Geographic and brand restrictions

### Audit Trail
- Comprehensive logging of all data modifications
- 7-year retention for compliance
- Forensic analysis capabilities

### PII Protection
- Hashed mobile numbers and emails
- Column-level encryption
- Access logging for sensitive data

## 📈 Performance Optimizations

### Strategic Indexes
- Composite indexes on common query patterns
- Covering indexes for read-heavy operations
- Partial indexes for filtered queries

### Materialized Views
- Pre-aggregated metrics for dashboards
- Automatic refresh every 5-15 minutes
- Concurrent refresh to avoid locks

### Partitioning Strategy
- Time-based partitioning for fact tables
- List partitioning by region for geographic queries
- Automatic partition management

## 🚀 Usage

### Viewing the Schema

1. **Online Viewer**: Upload `scout-schema-complete.dbml` to [dbdiagram.io](https://dbdiagram.io)
2. **VS Code**: Install the DBML extension for syntax highlighting
3. **Generate SQL**: Use DBML CLI to generate DDL scripts

### Generating SQL from DBML

```bash
# Install DBML CLI
npm install -g @dbml/cli

# Generate PostgreSQL DDL
dbml2sql scout-schema-complete.dbml -o scout-schema.sql

# Generate specific database dialect
dbml2sql scout-schema-complete.dbml --postgres -o scout-postgres.sql
```

### Generating Documentation

```bash
# Generate HTML documentation
dbdocs build scout-schema-complete.dbml

# Generate Markdown
dbml2md scout-schema-complete.dbml -o scout-schema.md
```

## 📝 Data Dictionary Format

Each table and column includes inline documentation:

```dbml
Table scout.example {
  id TEXT [pk, note: 'Unique identifier']
  name TEXT [not null, note: 'Display name']
  created_at TIMESTAMP [default: `NOW()`, note: 'Record creation time']
  
  Note: 'Table-level description and business context'
}
```

## 🔄 Schema Versioning

- Current Version: **5.0**
- Last Updated: January 2025
- Backward Compatibility: Maintained for 2 major versions

## 📚 Related Documentation

- [Architecture Overview](../../docs/architecture/overview.md)
- [API Reference](../../docs/api-reference/sql-interfaces.md)
- [Security Guide](../../docs/security/hardening-guide.md)
- [Operations Runbooks](../../docs/operations/monitoring.md)

## 🤝 Contributing

When modifying the schema:

1. Update the DBML file with clear notes
2. Regenerate SQL scripts
3. Update migration files
4. Test with sample data
5. Update this README if needed

## 📧 Contact

For questions about the schema:
- Technical Lead: platform@scout-analytics.ph
- Slack: #scout-platform
- GitHub Issues: [Create Issue](https://github.com/jgtolentino/ai-aas-hardened-lakehouse/issues)

---

*This schema documentation is automatically synchronized with the live database schema through CI/CD pipelines.*