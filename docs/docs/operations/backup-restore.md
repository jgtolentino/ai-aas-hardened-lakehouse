# Backup & Restore Procedures

## 🔒 Backup Strategy

### Automated Backups
- **Frequency**: Every 6 hours
- **Retention**: 30 days
- **Type**: Full + incremental
- **Storage**: S3 with encryption

### Manual Backup
```bash
# Full database backup
pg_dump $PGURI -Fc -f scout_backup_$(date +%Y%m%d_%H%M%S).dump

# Specific schema backup
pg_dump $PGURI -n scout -Fc -f scout_schema_$(date +%Y%m%d_%H%M%S).dump

# Upload to S3
aws s3 cp scout_backup_*.dump s3://scout-backups/manual/
```

## 🔄 Restore Procedures

### Full Restore
```bash
# Create restore database
createdb -h $DB_HOST -U postgres scout_restore

# Restore from backup
pg_restore -h $DB_HOST -U postgres -d scout_restore -v backup.dump

# Verify restore
psql -h $DB_HOST -U postgres -d scout_restore -c "SELECT COUNT(*) FROM scout.silver_transactions;"

# Swap databases (requires downtime)
psql -h $DB_HOST -U postgres <<SQL
ALTER DATABASE scout RENAME TO scout_old;
ALTER DATABASE scout_restore RENAME TO scout;
SQL
```

### Point-in-Time Recovery
```bash
# Restore to specific timestamp
pg_restore -h $DB_HOST -U postgres -d scout_restore \
  --recovery-target-time="2024-01-15 10:30:00" \
  backup.dump
```

## 📊 Backup Verification

### Daily Verification Script
```bash
#!/bin/bash
# verify_backups.sh

LATEST_BACKUP=$(aws s3 ls s3://scout-backups/ | tail -1 | awk '{print $4}')
TEMP_DB="verify_$(date +%s)"

# Download latest backup
aws s3 cp s3://scout-backups/$LATEST_BACKUP /tmp/

# Create temp database
createdb $TEMP_DB

# Restore and verify
pg_restore -d $TEMP_DB /tmp/$LATEST_BACKUP

# Run verification queries
psql -d $TEMP_DB <<SQL
SELECT 'Tables', COUNT(*) FROM information_schema.tables WHERE table_schema = 'scout';
SELECT 'Transactions', COUNT(*) FROM scout.silver_transactions;
SELECT 'Latest Transaction', MAX(ts) FROM scout.silver_transactions;
SQL

# Cleanup
dropdb $TEMP_DB
rm /tmp/$LATEST_BACKUP
```

## 🚨 Disaster Recovery

### RTO/RPO Targets
- **RTO (Recovery Time Objective)**: 4 hours
- **RPO (Recovery Point Objective)**: 6 hours

### DR Checklist
1. [ ] Identify failure scope
2. [ ] Activate DR team
3. [ ] Retrieve latest backup
4. [ ] Provision new infrastructure
5. [ ] Restore database
6. [ ] Update DNS/load balancers
7. [ ] Verify application functionality
8. [ ] Monitor for issues
