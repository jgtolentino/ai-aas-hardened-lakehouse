# MLOps Implementation Guide - Scout Dashboard

## Overview

This document describes the complete MLOps (Machine Learning Operations) implementation for the Scout Dashboard AI systems. The implementation provides comprehensive monitoring, cost tracking, drift detection, A/B testing, and deployment management for all AI-powered edge functions.

## Architecture Components

### 1. Database Infrastructure (`supabase/migrations/20250128000000_mlops_infrastructure.sql`)

**Core MLOps Schema:**
- `mlops.model_performance` - Real-time performance metrics tracking
- `mlops.experiments` - A/B testing and experimentation framework
- `mlops.feature_store` - Centralized feature management
- `mlops.drift_detection` - Statistical drift monitoring
- `mlops.cost_tracking` - AI model cost analysis
- `mlops.alerts` - Alert management system
- `mlops.model_cards` - Automated model documentation
- `mlops.deployments` - Deployment history and management

**Key Features:**
- Row Level Security (RLS) policies for multi-tenant access
- Automated trigger functions for metric aggregation
- Comprehensive indexing for performance optimization
- Support for both traditional ML and edge function deployments

### 2. Enhanced Edge Functions (`supabase/functions/ai-generate-insight/mlops-enhanced.ts`)

**MLOps Integration:**
- Automatic performance metric logging
- A/B testing framework with traffic splitting
- Cost tracking for OpenAI API calls
- Error monitoring and alerting
- Response quality assessment

**A/B Testing Features:**
- Control vs Treatment variant testing
- Configurable traffic splitting (default 50/50)
- Statistical significance tracking
- Performance comparison metrics

### 3. Cost Monitoring System (`scripts/mlops-cost-monitor.py`)

**Capabilities:**
- Real-time cost tracking for all AI models
- Daily/weekly/monthly cost aggregation
- Anomaly detection for unusual spending patterns
- Budget threshold alerts
- Cost optimization recommendations
- Email alerting for cost overruns

**Alert Thresholds:**
- Daily cost > $1.00
- Weekly cost > $5.00  
- Monthly cost > $20.00
- Hourly spike > 500% of baseline

### 4. Data Drift Detection (`scripts/mlops-drift-detector.py`)

**Statistical Tests:**
- **Kolmogorov-Smirnov Test** - Distribution changes
- **Mann-Whitney U Test** - Non-parametric distribution comparison
- **Anderson-Darling Test** - Distribution similarity
- **Chi-Square Test** - Categorical variable changes

**Monitored Metrics:**
- Query length distribution
- Response latency patterns
- Confidence score distributions
- Error rate patterns
- Request volume anomalies

### 5. Model Card Generation (`scripts/model-card-generator.py`)

**Automated Documentation:**
- Performance metrics aggregation
- Training data specifications
- Evaluation results
- Ethical considerations
- Technical specifications
- Deployment history

**Update Frequency:**
- Real-time performance metrics
- Weekly model card regeneration
- Monthly comprehensive reviews
- Alert-triggered updates for drift events

### 6. Blue-Green Deployment (`.github/workflows/edge-function-blue-green.yml`)

**Deployment Strategy:**
- Zero-downtime deployments
- Automated rollback on failure
- Health checks at each stage
- Performance validation
- Gradual traffic shifting

**Deployment Process:**
1. **Blue Environment** - Deploy new version to staging
2. **Testing Phase** - Comprehensive testing of blue environment
3. **Green Switch** - Promote blue to production (green)
4. **Validation** - Verify production deployment
5. **Cleanup** - Remove old blue environment

### 7. MLOps Monitoring Dashboard (`apps/dashboard/src/components/MLOpsMonitoringDashboard.tsx`)

**Real-time Monitoring:**
- Performance metrics visualization
- Cost tracking and trends
- Drift alert management
- A/B test results
- Deployment history

**Key Features:**
- Auto-refresh every 30 seconds
- Interactive charts and graphs
- Alert notifications
- Function-level drill-down
- Export capabilities for reports

## Getting Started

### 1. Database Setup

Apply the MLOps infrastructure migration:

```sql
-- Run in Supabase SQL Editor
-- File: supabase/migrations/20250128000000_mlops_infrastructure.sql
-- This creates all necessary tables, functions, and policies
```

### 2. Environment Configuration

Set required environment variables:

```bash
# Database connection
export DATABASE_URL="postgresql://postgres:password@host:port/database"
export SUPABASE_PROJECT_REF="your-project-ref"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"

# Email alerts (optional)
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_USER="your-email@gmail.com"
export SMTP_PASSWORD="your-app-password"
export ALERT_EMAIL="admin@yourcompany.com"

# Cost thresholds (optional)
export DAILY_COST_THRESHOLD="1.00"
export WEEKLY_COST_THRESHOLD="5.00"
export MONTHLY_COST_THRESHOLD="20.00"
```

### 3. Start MLOps Monitoring

Use the comprehensive monitoring script:

```bash
# Start all MLOps services
./scripts/run-mlops-monitoring.sh start

# Check status
./scripts/run-mlops-monitoring.sh status

# Stop services
./scripts/run-mlops-monitoring.sh stop

# Generate model cards only
./scripts/run-mlops-monitoring.sh cards

# Run health checks
./scripts/run-mlops-monitoring.sh health
```

