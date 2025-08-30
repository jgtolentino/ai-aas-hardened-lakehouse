import { trace, context, SpanStatusCode, SpanKind } from 'opentelemetry-api';

/**
 * OpenTelemetry integration for AI operations observability
 * Tracks performance, costs, and errors across MCP tools
 */

const tracer = trace.getTracer('@scout/ai-cookbook', '1.0.0');

export interface AIOperationMetrics {
  operation: string;
  model?: string;
  input_tokens?: number;
  output_tokens?: number;
  duration_ms: number;
  cost_usd?: number;
  success: boolean;
  error?: string;
  tool_calls?: number;
  retry_attempts?: number;
}

export class AIObservability {
  private static instance: AIObservability;
  private operations: Map<string, AIOperationMetrics> = new Map();

  public static getInstance(): AIObservability {
    if (!AIObservability.instance) {
      AIObservability.instance = new AIObservability();
    }
    return AIObservability.instance;
  }

  /**
   * Start tracking an AI operation
   */
  startOperation(operationId: string, operation: string, model?: string) {
    const span = tracer.startSpan(operation, {
      kind: SpanKind.CLIENT,
      attributes: {
        'ai.operation.id': operationId,
        'ai.operation.name': operation,
        'ai.model.name': model || 'unknown',
      },
    });

    const startTime = Date.now();
    this.operations.set(operationId, {
      operation,
      model,
      duration_ms: 0,
      success: false,
    });

    return {
      operationId,
      span,
      startTime,
    };
  }

  /**
   * End tracking an AI operation
   */
  endOperation(operationId: string, metrics: Partial<AIOperationMetrics>) {
    const operation = this.operations.get(operationId);
    if (!operation) {
      console.warn(`[AI Observability] Operation ${operationId} not found`);
      return;
    }

    const finalMetrics: AIOperationMetrics = {
      ...operation,
      ...metrics,
      duration_ms: metrics.duration_ms || Date.now(),
    };

    // Update OpenTelemetry span
    const span = trace.getActiveSpan();
    if (span) {
      span.setAttributes({
        'ai.model.name': finalMetrics.model || 'unknown',
        'ai.usage.input_tokens': finalMetrics.input_tokens || 0,
        'ai.usage.output_tokens': finalMetrics.output_tokens || 0,
        'ai.usage.total_tokens': (finalMetrics.input_tokens || 0) + (finalMetrics.output_tokens || 0),
        'ai.cost.usd': finalMetrics.cost_usd || 0,
        'ai.performance.duration_ms': finalMetrics.duration_ms,
        'ai.tools.calls': finalMetrics.tool_calls || 0,
        'ai.retry.attempts': finalMetrics.retry_attempts || 0,
      });

      if (finalMetrics.success) {
        span.setStatus({ code: SpanStatusCode.OK });
      } else {
        span.setStatus({ 
          code: SpanStatusCode.ERROR, 
          message: finalMetrics.error || 'Operation failed' 
        });
      }

      span.end();
    }

    // Emit metrics for external monitoring
    this.emitMetrics(finalMetrics);

    // Clean up
    this.operations.delete(operationId);
  }

  /**
   * Emit metrics to external monitoring systems
   */
  private emitMetrics(metrics: AIOperationMetrics) {
    // Console logging for development
    console.log(`[ai-metrics] ${JSON.stringify({
      ...metrics,
      timestamp: new Date().toISOString(),
    })}`);

    // Grafana/Prometheus metrics (if available)
    if (global.grafanaAgent) {
      global.grafanaAgent.recordMetric('ai_operation_duration', metrics.duration_ms, {
        operation: metrics.operation,
        model: metrics.model || 'unknown',
        success: metrics.success.toString(),
      });

      if (metrics.cost_usd) {
        global.grafanaAgent.recordMetric('ai_operation_cost', metrics.cost_usd, {
          operation: metrics.operation,
          model: metrics.model || 'unknown',
        });
      }

      if (metrics.input_tokens) {
        global.grafanaAgent.recordMetric('ai_tokens_input', metrics.input_tokens, {
          operation: metrics.operation,
          model: metrics.model || 'unknown',
        });
      }

      if (metrics.output_tokens) {
        global.grafanaAgent.recordMetric('ai_tokens_output', metrics.output_tokens, {
          operation: metrics.operation,
          model: metrics.model || 'unknown',
        });
      }
    }
  }

  /**
   * Get aggregated metrics for reporting
   */
  getAggregatedMetrics(timeWindow: number = 3600000): {
    total_operations: number;
    success_rate: number;
    avg_duration_ms: number;
    total_cost_usd: number;
    total_tokens: number;
    operations_by_type: Record<string, number>;
    models_used: Record<string, number>;
  } {
    // This would typically query from a metrics store
    // For now, return empty aggregation
    return {
      total_operations: 0,
      success_rate: 0,
      avg_duration_ms: 0,
      total_cost_usd: 0,
      total_tokens: 0,
      operations_by_type: {},
      models_used: {},
    };
  }

  /**
   * Create instrumented function wrapper
   */
  instrument<T extends (...args: any[]) => Promise<any>>(
    operation: string,
    model: string | undefined,
    fn: T
  ): T {
    return (async (...args: any[]) => {
      const operationId = `${operation}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      const tracking = this.startOperation(operationId, operation, model);

      try {
        const result = await fn(...args);
        
        this.endOperation(operationId, {
          success: true,
          duration_ms: Date.now() - tracking.startTime,
        });
        
        return result;
      } catch (error: any) {
        this.endOperation(operationId, {
          success: false,
          duration_ms: Date.now() - tracking.startTime,
          error: error.message,
        });
        
        throw error;
      }
    }) as T;
  }
}

// Export singleton instance
export const aiObservability = AIObservability.getInstance();

// Convenience function for wrapping operations
export function withObservability<T extends (...args: any[]) => Promise<any>>(
  operation: string,
  model: string | undefined,
  fn: T
): T {
  return aiObservability.instrument(operation, model, fn);
}

// Cost calculation helpers
export const costCalculator = {
  // Claude pricing (as of 2024)
  claude: {
    'claude-3-5-sonnet-20241022': {
      input: 3.00 / 1_000_000,  // $3 per 1M tokens
      output: 15.00 / 1_000_000, // $15 per 1M tokens
    },
    'claude-3-haiku-20240307': {
      input: 0.25 / 1_000_000,  // $0.25 per 1M tokens
      output: 1.25 / 1_000_000, // $1.25 per 1M tokens
    },
  },

  calculate(model: string, inputTokens: number, outputTokens: number): number {
    const pricing = this.claude[model as keyof typeof this.claude];
    if (!pricing) return 0;

    return (inputTokens * pricing.input) + (outputTokens * pricing.output);
  },
};