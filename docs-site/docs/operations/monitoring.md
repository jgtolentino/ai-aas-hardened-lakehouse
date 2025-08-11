# System Monitoring & Observability

Comprehensive monitoring setup for the AI-AAS Hardened Lakehouse platform ensuring high availability, performance optimization, and proactive issue detection.

## Monitoring Stack Overview

### Core Components
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards  
- **AlertManager**: Alert routing and management
- **Jaeger**: Distributed tracing
- **ELK Stack**: Log aggregation and analysis

## Infrastructure Monitoring

### System Metrics
```yaml
# prometheus.yml configuration
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'postgres'
    static_configs:
      - targets: ['localhost:5432']
    metrics_path: /metrics
    scrape_interval: 5s

  - job_name: 'supabase-edge'
    static_configs:
      - targets: ['localhost:54324']
    scrape_interval: 10s

  - job_name: 'minio'
    static_configs:
      - targets: ['localhost:9000']
    metrics_path: /minio/v2/metrics/cluster
```

### Key Performance Indicators (KPIs)
```promql
# Query Performance
avg(rate(postgres_query_duration_seconds[5m])) by (query_type)

# Storage Usage
minio_cluster_usage_total_bytes / minio_cluster_capacity_total_bytes * 100

# API Response Time
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Error Rate
rate(http_requests_total{status_code=~"5.."}[5m]) / rate(http_requests_total[5m])
```

## Application Monitoring

### Database Performance
```sql
-- Create monitoring views
CREATE OR REPLACE VIEW monitoring.query_performance AS
SELECT 
  query,
  calls,
  total_time,
  mean_time,
  min_time,
  max_time,
  stddev_time,
  (total_time / calls) as avg_time_per_call
FROM pg_stat_statements 
WHERE calls > 100
ORDER BY total_time DESC;

-- Connection monitoring
CREATE OR REPLACE VIEW monitoring.connection_stats AS
SELECT 
  datname,
  state,
  COUNT(*) as connection_count,
  MAX(now() - state_change) as max_state_duration
FROM pg_stat_activity 
WHERE state IS NOT NULL
GROUP BY datname, state;
```

### Edge Function Monitoring
```typescript
// Edge function monitoring middleware
export async function monitoringMiddleware(req: Request): Promise<Response> {
  const startTime = performance.now();
  const functionName = req.headers.get('x-function-name') || 'unknown';
  
  try {
    // Process request
    const response = await processRequest(req);
    
    // Record metrics
    await recordMetric({
      function_name: functionName,
      duration_ms: performance.now() - startTime,
      status_code: response.status,
      timestamp: new Date().toISOString()
    });
    
    return response;
  } catch (error) {
    // Record error metrics
    await recordError({
      function_name: functionName,
      error_type: error.name,
      error_message: error.message,
      duration_ms: performance.now() - startTime,
      timestamp: new Date().toISOString()
    });
    
    throw error;
  }
}
```

## Alerting Configuration

### Critical Alerts
```yaml
# alerting-rules.yml
groups:
  - name: database
    rules:
      - alert: DatabaseDown
        expr: up{job="postgres"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database is down"
          description: "PostgreSQL database has been down for more than 1 minute"

      - alert: HighQueryTime  
        expr: avg(rate(postgres_query_duration_seconds[5m])) > 2.0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High database query time"
          description: "Average query time is {{ $value }}s"

  - name: storage
    rules:
      - alert: StorageSpaceHigh
        expr: (minio_cluster_usage_total_bytes / minio_cluster_capacity_total_bytes) > 0.85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Storage usage high"
          description: "Storage usage is at {{ $value }}%"

  - name: api
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status_code=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High API error rate"
          description: "Error rate is {{ $value }}%"
```

### Alert Notification Channels
```yaml
# alertmanager.yml
route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
    - match:
        severity: warning  
      receiver: 'warning-alerts'

receivers:
  - name: 'critical-alerts'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts-critical'
        title: 'Critical Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
    
  - name: 'warning-alerts'
    email_configs:
      - to: 'team@company.com'
        subject: 'Warning: {{ .GroupLabels.alertname }}'
        body: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

## Dashboard Configuration

### Executive Dashboard
```json
{
  "dashboard": {
    "title": "AI-AAS Lakehouse - Executive Overview",
    "panels": [
      {
        "title": "System Health Score",
        "type": "stat",
        "targets": [
          {
            "expr": "avg(up{job=~\"postgres|minio|supabase.*\"}) * 100",
            "legendFormat": "Health %"
          }
        ]
      },
      {
        "title": "Data Pipeline Status",
        "type": "table",
        "targets": [
          {
            "expr": "last_over_time(pipeline_status[1h])",
            "legendFormat": "{{pipeline_name}}"
          }
        ]
      },
      {
        "title": "Query Performance (P95)",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(postgres_query_duration_seconds_bucket[5m]))",
            "legendFormat": "P95 Response Time"
          }
        ]
      }
    ]
  }
}
```

### Technical Dashboard
```json
{
  "dashboard": {
    "title": "AI-AAS Lakehouse - Technical Metrics",
    "panels": [
      {
        "title": "Database Connections",
        "type": "graph",
        "targets": [
          {
            "expr": "pg_stat_database_numbackends",
            "legendFormat": "{{datname}}"
          }
        ]
      },
      {
        "title": "Storage I/O",
        "type": "graph", 
        "targets": [
          {
            "expr": "rate(minio_s3_requests_total[5m])",
            "legendFormat": "{{api}} requests/sec"
          }
        ]
      },
      {
        "title": "Cache Hit Ratio",
        "type": "stat",
        "targets": [
          {
            "expr": "pg_stat_database_blks_hit / (pg_stat_database_blks_hit + pg_stat_database_blks_read) * 100",
            "legendFormat": "Cache Hit %"
          }
        ]
      }
    ]
  }
}
```

## Log Management

### Centralized Logging
```yaml
# docker-compose.logging.yml
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    ports:
      - "5000:5000"
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch
```

### Log Parsing Configuration
```ruby
# logstash.conf
input {
  beats {
    port => 5044
  }
  tcp {
    port => 5000
    codec => json
  }
}

