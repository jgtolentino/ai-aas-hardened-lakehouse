import type { BrunoJob, BrunoPolicy, PolicyRule, SecurityEvent } from '../executor/types';

export class PolicyEngine {
  private policies: Map<string, BrunoPolicy> = new Map();
  private securityEvents: SecurityEvent[] = [];
  private defaultPolicy: 'allow' | 'deny' = 'deny';

  constructor() {
    this.loadDefaultPolicies();
  }

  private loadDefaultPolicies(): void {
    // Network access policy
    this.addPolicy({
      name: 'network-access',
      description: 'Controls network access for jobs',
      enforcement: 'strict',
      rules: [
        {
          id: 'deny-external-network',
          type: 'deny',
          resource: 'network:*',
          actions: ['connect', 'bind'],
          conditions: {
            destination: { not: ['localhost', '127.0.0.1', '::1'] }
          }
        },
        {
          id: 'allow-localhost',
          type: 'allow',
          resource: 'network:localhost',
          actions: ['connect']
        }
      ]
    });

    // File system policy
    this.addPolicy({
      name: 'filesystem-access',
      description: 'Controls file system access',
      enforcement: 'strict',
      rules: [
        {
          id: 'deny-system-dirs',
          type: 'deny',
          resource: 'file:*',
          actions: ['write', 'delete'],
          conditions: {
            path: { matches: ['/etc/*', '/usr/*', '/bin/*', '/sbin/*', '/var/*'] }
          }
        },
        {
          id: 'allow-workspace',
          type: 'allow',
          resource: 'file:workspace',
          actions: ['read', 'write', 'create']
        },
        {
          id: 'allow-temp',
          type: 'allow',
          resource: 'file:/tmp/*',
          actions: ['read', 'write', 'create', 'delete']
        }
      ]
    });

    // Process execution policy
    this.addPolicy({
      name: 'process-execution',
      description: 'Controls process execution',
      enforcement: 'strict',
      rules: [
        {
          id: 'deny-dangerous-commands',
          type: 'deny',
          resource: 'process:*',
          actions: ['execute'],
          conditions: {
            command: { 
              matches: [
                'rm -rf /*',
                'dd if=/dev/zero',
                'fork bomb',
                ':(){ :|:& };:',
                'chmod 777 /',
                'sudo *',
                'su *'
              ]
            }
          }
        },
        {
          id: 'allow-safe-commands',
          type: 'allow',
          resource: 'process:*',
          actions: ['execute'],
          conditions: {
            command: {
              matches: [
                'ls *',
                'cat *',
                'echo *',
                'grep *',
                'sed *',
                'awk *',
                'node *',
                'python *',
                'npm *',
                'yarn *',
                'pnpm *'
              ]
            }
          }
        }
      ]
    });

    // Resource limits policy
    this.addPolicy({
      name: 'resource-limits',
      description: 'Enforces resource consumption limits',
      enforcement: 'strict',
      rules: [
        {
          id: 'cpu-limit',
          type: 'deny',
          resource: 'system:cpu',
          actions: ['exceed'],
          conditions: {
            usage: { greaterThan: 80 } // 80% CPU
          }
        },
        {
          id: 'memory-limit',
          type: 'deny',
          resource: 'system:memory',
          actions: ['exceed'],
          conditions: {
            usage: { greaterThan: 1024 } // 1GB
          }
        },
        {
          id: 'disk-limit',
          type: 'deny',
          resource: 'system:disk',
          actions: ['exceed'],
          conditions: {
            usage: { greaterThan: 5120 } // 5GB
          }
        }
      ]
    });
  }

  addPolicy(policy: BrunoPolicy): void {
    this.policies.set(policy.name, policy);
  }

  removePolicy(name: string): void {
    this.policies.delete(name);
  }

  validateJob(job: BrunoJob): { allowed: boolean; violations: SecurityEvent[] } {
    const violations: SecurityEvent[] = [];
    let allowed = true;

    // Check each policy
    for (const policy of this.policies.values()) {
      const policyResult = this.evaluatePolicy(policy, job);
      
      if (!policyResult.allowed) {
        allowed = false;
        violations.push(...policyResult.violations);
      }
    }

    // Log security events
    this.securityEvents.push(...violations);

    return { allowed, violations };
  }

