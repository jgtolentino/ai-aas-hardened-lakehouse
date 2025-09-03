# Scout Database Documentation

## Schema Organization

### Medallion Architecture Layers

1. **Bronze Layer** (`scout.bronze_*`)
   - Raw data ingestion
   - Minimal validation
   - Audit trails

2. **Silver Layer** (`scout.silver_*`)
   - Cleaned and validated data
   - Business rules applied
   - Quality metrics

3. **Gold Layer** (`scout.gold_*`) - **PUBLIC**
   - Business-ready aggregates
   - KPIs and metrics
   - Dashboard-optimized

4. **Platinum Layer** (`scout.platinum_*`) - **PUBLIC**
   - Executive insights
   - Cross-functional analytics
   - Strategic metrics

## Access Control

- **Public Schemas**: `scout.gold*`, `scout.platinum*` 
- **Internal Schemas**: All others require authentication
- **RLS Policies**: Regional access controls implemented

## Documentation

- [Schema Registry](./schema-registry.md)
- [Views Documentation](./views/)
- [Functions Documentation](./functions/)
- [Policies Documentation](./policies/)
