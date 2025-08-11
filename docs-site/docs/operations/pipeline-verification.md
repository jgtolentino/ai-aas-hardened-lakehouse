# Pipeline Verification & Traceability

## Quick Health
```sql
select * from scout.pipeline_health_check();
```

## Per-file Trace (Bronze → Silver → Gold)

```sql
select * from scout.verify_file('edge-inbox/batch1.zip');
```

## ZIP Pipeline Status

```sql
select * from scout.v_zip_pipeline_status order by finished_at desc nulls last;
```

## Stuck Files

```sql
select * from scout.v_pipeline_panic;
```

## Verification Examples

### Check Specific ZIP Files
```sql
-- Check our target files
select * from scout.verify_file('edge-inbox/json.zip');
select * from scout.verify_file('edge-inbox/scoutpi-0003.zip');
```

### Monitor Processing Progress
```sql
-- Overall pipeline status
select * from scout.v_zip_pipeline_status 
where file_name in ('edge-inbox/json.zip', 'edge-inbox/scoutpi-0003.zip');

-- Detailed layer counts
select 
    layer,
    count(*) as records,
    count(distinct source_file) as unique_files,
    min(ts) as earliest_record,
    max(ts) as latest_record
from scout.verify_file('edge-inbox/json.zip')
group by layer
order by case layer when 'Bronze' then 1 when 'Silver' then 2 when 'Gold-Fact' then 3 end;
```

### Health Monitoring
```sql
-- Check for any stuck files
select * from scout.v_pipeline_panic;

-- Queue status
select status, count(*) as files, sum(size_bytes)/1024/1024 as total_mb
from scout.etl_queue 
group by status;

-- Processing performance
select 
    file_name,
    extract(epoch from (finished_at - started_at)) as processing_seconds,
    round(size_bytes/1024/1024.0, 2) as size_mb
from scout.etl_queue 
where status = 'DONE' and finished_at > now() - interval '24 hours'
order by processing_seconds desc;
```