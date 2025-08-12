import { EventEmitter } from 'events';
import type { 
  SecurityPolicy, 
  PolicyRule, 
  PolicyException,
  SecurityFinding,
  SecurityScanResult 
} from '../scanners/types';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

export interface PolicyEvaluationResult {
  policyId: string;
  passed: boolean;
  violations: PolicyViolation[];
  exceptions: AppliedException[];
  summary: {
    totalFindings: number;
    violatingFindings: number;
    exceptedFindings: number;
  };
}

export interface PolicyViolation {
  ruleId: string;
  finding: SecurityFinding;
  message: string;
  remediation: string;
}

export interface AppliedException {
  exceptionId: string;
  findingId: string;
  reason: string;
}

export interface PolicyEngineConfig {
  enforcement?: 'block' | 'warn' | 'monitor';
  policyPaths?: string[];
  exceptionPaths?: string[];
}

export class SecurityPolicyEngine extends EventEmitter {
  private policies: Map<string, SecurityPolicy> = new Map();
  private config: PolicyEngineConfig;

  constructor(config: PolicyEngineConfig = {}) {
    super();
    this.config = {
      enforcement: 'block',
      policyPaths: ['./security/policies/default'],
      exceptionPaths: ['./security/policies/exceptions'],
      ...config
    };

    this.loadPolicies();
  }

  private loadPolicies(): void {
    // Load default policies
    this.loadDefaultPolicies();

    // Load custom policies from files
    if (this.config.policyPaths) {
      for (const path of this.config.policyPaths) {
        this.loadPoliciesFromPath(path);
      }
    }
  }

  private loadDefaultPolicies(): void {
    // OWASP Top 10 Policy
    const owaspPolicy: SecurityPolicy = {
      id: 'owasp-top-10',
      name: 'OWASP Top 10 Security Policy',
      description: 'Enforces protection against OWASP Top 10 vulnerabilities',
      enforcement: 'block',
      rules: [
        {
          id: 'injection',
          severity: 'critical',
          pattern: 'injection|sqli|sql-injection',
          message: 'Injection vulnerabilities must be fixed immediately',
          remediation: 'Use parameterized queries and input validation'
        },
        {
          id: 'broken-auth',
          severity: 'high',
          pattern: 'authentication|auth-bypass|weak-password',
          message: 'Authentication vulnerabilities pose significant risk',
          remediation: 'Implement proper authentication mechanisms'
        },
        {
          id: 'sensitive-data',
          severity: 'high',
          pattern: 'sensitive-data|data-exposure|cleartext',
          message: 'Sensitive data must be protected',
          remediation: 'Encrypt sensitive data at rest and in transit'
        },
        {
          id: 'xxe',
          severity: 'high',
          pattern: 'xxe|xml-injection|xml-external',
          message: 'XML External Entity vulnerabilities must be fixed',
          remediation: 'Disable XML external entity processing'
        },
        {
          id: 'broken-access',
          severity: 'high',
          pattern: 'access-control|authorization|privilege',
          message: 'Access control vulnerabilities must be addressed',
          remediation: 'Implement proper authorization checks'
        }
      ]
    };

    // Secrets Policy
    const secretsPolicy: SecurityPolicy = {
      id: 'no-secrets',
      name: 'No Secrets in Code',
      description: 'Prevents secrets from being committed to code',
      enforcement: 'block',
      rules: [
        {
          id: 'verified-secrets',
          severity: 'critical',
          pattern: 'verified.*secret|active.*credential',
          message: 'Active secrets detected - immediate action required',
          remediation: 'Rotate credentials immediately and remove from code'
        },
        {
          id: 'any-secrets',
          severity: 'high',
          pattern: 'secret|password|api[_-]key|token',
          message: 'Potential secrets detected in code',
          remediation: 'Remove secrets and use secure secret management'
        }
      ]
    };

    // Container Security Policy
    const containerPolicy: SecurityPolicy = {
      id: 'container-security',
      name: 'Container Security Policy',
      description: 'Ensures container images are secure',
      enforcement: 'warn',
      rules: [
        {
          id: 'critical-vulns',
          severity: 'critical',
          cve: ['.*'],
          message: 'Critical vulnerabilities in container images',
          remediation: 'Update base images and dependencies'
        },
        {
          id: 'rootless',
          severity: 'medium',
          pattern: 'running.*root|user.*root',
          message: 'Containers should not run as root',
          remediation: 'Use non-root user in Dockerfile'
        }
      ]
    };

    this.policies.set(owaspPolicy.id, owaspPolicy);
    this.policies.set(secretsPolicy.id, secretsPolicy);
    this.policies.set(containerPolicy.id, containerPolicy);
  }

