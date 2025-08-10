# 🚀 Scout Analytics Hardened Lakehouse - Deployment Checklist

This checklist ensures all components of the hardened lakehouse with geographic visualization are properly deployed.

## 📋 Pre-Deployment

### Environment Variables
- [ ] `PGURI` - PostgreSQL connection string
- [ ] `MAPBOX_API_KEY` - Valid Mapbox token (starts with `pk.`)
- [ ] `SUPABASE_URL` - Supabase project URL
- [ ] `SUPABASE_ANON_KEY` - Supabase anonymous key
- [ ] `SUPABASE_SERVICE_KEY` - Supabase service role key

### Infrastructure Requirements
- [ ] PostgreSQL 14+ with PostGIS extension
- [ ] Kubernetes cluster (1.24+)
- [ ] Redis instance for caching
- [ ] 16GB+ RAM for Superset workers
- [ ] 100GB+ storage for geographic data

## 🗄️ Database Setup

### 1. Apply Core Migrations
```bash
# Bronze/Silver/Gold architecture
psql "$PGURI" -f platform/scout/migrations/001_bronze.sql
psql "$PGURI" -f platform/scout/migrations/002_silver.sql
psql "$PGURI" -f platform/scout/migrations/003_gold.sql
psql "$PGURI" -f platform/scout/migrations/004_platinum.sql
psql "$PGURI" -f platform/scout/migrations/005_mv.sql

# Hardening features
psql "$PGURI" -f platform/scout/migrations/006_ingest_idempotency.sql
psql "$PGURI" -f platform/scout/migrations/007_gold_refresh.sql
psql "$PGURI" -f platform/scout/migrations/008_rls.sql
psql "$PGURI" -f platform/scout/migrations/009_validation.sql
```
- [ ] All migrations applied successfully
- [ ] No errors in migration output

### 2. Apply Geographic Migrations
```bash
# PostGIS and boundaries
psql "$PGURI" -f platform/scout/migrations/010_geo_boundaries.sql
psql "$PGURI" -f platform/scout/migrations/011_geo_normalizers.sql
psql "$PGURI" -f platform/scout/migrations/012_geo_gold_views.sql
psql "$PGURI" -f platform/scout/migrations/013_geo_performance_indexes.sql
```
- [ ] PostGIS extension enabled
- [ ] Geo tables created
- [ ] GIST indexes created

### 3. Load Boundary Data
```bash
kubectl apply -f platform/lakehouse/jobs/geo-importer.yaml
kubectl -n aaas wait --for=condition=complete job/geo-boundary-importer --timeout=30m
```
- [ ] 17 regions loaded
- [ ] 80+ provinces loaded
- [ ] 1600+ cities/municipalities loaded

## 🐳 Kubernetes Deployments

### 1. Security Policies
```bash
kubectl apply -f platform/security/gatekeeper/
```
- [ ] Gatekeeper templates applied
- [ ] Container probe policies active
- [ ] Resource limit policies active

### 2. Superset Deployment
```bash
# Create Mapbox secret
kubectl -n aaas create secret generic superset-mapbox \
  --from-literal=MAPBOX_API_KEY="$MAPBOX_API_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy with Helm
helm upgrade --install superset apache/superset \
  -n aaas \
  -f helm-overlays/superset-values-prod.yaml
```
- [ ] Mapbox secret created
- [ ] Superset pods running
- [ ] Environment variables verified

### 3. Import Superset Assets
```bash
bash platform/superset/scripts/import_scout_bundle.sh
```
- [ ] Datasets imported
- [ ] Charts imported
- [ ] Dashboards imported
- [ ] Choropleth visualizations visible

## ✅ Verification Steps

### 1. Database Verification
```bash
bash scripts/verify_geo_deployment.sh
```
- [ ] PostGIS functional
- [ ] Boundary data complete
- [ ] Indexes active
- [ ] Spatial queries working

