import { mcpGuard } from '../guards/mcp-security-guard';

export interface MCPRequest {
  server: string;
  method: string;
  params?: any;
  metadata?: {
    timestamp: string;
    requestId: string;
    source?: string;
  };
}

export interface MCPResponse {
  success: boolean;
  data?: any;
  error?: string;
  metadata?: {
    timestamp: string;
    requestId: string;
    duration: number;
  };
}

export class MCPInterceptor {
  private requestLog: Map<string, MCPRequest> = new Map();

  async intercept(request: MCPRequest): Promise<MCPResponse> {
    const startTime = Date.now();
    const requestId = request.metadata?.requestId || this.generateRequestId();
    
    // Store request for auditing
    this.requestLog.set(requestId, request);

    try {
      // Validate server access
      if (!mcpGuard.validateServerAccess(request.server)) {
        throw new Error(`Access denied to server: ${request.server}`);
      }

      // Validate action
      if (!mcpGuard.validateAction(request.server, request.method)) {
        throw new Error(`Action not allowed: ${request.method}`);
      }

      // Check payload size
      if (request.params && !mcpGuard.validatePayloadSize(request.params)) {
        throw new Error('Payload size exceeds limit');
      }

      // Detect sensitive data
      const sensitiveFindings = mcpGuard.detectSensitiveData(request.params || {});
      if (sensitiveFindings.length > 0) {
        console.warn('[MCP Interceptor] Sensitive data detected:', sensitiveFindings);
        // In strict mode, we would throw here
        // throw new Error('Sensitive data detected in request');
      }

      // Special handling for database queries
      if (request.method === 'query' || request.method === 'execute_sql') {
        const query = request.params?.query || request.params?.sql;
        if (query && !mcpGuard.validateQuery(query)) {
          throw new Error('Dangerous query pattern detected');
        }
      }

      // Schema access validation
      if (request.params?.schema) {
        if (!mcpGuard.validateSchemaAccess(request.server, request.params.schema)) {
          throw new Error(`Access denied to schema: ${request.params.schema}`);
        }
      }

      // If all validations pass, return success
      // In real implementation, this would forward to actual MCP server
      return {
        success: true,
        data: { message: 'Request validated and would be forwarded' },
        metadata: {
          timestamp: new Date().toISOString(),
          requestId,
          duration: Date.now() - startTime
        }
      };

    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
        metadata: {
          timestamp: new Date().toISOString(),
          requestId,
          duration: Date.now() - startTime
        }
      };
    }
  }

  private generateRequestId(): string {
    return `mcp-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  getRequestLog(): MCPRequest[] {
    return Array.from(this.requestLog.values());
  }

  clearRequestLog(): void {
    this.requestLog.clear();
  }
}

// Export singleton instance
export const mcpInterceptor = new MCPInterceptor();