import { z } from 'zod';
import pRetry from 'p-retry';
import { trace } from 'opentelemetry-api';

/**
 * JSON Guard with Zod validation and prefill protection
 * Prevents prose contamination in structured outputs
 */
export function createJSONGuard<T>(schema: z.ZodSchema<T>) {
  return {
    validate: (input: unknown): T => {
      // Strip any prose prefix/suffix before JSON
      let cleaned = input;
      if (typeof input === 'string') {
        const jsonMatch = input.match(/\{[\s\S]*\}|\[[\s\S]*\]/);
        if (jsonMatch) {
          cleaned = jsonMatch[0];
        }
        try {
          cleaned = JSON.parse(cleaned as string);
        } catch {
          throw new Error('Invalid JSON in response');
        }
      }
      
      return schema.parse(cleaned);
    },
    
    prefill: (prompt: string): string => {
      return `${prompt}\n\nRespond with JSON only, no explanation:\n{`;
    },
    
    schema,
  };
}

/**
 * Retry wrapper with exponential backoff
 * Handles common MCP failures (timeouts, network issues, rate limits)
 */
export function withRetry<T extends any[], R>(
  fn: (...args: T) => Promise<R>,
  options: {
    retries?: number;
    factor?: number;
    minTimeout?: number;
    maxTimeout?: number;
    onFailedAttempt?: (error: any, attempt: number) => void;
  } = {}
) {
  const {
    retries = 3,
    factor = 2,
    minTimeout = 1000,
    maxTimeout = 5000,
    onFailedAttempt,
  } = options;

  return async (...args: T): Promise<R> => {
    return pRetry(
      async () => {
        try {
          return await fn(...args);
        } catch (error: any) {
          // Map common MCP errors to retryable conditions
          if (
            error.code === 'ETIMEDOUT' ||
            error.code === 'ECONNRESET' ||
            error.code === 'ENOTFOUND' ||
            error.message?.includes('timeout') ||
            error.message?.includes('rate limit') ||
            error.status === 429 ||
            error.status === 502 ||
            error.status === 503 ||
            error.status === 504
          ) {
            throw error; // Retryable
          }
          
          // Non-retryable errors
          if (error.code === '42P01' || error.message?.includes('does not exist')) {
            const notFoundError = new Error(`Resource not found: ${error.message}`);
            (notFoundError as any).code = 'NOT_FOUND';
            (notFoundError as any).retryable = false;
            throw notFoundError;
          }
          
          throw error;
        }
      },
      {
        retries,
        factor,
        minTimeout,
        maxTimeout,
        onFailedAttempt: (error, attemptNumber) => {
          if (onFailedAttempt) {
            onFailedAttempt(error, attemptNumber);
          }
          console.warn(`[Retry ${attemptNumber}/${retries + 1}]`, error.message);
        },
      }
    );
  };
}

/**
 * Cost and performance tracking
 * Integrates with OpenTelemetry for enterprise observability
 */
export function trackCost(operation: string) {
  const span = trace.getActiveSpan();
  const startTime = Date.now();
  
  return {
    start: () => {
      span?.setAttributes({
        'ai.operation': operation,
        'ai.start_time': startTime,
      });
      return startTime;
    },
    
    end: (result: {
      model?: string;
      input_tokens?: number;
      output_tokens?: number;
      cost_usd?: number;
      success: boolean;
      error?: string;
    }) => {
      const endTime = Date.now();
      const duration = endTime - startTime;
      
      span?.setAttributes({
        'ai.model': result.model || 'unknown',
        'ai.input_tokens': result.input_tokens || 0,
        'ai.output_tokens': result.output_tokens || 0,
        'ai.cost_usd': result.cost_usd || 0,
        'ai.duration_ms': duration,
        'ai.success': result.success,
        'ai.error': result.error || '',
      });
      
      // Emit cost event for Grafana/monitoring
      console.log(`[ai-cost] ${JSON.stringify({
        operation,
        model: result.model,
        input_tokens: result.input_tokens,
        output_tokens: result.output_tokens,
        duration_ms: duration,
        cost_usd: result.cost_usd,
        success: result.success,
        timestamp: new Date().toISOString(),
      })}`);
      
      return duration;
    },
  };
}