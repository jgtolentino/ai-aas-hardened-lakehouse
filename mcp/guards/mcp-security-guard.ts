import { readFileSync } from 'fs';
import { join } from 'path';

interface MCPPermission {
  server: string;
  action: string;
  resource: string;
  allowed: boolean;
}

interface SecurityPolicy {
  allowedServers: string[];
  deniedActions: string[];
  sensitiveSchemas: string[];
  maxPayloadSize: number;
}

export class MCPSecurityGuard {
  private policy: SecurityPolicy;
  private auditLog: MCPPermission[] = [];

  constructor(policyPath?: string) {
    const defaultPolicy: SecurityPolicy = {
      allowedServers: ['filesystem', 'context7', 'supabase_primary', 'scout_analytics'],
      deniedActions: ['execute', 'write', 'delete', 'drop', 'truncate'],
      sensitiveSchemas: ['auth', 'private', 'secrets', 'vault'],
      maxPayloadSize: 10 * 1024 * 1024 // 10MB
    };

    if (policyPath) {
      try {
        const customPolicy = JSON.parse(readFileSync(policyPath, 'utf-8'));
        this.policy = { ...defaultPolicy, ...customPolicy };
      } catch (error) {
        console.warn('[MCP Guard] Failed to load custom policy, using defaults');
        this.policy = defaultPolicy;
      }
    } else {
      this.policy = defaultPolicy;
    }
  }

  validateServerAccess(server: string): boolean {
    const allowed = this.policy.allowedServers.includes(server);
    this.audit(server, 'access', 'server', allowed);
    return allowed;
  }

  validateAction(server: string, action: string): boolean {
    const denied = this.policy.deniedActions.includes(action.toLowerCase());
    const allowed = !denied;
    this.audit(server, action, 'action', allowed);
    return allowed;
  }

  validateSchemaAccess(server: string, schema: string): boolean {
    const sensitive = this.policy.sensitiveSchemas.includes(schema.toLowerCase());
    const allowed = !sensitive;
    this.audit(server, 'access', `schema:${schema}`, allowed);
    return allowed;
  }

  validatePayloadSize(payload: any): boolean {
    const size = JSON.stringify(payload).length;
    const allowed = size <= this.policy.maxPayloadSize;
    this.audit('system', 'payload', `size:${size}`, allowed);
    return allowed;
  }

  detectSensitiveData(payload: any): string[] {
    const sensitivePatterns = [
      /api[_-]?key/i,
      /password/i,
      /secret/i,
      /token/i,
      /credential/i,
      /private[_-]?key/i,
      /ssn/i,
      /credit[_-]?card/i
    ];

    const findings: string[] = [];
    const payloadStr = JSON.stringify(payload);

    for (const pattern of sensitivePatterns) {
      if (pattern.test(payloadStr)) {
        findings.push(`Potential sensitive data matching pattern: ${pattern}`);
      }
    }

    if (findings.length > 0) {
      this.audit('system', 'scan', 'sensitive_data', false);
    }

    return findings;
  }

  validateQuery(query: string): boolean {
    const dangerousPatterns = [
      /drop\s+table/i,
      /truncate\s+table/i,
      /delete\s+from\s+\w+\s*;/i, // DELETE without WHERE
      /update\s+\w+\s+set\s+.*\s*;/i, // UPDATE without WHERE
      /grant\s+/i,
      /revoke\s+/i,
      /create\s+user/i,
      /alter\s+user/i
    ];

    for (const pattern of dangerousPatterns) {
      if (pattern.test(query)) {
        this.audit('query', 'validate', `dangerous:${pattern}`, false);
        return false;
      }
    }

    return true;
  }

  private audit(server: string, action: string, resource: string, allowed: boolean): void {
    const entry: MCPPermission = {
      server,
      action,
      resource,
      allowed
    };
    
    this.auditLog.push(entry);
    
    if (!allowed) {
      console.warn(`[MCP Guard] Blocked: ${server} - ${action} on ${resource}`);
    }
  }

  getAuditLog(): MCPPermission[] {
    return [...this.auditLog];
  }

  generateSecurityReport(): string {
    const blocked = this.auditLog.filter(e => !e.allowed);
    const allowed = this.auditLog.filter(e => e.allowed);
    
    return `
MCP Security Report
==================
Total requests: ${this.auditLog.length}
Allowed: ${allowed.length}
Blocked: ${blocked.length}

Blocked Operations:
${blocked.map(e => `- ${e.server}: ${e.action} on ${e.resource}`).join('\n')}

Policy Summary:
- Allowed servers: ${this.policy.allowedServers.join(', ')}
- Denied actions: ${this.policy.deniedActions.join(', ')}
- Sensitive schemas: ${this.policy.sensitiveSchemas.join(', ')}
- Max payload size: ${this.policy.maxPayloadSize} bytes
    `.trim();
  }
}

// Export singleton instance
export const mcpGuard = new MCPSecurityGuard();