filter {
  if [service] == "postgres" {
    grok {
      match => { 
        "message" => "%{TIMESTAMP_ISO8601:timestamp} \[%{DATA:pid}\] %{WORD:level}: %{GREEDYDATA:query}"
      }
    }
  }
  
  if [service] == "supabase-edge" {
    json {
      source => "message"
    }
    date {
      match => [ "timestamp", "ISO8601" ]
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "lakehouse-logs-%{+YYYY.MM.dd}"
  }
}
```

## Health Checks

### Automated Health Monitoring
```typescript
// health-check.ts
interface HealthCheck {
  service: string;
  status: 'healthy' | 'unhealthy' | 'degraded';
  responseTime: number;
  lastCheck: Date;
  details?: any;
}

export class HealthMonitor {
  private checks: Map<string, HealthCheck> = new Map();
  
  async performHealthChecks(): Promise<HealthCheck[]> {
    const services = [
      { name: 'postgres', check: this.checkDatabase },
      { name: 'minio', check: this.checkStorage },
      { name: 'supabase-api', check: this.checkAPI },
      { name: 'edge-functions', check: this.checkEdgeFunctions }
    ];
    
    const results = await Promise.allSettled(
      services.map(async service => {
        const startTime = Date.now();
        try {
          await service.check();
          return {
            service: service.name,
            status: 'healthy' as const,
            responseTime: Date.now() - startTime,
            lastCheck: new Date()
          };
        } catch (error) {
          return {
            service: service.name,
            status: 'unhealthy' as const,
            responseTime: Date.now() - startTime,
            lastCheck: new Date(),
            details: error.message
          };
        }
      })
    );
    
    return results
      .filter(result => result.status === 'fulfilled')
      .map(result => result.value);
  }
  
  private async checkDatabase() {
    // PostgreSQL health check
    const result = await sql`SELECT 1 as health`;
    if (!result.rows.length) throw new Error('Database query failed');
  }
  
  private async checkStorage() {
    // MinIO health check
    const response = await fetch('http://localhost:9000/minio/health/live');
    if (!response.ok) throw new Error('Storage health check failed');
  }
  
  private async checkAPI() {
    // Supabase API health check
    const response = await fetch('http://localhost:54321/rest/v1/');
    if (!response.ok) throw new Error('API health check failed');
  }
  
  private async checkEdgeFunctions() {
    // Edge Functions health check
    const response = await fetch('http://localhost:54324/functions/v1/health');
    if (!response.ok) throw new Error('Edge Functions health check failed');
  }
}
```

## Performance Optimization

### Query Performance Monitoring
```sql
-- Slow query monitoring
CREATE OR REPLACE FUNCTION monitor_slow_queries()
RETURNS void AS $$
DECLARE
  slow_query RECORD;
BEGIN
  FOR slow_query IN 
    SELECT query, calls, mean_time, total_time
    FROM pg_stat_statements 
    WHERE mean_time > 1000  -- queries taking more than 1 second
    AND calls > 10
    ORDER BY mean_time DESC
    LIMIT 10
  LOOP
    INSERT INTO monitoring.slow_queries (
      query_hash,
      query_text,
      avg_duration_ms,
      call_count,
      detected_at
    ) VALUES (
      md5(slow_query.query),
      slow_query.query,
      slow_query.mean_time,
      slow_query.calls,
      NOW()
    ) ON CONFLICT (query_hash) DO UPDATE SET
      avg_duration_ms = EXCLUDED.avg_duration_ms,
      call_count = EXCLUDED.call_count,
      last_seen = NOW();
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Schedule monitoring
SELECT cron.schedule(
  'monitor-slow-queries',
  '*/5 * * * *',  -- Every 5 minutes
  'SELECT monitor_slow_queries();'
);
```

This comprehensive monitoring setup provides full observability into the AI-AAS Hardened Lakehouse platform, enabling proactive maintenance and optimization.