### 2. Performance Verification
```bash
python3 scripts/benchmark_choropleth_hard.py \
  --pguri "$PGURI" \
  --exit-on-fail
```
- [ ] ADM3 query < 1.5s p95
- [ ] Render < 2.5s p95
- [ ] Join coverage > 99%

### 3. API Testing
```bash
# Run complete Bruno test suite
BRUNO_ENV=production ./scripts/run_bruno_tests.sh
```
- [ ] Authentication passing
- [ ] Core APIs functional
- [ ] Ingestion working
- [ ] Superset integrated
- [ ] Security active
- [ ] Choropleth tests passing

### 4. Complete System Check
```bash
bash scripts/verify_choropleth_complete.sh
```
- [ ] All components green
- [ ] No critical issues

## 🎯 Post-Deployment

### 1. Performance Monitoring
```bash
# Set up monitoring cron
crontab -e
# Add: 0 */6 * * * /opt/scout/scripts/benchmark_choropleth.py --pguri "$PGURI"
```
- [ ] Monitoring scheduled
- [ ] Alerts configured

### 2. Data Loading
```bash
# Load sample data if needed
psql "$PGURI" -f scripts/load_sample_data.sql
```
- [ ] Transaction data loaded
- [ ] Metrics calculating correctly

### 3. User Access
- [ ] Admin accounts created
- [ ] Viewer accounts configured
- [ ] RLS policies tested

## 🔍 Smoke Tests

### Manual UI Verification
1. Access Superset: `kubectl -n aaas port-forward svc/superset 8088:8088`
2. Login with admin credentials
3. Navigate to Dashboards → Scout Analytics
4. Open "Philippines Regional Sales Heatmap"
   - [ ] Map loads with base tiles
   - [ ] Regions colored by metrics
   - [ ] Tooltips show data
   - [ ] Date filters work
5. Open "City/Municipality Sales Intensity Map"
   - [ ] City-level detail visible
   - [ ] Performance acceptable
   - [ ] Drill-down works

### API Quick Checks
```bash
# Check Supabase
curl -H "apikey: $SUPABASE_ANON_KEY" \
  "$SUPABASE_URL/rest/v1/stores?limit=1"

# Check Superset
curl -X POST "$SUPERSET_BASE/api/v1/security/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin","provider":"db"}'
```

## 📊 Success Criteria

### Performance Metrics
- [ ] P95 query latency < 1.5s
- [ ] Choropleth load time < 2.5s
- [ ] API response time < 1.0s
- [ ] 99.9% uptime achieved

### Data Quality
- [ ] >99% geographic join rate
- [ ] Zero duplicate ingestions
- [ ] All validations passing

### Security
- [ ] RLS policies enforced
- [ ] CSRF protection active
- [ ] Secrets properly managed
- [ ] No hardcoded credentials

## 🚨 Rollback Plan

If issues occur:
```bash
# 1. Restore database
psql "$PGURI" -f backups/pre_deployment_backup.sql

# 2. Rollback Helm
helm rollback superset -n aaas

# 3. Remove geographic features
psql "$PGURI" -c "DROP SCHEMA IF EXISTS geo CASCADE;"
```

## 📝 Sign-Off

- [ ] Development team approval
- [ ] Security review completed
- [ ] Performance benchmarks met
- [ ] Documentation updated
- [ ] Runbook created

**Deployment Date**: _______________
**Deployed By**: _______________
**Version**: v1.0.0-hardened

---

## 🆘 Support Contacts

- **Platform Team**: platform@company.com
- **On-Call**: +1-xxx-xxx-xxxx
- **Slack**: #scout-analytics-support

## 📚 Reference Documents

- [Architecture Overview](docs/architecture/README.md)
- [Mapbox Setup Guide](docs/setup/mapbox_setup.md)
- [Performance Tuning](docs/setup/choropleth_optimization.md)
- [Bruno Test Collection](platform/scout/bruno/collection_summary.md)