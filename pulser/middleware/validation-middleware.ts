import type { RoutingRequest } from '../routing/router';
import { pulserConfig } from '../config/pulser.config';

export interface ValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
}

export class ValidationMiddleware {
  private sensitivePatterns = [
    /api[_-]?key/i,
    /password/i,
    /secret/i,
    /token/i,
    /credential/i,
    /private[_-]?key/i
  ];

  validateRequest(request: RoutingRequest): ValidationResult {
    const errors: string[] = [];
    const warnings: string[] = [];

    // Validate request structure
    if (!request.type) {
      errors.push('Request type is required');
    }

    if (!request.payload) {
      warnings.push('Request payload is empty');
    }

    // Check payload size
    const payloadSize = JSON.stringify(request.payload || {}).length;
    if (payloadSize > 10 * 1024 * 1024) { // 10MB
      errors.push(`Payload size (${payloadSize} bytes) exceeds limit`);
    }

    // Check for sensitive data
    const sensitiveData = this.detectSensitiveData(request.payload);
    if (sensitiveData.length > 0) {
      if (pulserConfig.security.enforcePermissions) {
        errors.push(`Sensitive data detected: ${sensitiveData.join(', ')}`);
      } else {
        warnings.push(`Potential sensitive data: ${sensitiveData.join(', ')}`);
      }
    }

    // Validate context
    if (request.context) {
      if (request.context.timeout && request.context.timeout < 0) {
        errors.push('Invalid timeout value');
      }

      if (request.context.priority && !['low', 'medium', 'high', 'critical'].includes(request.context.priority)) {
        errors.push('Invalid priority value');
      }
    }

    return {
      valid: errors.length === 0,
      errors,
      warnings
    };
  }

  private detectSensitiveData(payload: any): string[] {
    const findings: string[] = [];
    const payloadStr = JSON.stringify(payload);

    for (const pattern of this.sensitivePatterns) {
      if (pattern.test(payloadStr)) {
        findings.push(pattern.source);
      }
    }

    return findings;
  }

  validatePermissions(requiredPermissions: string[], grantedPermissions: string[]): boolean {
    if (!pulserConfig.security.enforcePermissions) {
      return true;
    }

    return requiredPermissions.every(perm => grantedPermissions.includes(perm));
  }

  sanitizePayload(payload: any): any {
    if (!payload || typeof payload !== 'object') {
      return payload;
    }

    const sanitized = { ...payload };

    // Remove sensitive fields
    const sensitiveFields = ['password', 'token', 'secret', 'apiKey', 'api_key'];
    for (const field of sensitiveFields) {
      if (field in sanitized) {
        sanitized[field] = '[REDACTED]';
      }
    }

    // Recursively sanitize nested objects
    for (const key in sanitized) {
      if (typeof sanitized[key] === 'object' && sanitized[key] !== null) {
        sanitized[key] = this.sanitizePayload(sanitized[key]);
      }
    }

    return sanitized;
  }
}

export const validationMiddleware = new ValidationMiddleware();