  private evaluatePolicy(policy: BrunoPolicy, job: BrunoJob): { allowed: boolean; violations: SecurityEvent[] } {
    const violations: SecurityEvent[] = [];
    let hasAllowRule = false;
    let hasDenyRule = false;

    for (const rule of policy.rules) {
      if (this.matchesRule(rule, job)) {
        if (rule.type === 'deny') {
          hasDenyRule = true;
          violations.push({
            timestamp: new Date(),
            type: 'policy_violation',
            severity: 'high',
            details: `Policy ${policy.name} rule ${rule.id} denied: ${rule.resource}`,
            action: 'blocked'
          });
        } else {
          hasAllowRule = true;
        }
      }
    }

    // Determine final decision based on policy enforcement
    let allowed: boolean;
    switch (policy.enforcement) {
      case 'strict':
        allowed = hasAllowRule && !hasDenyRule;
        break;
      case 'permissive':
        allowed = !hasDenyRule;
        break;
      case 'audit':
        allowed = true; // Always allow but log
        break;
      default:
        allowed = this.defaultPolicy === 'allow';
    }

    return { allowed, violations };
  }

  private matchesRule(rule: PolicyRule, job: BrunoJob): boolean {
    // Check if job matches rule resource pattern
    const resourceMatch = this.matchesResource(rule.resource, job);
    if (!resourceMatch) return false;

    // Check if job action matches rule actions
    const actionMatch = this.matchesAction(rule.actions, job);
    if (!actionMatch) return false;

    // Check conditions if present
    if (rule.conditions) {
      return this.matchesConditions(rule.conditions, job);
    }

    return true;
  }

  private matchesResource(pattern: string, job: BrunoJob): boolean {
    // Simple pattern matching (can be enhanced with glob patterns)
    if (pattern === '*') return true;
    
    // Extract resource type from pattern
    const [resourceType, resourcePath] = pattern.split(':');
    
    switch (resourceType) {
      case 'file':
        return job.type === 'file';
      case 'process':
        return job.type === 'shell' || job.type === 'script';
      case 'network':
        return job.type === 'api';
      case 'database':
        return job.type === 'database';
      default:
        return false;
    }
  }

  private matchesAction(actions: string[], job: BrunoJob): boolean {
    // Map job types to actions
    const jobActions: string[] = [];
    
    switch (job.type) {
      case 'shell':
      case 'script':
        jobActions.push('execute');
        break;
      case 'file':
        jobActions.push('read', 'write', 'create', 'delete');
        break;
      case 'api':
        jobActions.push('connect', 'request');
        break;
      case 'database':
        jobActions.push('query', 'read', 'write');
        break;
    }

    return actions.some(action => jobActions.includes(action));
  }

  private matchesConditions(conditions: Record<string, any>, job: BrunoJob): boolean {
    for (const [key, condition] of Object.entries(conditions)) {
      if (!this.evaluateCondition(key, condition, job)) {
        return false;
      }
    }
    return true;
  }

  private evaluateCondition(key: string, condition: any, job: BrunoJob): boolean {
    // Handle different condition types
    if (typeof condition === 'object') {
      if ('matches' in condition) {
        const value = this.getJobValue(key, job);
        return condition.matches.some((pattern: string) => 
          this.matchesPattern(pattern, value)
        );
      }
      if ('not' in condition) {
        const value = this.getJobValue(key, job);
        return !condition.not.includes(value);
      }
      if ('greaterThan' in condition) {
        const value = Number(this.getJobValue(key, job));
        return value > condition.greaterThan;
      }
    }
    
    return false;
  }

  private getJobValue(key: string, job: BrunoJob): any {
    switch (key) {
      case 'command':
        return job.command || '';
      case 'path':
        return job.workingDirectory || '';
      case 'destination':
        // Extract from API endpoint or command
        return 'localhost'; // Simplified
      default:
        return job.payload?.[key];
    }
  }

  private matchesPattern(pattern: string, value: string): boolean {
    // Convert glob pattern to regex
    const regex = pattern
      .replace(/\*/g, '.*')
      .replace(/\?/g, '.');
    
    return new RegExp(`^${regex}$`).test(value);
  }

  getSecurityEvents(limit?: number): SecurityEvent[] {
    const events = [...this.securityEvents];
    if (limit) {
      return events.slice(-limit);
    }
    return events;
  }

  clearSecurityEvents(): void {
    this.securityEvents = [];
  }
}