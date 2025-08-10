# Scout Platform - Disaster Recovery Procedures
## Auto-Generated from Infrastructure Configuration

### 📦 Backup Configuration
```yaml
Source: Supabase Managed Backups
Frequency: Daily @ 02:00 UTC
Retention: 30 days
Type: Point-in-Time Recovery (PITR)
```

### 🔄 Recovery Steps
1. **Identify Recovery Point**
   ```bash
   supabase db list-backups --project-ref $(SUPABASE_PROJECT_REF)
   ```

2. **Initiate Recovery**
   ```bash
   supabase db restore --project-ref $(SUPABASE_PROJECT_REF) \
     --backup-id <BACKUP_ID>
   ```

3. **Validate Data Integrity**
   ```sql
   -- Check transaction counts
   SELECT 
     (SELECT COUNT(*) FROM scout.bronze_transactions_raw) as bronze,
     (SELECT COUNT(*) FROM scout.silver_transactions_cleaned) as silver,
     (SELECT COUNT(*) FROM scout.gold_business_metrics) as gold;
   
   -- Verify latest data
   SELECT MAX(created_at) FROM scout.bronze_transactions_raw;
   ```
