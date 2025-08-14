# Scout Edge: Complete Ingestion Operations Guide

## 🚀 System Overview

The Scout Analytics platform now features a comprehensive multi-source data ingestion pipeline combining:

1. **File Ingestion** - Gmail attachments, Google Drive files, manual uploads
2. **Edge Computing** - Raspberry Pi devices with STT and OpenCV
3. **SKU Scraping** - Web scraping for product catalogs
4. **Real-time Processing** - Unified analytics across all sources

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   DATA SOURCES                          │
├─────────────────────────────────────────────────────────┤
│ 📧 Gmail    │ 📁 Drive   │ 🖥️ Edge    │ 🌐 Web       │
│ Attachments │ Folders    │ Pi Devices │ Scraping     │
└──────┬──────┴─────┬──────┴──────┬─────┴────────┬──────┘
       │            │             │              │
       ▼            ▼             ▼              ▼
┌─────────────────────────────────────────────────────────┐
│              INGESTION LAYER                            │
│  • File Queue      • Edge Events   • Scraping Jobs     │
│  • Auto-triggers   • STT/OpenCV    • Rate Limiting     │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│            PROCESSING ENGINE                            │
│  • Type Handlers   • Brand Resolution  • SKU Matching  │
│  • Retry Logic     • Quality Scoring   • Deduplication │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│           UNIFIED ANALYTICS                             │
│  • Scout Schema    • Edge Schema     • Master Catalog  │
│  • Gold Tables     • Real-time Views • KPI Dashboards  │
└─────────────────────────────────────────────────────────┘
```

## 📧 File Ingestion System

### Auto-Trigger Configuration

| Email Subject Pattern | Action | File Types | Store |
|---------------------|--------|------------|-------|
| `Scout Data Upload%` | Auto-ingest | JSON, CSV, ZIP | STORE_001 |
| `Daily Sales Report%` | Auto-ingest | CSV, Excel | By sender |
| `POS Export%` | Auto-ingest | JSON, ZIP | STORE_002 |
| `Transcript%` | Auto-ingest | SRT, VTT | STORE_003 |

### API Usage

```sql
-- 1. Gmail attachment processing
SELECT api.ingest_from_gmail(
    'msg_id', 'subject', 'sender@email.com',
    '[{"filename": "data.json", "size": 1024, "id": "att_1"}]'
);

-- 2. Manual file upload
SELECT api.upload_file('filename.json', '{"data": "content"}', 'STORE_001');

-- 3. Batch upload
SELECT api.batch_ingest_files('[
    {"name": "file1.json", "content": "{}", "store_id": "STORE_001"},
    {"name": "file2.csv", "content": "csv,data", "store_id": "STORE_002"}
]');

-- 4. Google Drive file
SELECT api.ingest_from_drive(
    'file_id', 'filename.json', '/Scout Analytics/Data', 'content'
);
```

### Monitoring

```sql
-- Check ingestion dashboard
SELECT * FROM scout.get_ingestion_dashboard();

-- View queue status
SELECT status, count(*) FROM scout.file_ingestion_queue GROUP BY status;

-- Check processing performance
SELECT * FROM scout.v_ingestion_performance;
```

## 🖥️ Edge Device Management

### Device Fleet

| Device ID | Location | Capabilities | Store |
|-----------|----------|--------------|-------|
| PI5_STORE_001 | SM Manila | STT, OpenCV | STORE_001 |
| PI5_STORE_002 | Robinsons Galleria | STT, OpenCV | STORE_002 |
| PI5_STORE_003 | Ayala Center | STT, OpenCV, Motion | STORE_003 |

### Event Ingestion

```sql
-- STT event from device
SELECT edge.ingest_edge_event(
    'PI5_STORE_001',
    'stt',
    '{"transcript": "lucky me noodles", "brands": ["Lucky Me"]}'::jsonb,
    0.85
);

-- OpenCV event
SELECT edge.ingest_edge_event(
    'PI5_STORE_001',
    'opencv',
    '{"detected_brands": ["Lucky Me"], "confidence": 0.92}'::jsonb,
    0.92
);
```

### Device Monitoring

```sql
-- Check device status
SELECT * FROM edge.get_device_status();

-- View real-time activity
SELECT * FROM edge.v_realtime_activity;

-- Edge analytics
SELECT * FROM edge.v_hourly_metrics WHERE hour > now() - interval '24 hours';
```

## 🌐 SKU Scraping Operations

### Quick Commands

```bash
# Start scraping
make worker

# Monitor status
make scraper-status

# Health check
make scraper-health