  private loadPoliciesFromPath(path: string): void {
    if (!existsSync(path)) {
      this.emit('policy:load:error', `Path not found: ${path}`);
      return;
    }

    // Load JSON policy files
    const policyFiles = [
      'owasp.json',
      'cis.json',
      'custom.json'
    ];

    for (const file of policyFiles) {
      const filePath = join(path, file);
      if (existsSync(filePath)) {
        try {
          const content = readFileSync(filePath, 'utf-8');
          const policy = JSON.parse(content) as SecurityPolicy;
          this.policies.set(policy.id, policy);
          this.emit('policy:loaded', policy.id);
        } catch (error) {
          this.emit('policy:load:error', `Failed to load ${filePath}: ${error}`);
        }
      }
    }
  }

  async evaluate(
    scanResults: SecurityScanResult[], 
    policyIds?: string[]
  ): Promise<PolicyEvaluationResult[]> {
    const results: PolicyEvaluationResult[] = [];
    const policiesToEvaluate = policyIds ? 
      policyIds.map(id => this.policies.get(id)).filter(p => p) as SecurityPolicy[] :
      Array.from(this.policies.values());

    for (const policy of policiesToEvaluate) {
      const result = await this.evaluatePolicy(policy, scanResults);
      results.push(result);
      
      this.emit('policy:evaluated', result);
      
      // Handle enforcement
      if (policy.enforcement === 'block' && !result.passed) {
        this.emit('policy:blocked', result);
      }
    }

    return results;
  }

  private async evaluatePolicy(
    policy: SecurityPolicy, 
    scanResults: SecurityScanResult[]
  ): Promise<PolicyEvaluationResult> {
    const violations: PolicyViolation[] = [];
    const exceptions: AppliedException[] = [];
    let totalFindings = 0;

    // Collect all findings
    const allFindings: SecurityFinding[] = [];
    for (const result of scanResults) {
      allFindings.push(...result.findings);
      totalFindings += result.findings.length;
    }

    // Evaluate each rule
    for (const rule of policy.rules) {
      const matchingFindings = this.findMatchingFindings(rule, allFindings);
      
      for (const finding of matchingFindings) {
        // Check if there's an exception
        const exception = this.findException(policy, rule, finding);
        
        if (exception) {
          exceptions.push({
            exceptionId: `${rule.id}-${exception.reason}`,
            findingId: finding.id,
            reason: exception.reason
          });
        } else {
          violations.push({
            ruleId: rule.id,
            finding,
            message: rule.message,
            remediation: rule.remediation
          });
        }
      }
    }

    const passed = violations.length === 0 || 
                  (policy.enforcement === 'monitor');

    return {
      policyId: policy.id,
      passed,
      violations,
      exceptions,
      summary: {
        totalFindings,
        violatingFindings: violations.length,
        exceptedFindings: exceptions.length
      }
    };
  }

  private findMatchingFindings(
    rule: PolicyRule, 
    findings: SecurityFinding[]
  ): SecurityFinding[] {
    return findings.filter(finding => {
      // Check severity
      if (!this.matchesSeverity(finding.severity, rule.severity)) {
        return false;
      }

      // Check pattern
      if (rule.pattern) {
        const regex = new RegExp(rule.pattern, 'i');
        const findingText = JSON.stringify(finding).toLowerCase();
        if (!regex.test(findingText)) {
          return false;
        }
      }

      // Check CWE
      if (rule.cwe && finding.cwe) {
        if (!rule.cwe.some(cwe => finding.cwe === cwe)) {
          return false;
        }
      }

      // Check OWASP
      if (rule.owasp && finding.owasp) {
        if (!rule.owasp.some(owasp => finding.owasp?.includes(owasp))) {
          return false;
        }
      }

      return true;
    });
  }

