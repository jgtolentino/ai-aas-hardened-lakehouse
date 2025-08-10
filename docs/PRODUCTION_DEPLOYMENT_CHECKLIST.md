# Production Deployment Checklist

## 🚀 Scout Analytics Platform - Production Deployment

This checklist ensures a safe and complete deployment of the Scout Analytics Platform with its Bronze → Silver → Gold → Platinum medallion architecture.

---

## Pre-Deployment Verification

### 1. Environment Setup
- [ ] **Supabase Project**
  - [ ] Project URL confirmed: `https://cxzllzyxwpyptfretryc.supabase.co`
  - [ ] Service role key stored securely
  - [ ] Anon key available for public access
  - [ ] Database connection string tested

### 2. Access Credentials
- [ ] **GitHub Secrets Configured**
  ```
  SUPABASE_URL
  SUPABASE_SERVICE_KEY
  SUPABASE_ANON_KEY
  PGURI
  SUPABASE_JWT_SECRET
  ```
- [ ] **Edge Device Tokens**
  - [ ] `storage_uploader` role created
  - [ ] JWT tokens generated for colleagues
  - [ ] Token expiry dates documented

### 3. Code Review
- [ ] All SQL migrations reviewed
- [ ] TypeScript/JavaScript linted
- [ ] No hardcoded credentials
- [ ] Error handling implemented
- [ ] Retry logic in place

---

## Database Deployment

### 4. Medallion Architecture Setup
```sql
-- Run migrations in order:
015_medallion_buckets.sql
016_medallion_storage_policies.sql  
017_medallion_schemas.sql
018_gold_layer.sql
019_platinum_layer.sql
020_monitoring_alerts.sql
```

- [ ] **Bronze Layer**
  - [ ] `scout.bronze_edge_raw` table created
  - [ ] Indexes applied
  - [ ] Partitioning configured (if needed)

- [ ] **Silver Layer**
  - [ ] `scout.silver_edge_events` view created
  - [ ] Data normalization verified

- [ ] **Gold Layer**
  - [ ] All business aggregation views created
  - [ ] Performance optimized with indexes

- [ ] **Platinum Layer**
  - [ ] ML feature tables created
  - [ ] Export functions ready

### 5. Storage Buckets
- [ ] `scout-ingest` bucket created (private)
- [ ] `scout-silver` bucket created (private)
- [ ] `scout-gold` bucket created (private)
- [ ] `scout-platinum` bucket created (private)
- [ ] Storage policies applied
- [ ] Bucket size limits configured

---

## Edge Functions Deployment

### 6. Deploy Functions
```bash
supabase functions deploy ingest-bronze
supabase functions deploy export-platinum
```

- [ ] **ingest-bronze**
  - [ ] Deployed successfully
  - [ ] Storage trigger configured
  - [ ] Error handling tested

- [ ] **export-platinum**
  - [ ] Deployed successfully
  - [ ] Scheduled trigger set up
  - [ ] Export formats verified

---

## Data Pipeline Setup

### 7. Eugene's Data Processing
```bash
export SUPABASE_SERVICE_KEY="your-key"
node scripts/process-all-eugene-data.js
```
- [ ] All 1,220 JSON files processed
- [ ] Bronze table populated
- [ ] No duplicate records
- [ ] Error logs reviewed

### 8. ETL Pipeline
- [ ] Bronze → Silver transformation tested
- [ ] Silver → Gold aggregations verified
- [ ] Gold → Platinum exports working
- [ ] Pipeline monitoring active

---

## Monitoring & Alerts

### 9. Monitoring Setup
- [ ] Dataset freshness tracking enabled
- [ ] Pipeline health metrics configured
- [ ] Alert rules activated
- [ ] Data quality checks scheduled

### 10. Alert Channels
- [ ] Email notifications configured
- [ ] Slack webhook set up (optional)
- [ ] Alert severity levels defined
- [ ] Escalation procedures documented

---

## Security Verification

### 11. Access Control
- [ ] RLS policies enabled on all tables
- [ ] Storage policies restrict uploads
- [ ] Service role key not exposed
- [ ] JWT tokens have appropriate expiry

### 12. Audit Trail
- [ ] Storage access logging enabled
- [ ] Database audit tables created
- [ ] Retention policies defined
- [ ] Compliance requirements met

---

## Performance Testing

### 13. Load Testing
- [ ] Bronze ingestion at scale (1000+ files)
- [ ] Gold view query performance (<1s)
- [ ] Platinum export time acceptable
- [ ] Concurrent user testing passed

### 14. Optimization
- [ ] Database indexes verified
- [ ] View materialization considered
- [ ] Caching strategy implemented
- [ ] CDN configured for static assets

---

## Documentation

### 15. Technical Documentation
- [ ] Architecture diagrams updated
- [ ] API documentation complete
- [ ] Database schema documented
- [ ] Runbooks created

### 16. User Documentation
- [ ] Edge device upload guide distributed
- [ ] Dashboard user manual ready
- [ ] FAQ section populated
- [ ] Video tutorials recorded (optional)

---

## Go-Live Checklist

### 17. Final Verification
- [ ] All migrations applied successfully
- [ ] Sample data flowing through pipeline
- [ ] Dashboards displaying correct data
- [ ] No console errors in applications

### 18. Rollback Plan
- [ ] Database backup taken
- [ ] Rollback scripts prepared
- [ ] Previous version tagged
- [ ] Team notified of go-live window

### 19. Communication
- [ ] Stakeholders notified
- [ ] Edge device operators trained
- [ ] Support team briefed
- [ ] Success metrics defined

---

## Post-Deployment

### 20. Verification
- [ ] First hour: Monitor error logs
- [ ] First day: Check data freshness
- [ ] First week: Review performance metrics
- [ ] First month: Analyze usage patterns

### 21. Optimization
- [ ] Identify slow queries
- [ ] Optimize based on usage
- [ ] Adjust monitoring thresholds
- [ ] Plan next improvements

---

## Sign-offs

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Technical Lead | | | |
| Database Admin | | | |
| Security Officer | | | |
| Product Owner | | | |

---

## Emergency Contacts

- **On-call Engineer**: +1-XXX-XXX-XXXX
- **Supabase Support**: support@supabase.io
- **Escalation**: [Internal escalation matrix]

---

**Deployment Status**: ⬜ Not Started | 🟡 In Progress | ✅ Complete

Last Updated: {{ current_date }}