# Emergency stop
make emergency-stop
```

### Operational Controls

```sql
-- Throttle domain
SELECT scout.throttle_domain('slow-site.com', 60000); -- 1 req/min

-- Quarantine source
SELECT scout.quarantine_source('source-uuid', 'investigating issues');

-- Check blocked jobs
SELECT * FROM scout.v_blocked_jobs;
```

## 📈 Unified Analytics

### Cross-System Views

```sql
-- Combined transactions (Edge + Files)
SELECT * FROM scout.v_edge_integrated_transactions
WHERE transaction_time > now() - interval '24 hours';

-- Unified analytics dashboard
SELECT * FROM scout.v_unified_analytics;

-- System-wide health
SELECT * FROM scout.get_system_health();
```

### KPI Monitoring

```sql
-- Real-time metrics
SELECT 
    component,
    status,
    metrics->>'online' as devices_online,
    metrics->>'completed_24h' as files_processed,
    metrics->>'success_rate' as success_pct
FROM scout.get_system_health();
```

## 🚨 Alerts & Troubleshooting

### Common Issues

#### 1. Files Stuck in Queue
```sql
-- Check stuck files
SELECT * FROM scout.file_ingestion_queue 
WHERE status = 'processing' AND updated_at < now() - interval '1 hour';

-- Reset stuck files
UPDATE scout.file_ingestion_queue 
SET status = 'pending', attempts = 0 
WHERE status = 'processing' AND updated_at < now() - interval '1 hour';
```

#### 2. Edge Device Offline
```sql
-- Check offline devices
SELECT * FROM edge.devices WHERE status = 'offline';

-- View last events
SELECT * FROM edge.bronze_edge_events 
WHERE device_id = 'PI5_STORE_001' 
ORDER BY timestamp DESC LIMIT 10;
```

#### 3. Low Confidence Scores
```sql
-- Check confidence trends
SELECT 
    date_trunc('hour', transaction_time) as hour,
    avg(confidence_score) as avg_confidence,
    count(*) as transactions
FROM edge.fact_edge_transactions
WHERE transaction_time > now() - interval '24 hours'
GROUP BY 1 ORDER BY 1;
```

## 📊 Daily Operations Checklist

### Morning (9 AM)
- [ ] Check system health: `SELECT * FROM scout.get_system_health();`
- [ ] Review overnight ingestion: `SELECT * FROM scout.get_ingestion_dashboard();`
- [ ] Check edge devices: `SELECT * FROM edge.get_device_status();`
- [ ] Monitor scraping queue: `make scraper-status`

### Afternoon (2 PM)
- [ ] Process file queue: `SELECT scout.process_file_queue(20);`
- [ ] Check failed ingestions: `SELECT * FROM scout.v_ingestion_queue_status;`
- [ ] Review edge transactions: `SELECT * FROM edge.v_hourly_metrics;`

### End of Day (5 PM)
- [ ] Generate daily report
- [ ] Check for blocked scrapers: `make blocked-jobs`
- [ ] Review system alerts

## 🔧 Maintenance Tasks

### Weekly
```sql
-- Clean old processed files
DELETE FROM scout.file_ingestion_queue 
WHERE status = 'completed' AND processed_at < now() - interval '30 days';

-- Archive edge events
INSERT INTO edge.bronze_edge_events_archive
SELECT * FROM edge.bronze_edge_events 
WHERE created_at < now() - interval '7 days';
```

### Monthly
```sql
-- Analyze ingestion patterns
SELECT 
    source_type,
    file_type,
    count(*) as files,
    avg(processing_time_ms) as avg_ms
FROM scout.ingestion_history
WHERE processed_at > now() - interval '30 days'
GROUP BY 1, 2;

-- Review trigger effectiveness
SELECT * FROM scout.v_active_triggers
ORDER BY files_triggered DESC;
```

## 🎯 Performance Targets

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| File Processing | < 1000ms | > 5000ms |
| Edge Latency | < 100ms | > 500ms |
| Scraping Rate | > 10 pages/min | < 5 pages/min |
| Success Rate | > 95% | < 90% |
| Device Uptime | > 99% | < 95% |

## 🔐 Security Notes

1. **API Keys**: Store in environment variables, never in code
2. **File Validation**: Always validate file types and sizes
3. **Rate Limiting**: Enforce limits on API endpoints
4. **Access Control**: Use RLS policies for multi-tenant data
5. **Audit Trail**: Log all ingestion activities

## 📞 Support

For issues:
1. Check system health dashboard
2. Review error logs in ingestion_history
3. Consult this guide's troubleshooting section
4. Contact DevOps if critical

Remember: The system is designed to be self-healing. Most transient issues resolve automatically through retry mechanisms.