### 4. Deploy Enhanced Edge Functions

The A/B testing enabled edge functions are automatically deployed via GitHub Actions when changes are pushed to `supabase/functions/` directories.

### 5. Access MLOps Dashboard

Navigate to `/mlops` in your Scout Dashboard application to access the real-time monitoring interface.

## Usage Examples

### Cost Monitoring

```python
# Monitor costs programmatically
from scripts.mlops_cost_monitor import MLOpsCostMonitor

monitor = MLOpsCostMonitor()
daily_costs = await monitor.analyze_costs()

for function, metrics in daily_costs.items():
    print(f"{function}: ${metrics.total_cost:.4f} ({metrics.request_count} requests)")
```

### Drift Detection

```python
# Check for data drift
from scripts.mlops_drift_detector import DataDriftDetector

detector = DataDriftDetector()
drift_results = await detector.detect_all_drift()

for result in drift_results:
    if result.drift_detected:
        print(f"DRIFT ALERT: {result.function_name} - {result.metric_name}")
        print(f"P-value: {result.p_value}, Threshold: {result.threshold}")
```

### A/B Testing

```typescript
// Edge function automatically handles A/B testing
const response = await fetch('/functions/v1/ai-generate-insight', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${supabaseKey}`
  },
  body: JSON.stringify({
    query: "Analyze quarterly performance",
    context: { department: "sales" }
  })
});

// Variant is automatically assigned and tracked
```

## Monitoring and Alerts

### Performance Metrics

- **Latency**: Response time tracking with percentiles
- **Throughput**: Requests per second/minute/hour
- **Error Rate**: Failed requests percentage
- **Confidence**: Model prediction confidence scores
- **Cost**: Real-time cost per request and total costs

### Alert Types

1. **Performance Alerts**
   - High latency (>5 seconds)
   - Low confidence scores (<70%)
   - High error rates (>5%)

2. **Cost Alerts**
   - Daily budget exceeded
   - Unusual cost spikes
   - Cost per request anomalies

3. **Drift Alerts**
   - Statistical distribution changes
   - Data quality issues
   - Concept drift detection

4. **Deployment Alerts**
   - Failed deployments
   - Health check failures
   - Rollback notifications

## Best Practices

### 1. Model Performance

- Monitor key metrics continuously
- Set up alerts for performance degradation
- Regular model retraining based on drift detection
- A/B test new model versions before full deployment

### 2. Cost Management

- Set realistic budget thresholds
- Monitor cost per request trends
- Optimize model selection based on cost-performance trade-offs
- Regular cost reviews and optimization

### 3. Deployment Safety

- Use blue-green deployments for zero downtime
- Comprehensive testing before production deployment
- Automated rollback on failure detection
- Performance validation at each stage

### 4. Data Quality

- Continuous drift monitoring
- Regular data quality assessments
- Alert on significant distribution changes
- Maintain feature store hygiene

## Troubleshooting

### Common Issues

1. **Database Connection Errors**
   ```bash
   # Check environment variables
   echo $DATABASE_URL
   echo $SUPABASE_PROJECT_REF
   
   # Test connection
   ./scripts/run-mlops-monitoring.sh health
   ```

2. **High Memory Usage**
   ```bash
   # Check process memory
   ps aux | grep python | grep mlops
   
   # Restart services if needed
   ./scripts/run-mlops-monitoring.sh restart
   ```

3. **Missing Drift Data**
   ```sql
   -- Check if data exists
   SELECT COUNT(*) FROM mlops.model_performance 
   WHERE created_at >= NOW() - INTERVAL '24 hours';
   ```

4. **Cost Tracking Issues**
   ```python
   # Verify OpenAI API key configuration
   # Check edge function logs in Supabase dashboard
   ```

### Log Files

All MLOps components write to structured log files:

```bash
# Main monitoring log
tail -f logs/mlops/mlops-monitoring.log

# Cost monitor logs
tail -f logs/mlops/cost-monitor.log

# Drift detector logs
tail -f logs/mlops/drift-detector.log
```

## Extending the System

### Adding New Models

1. Update the model specifications in `model-card-generator.py`
2. Add cost tracking to your edge function
3. Configure drift detection for new metrics
4. Update dashboard to display new model data

### Custom Metrics

1. Add new columns to `mlops.model_performance` table
2. Update edge functions to log custom metrics
3. Extend dashboard visualization
4. Add custom alert rules

### Integration with External Tools

The MLOps system provides REST APIs and database views for integration with:

- Grafana dashboards
- DataDog monitoring
- PagerDuty alerting
- Slack notifications
- Custom reporting tools

## Performance Considerations

- Database queries are optimized with proper indexing
- Real-time metrics use efficient aggregation functions
- Monitoring scripts use connection pooling
- Dashboard implements pagination for large datasets
- Cost calculations use approximate algorithms for speed

## Security

- All database access uses RLS policies
- API keys are managed through environment variables
- Logs exclude sensitive data
- Access controls limit MLOps data to authorized users
- Audit trail for all configuration changes

---

This MLOps implementation provides enterprise-grade monitoring, cost management, and deployment capabilities for the Scout Dashboard AI systems. Regular maintenance and monitoring ensure optimal performance and cost efficiency.

For support or questions, refer to the troubleshooting section or contact the development team.