  private matchesSeverity(
    findingSeverity: string, 
    ruleSeverity: string
  ): boolean {
    const severityOrder = ['info', 'low', 'medium', 'high', 'critical'];
    const findingIndex = severityOrder.indexOf(findingSeverity);
    const ruleIndex = severityOrder.indexOf(ruleSeverity);
    
    // Finding severity must be at least as severe as rule severity
    return findingIndex >= ruleIndex;
  }

  private findException(
    policy: SecurityPolicy,
    rule: PolicyRule,
    finding: SecurityFinding
  ): PolicyException | undefined {
    if (!policy.exceptions) {
      return undefined;
    }

    return policy.exceptions.find(exception => {
      // Check if exception applies to this rule
      if (exception.ruleId !== rule.id) {
        return false;
      }

      // Check if exception has expired
      if (exception.expiresAt && new Date(exception.expiresAt) < new Date()) {
        return false;
      }

      // Check if exception applies to this path
      if (exception.path && finding.location?.file) {
        const regex = new RegExp(exception.path);
        if (!regex.test(finding.location.file)) {
          return false;
        }
      }

      return true;
    });
  }

  // Policy management methods
  addPolicy(policy: SecurityPolicy): void {
    this.policies.set(policy.id, policy);
    this.emit('policy:added', policy.id);
  }

  removePolicy(policyId: string): void {
    this.policies.delete(policyId);
    this.emit('policy:removed', policyId);
  }

  getPolicy(policyId: string): SecurityPolicy | undefined {
    return this.policies.get(policyId);
  }

  listPolicies(): SecurityPolicy[] {
    return Array.from(this.policies.values());
  }

  // Exception management
  addException(
    policyId: string, 
    exception: PolicyException
  ): void {
    const policy = this.policies.get(policyId);
    if (!policy) {
      throw new Error(`Policy ${policyId} not found`);
    }

    if (!policy.exceptions) {
      policy.exceptions = [];
    }

    policy.exceptions.push(exception);
    this.emit('exception:added', policyId, exception);
  }

  // Reporting methods
  generateReport(results: PolicyEvaluationResult[]): string {
    let report = '# Security Policy Evaluation Report\n\n';
    report += `Generated: ${new Date().toISOString()}\n\n`;

    // Summary
    const totalViolations = results.reduce((sum, r) => sum + r.violations.length, 0);
    const failedPolicies = results.filter(r => !r.passed).length;
    
    report += '## Summary\n';
    report += `- Total Policies Evaluated: ${results.length}\n`;
    report += `- Failed Policies: ${failedPolicies}\n`;
    report += `- Total Violations: ${totalViolations}\n\n`;

    // Policy Details
    report += '## Policy Results\n\n';
    
    for (const result of results) {
      const policy = this.policies.get(result.policyId);
      report += `### ${policy?.name || result.policyId}\n`;
      report += `- Status: ${result.passed ? '✅ PASSED' : '❌ FAILED'}\n`;
      report += `- Violations: ${result.violations.length}\n`;
      report += `- Exceptions Applied: ${result.exceptions.length}\n\n`;

      if (result.violations.length > 0) {
        report += '#### Violations\n';
        for (const violation of result.violations) {
          report += `- **${violation.finding.title}**\n`;
          report += `  - Severity: ${violation.finding.severity}\n`;
          report += `  - Location: ${violation.finding.location?.file || 'Unknown'}\n`;
          report += `  - Message: ${violation.message}\n`;
          report += `  - Remediation: ${violation.remediation}\n\n`;
        }
      }
    }

    return report;
  }
}

// Export singleton instance
export const policyEngine = new SecurityPolicyEngine();