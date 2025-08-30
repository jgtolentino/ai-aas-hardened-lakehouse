/**
 * OpenTelemetry Observability Configuration
 * Enables cost tracking and performance monitoring for AI operations
 */

const { NodeSDK } = require('@opentelemetry/sdk-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-otlp-http');
const { OTLPMetricsExporter } = require('@opentelemetry/exporter-otlp-http');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');

// Initialize OpenTelemetry SDK
const sdk = new NodeSDK({
  resource: Resource.default().merge(
    new Resource({
      [SemanticResourceAttributes.SERVICE_NAME]: 'scout-ai-cookbook',
      [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
      [SemanticResourceAttributes.DEPLOYMENT_ENVIRONMENT]: process.env.NODE_ENV || 'development',
    })
  ),
  
  // Configure trace export (Grafana/Jaeger endpoint)
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT || 'http://localhost:4318/v1/traces',
  }),
  
  // Configure metrics export
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricsExporter({
      url: process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT || 'http://localhost:4318/v1/metrics',
    }),
    exportIntervalMillis: 5000, // Export every 5 seconds
  }),
});

// Start the SDK
sdk.start();

// Setup Grafana Agent integration
if (process.env.GRAFANA_AGENT_URL) {
  const grafanaAgent = {
    recordMetric: (metricName, value, labels = {}) => {
      // Send metrics to Grafana Agent
      fetch(`${process.env.GRAFANA_AGENT_URL}/api/v1/write`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          metric: metricName,
          value: value,
          timestamp: Date.now(),
          labels: labels,
        }),
      }).catch(err => {
        console.warn('Failed to send metric to Grafana:', err.message);
      });
    }
  };
  
  global.grafanaAgent = grafanaAgent;
  console.log('🔍 Grafana Agent integration enabled');
}

// Graceful shutdown
process.on('SIGTERM', () => {
  sdk.shutdown()
    .then(() => console.log('📊 OpenTelemetry terminated'))
    .catch((error) => console.log('Error terminating OpenTelemetry', error))
    .finally(() => process.exit(0));
});

module.exports = { sdk };