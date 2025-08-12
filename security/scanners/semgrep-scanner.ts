import { BaseScanner } from './base-scanner';
import type { SecurityScanResult, SecurityFinding, ScannerConfig } from './types';
import { join } from 'path';

export class SemgrepScanner extends BaseScanner {
  constructor() {
    super({
      name: 'semgrep',
      type: 'sast',
      enabled: true,
      docker: {
        image: 'returntocorp/semgrep:latest'
      },
      timeout: 1200000, // 20 minutes
      severity: ['critical', 'high', 'medium'],
      customRules: []
    });
  }

  async scan(target: string, options?: any): Promise<SecurityScanResult> {
    const startTime = new Date();
    
    try {
      const absolutePath = join(process.cwd(), target);
      const findings = await this.runSemgrepScan(absolutePath, options);
      
      return this.createScanResult(
        'semgrep',
        'sast',
        findings,
        'success',
        {
          path: target,
          rulesetsUsed: options?.rulesets || ['auto'],
          customRules: this.config.customRules?.length || 0
        }
      );
    } catch (error) {
      return this.createScanResult(
        'semgrep',
        'sast',
        [],
        'failure',
        { error: error.message }
      );
    }
  }

  private async runSemgrepScan(
    path: string,
    options?: any
  ): Promise<SecurityFinding[]> {
    const args = [
      '--config=auto',
      '--json',
      '--no-git-ignore'
    ];

    // Add custom rulesets
    if (options?.rulesets) {
      for (const ruleset of options.rulesets) {
        args.push('--config', ruleset);
      }
    } else {
      // Use default security-focused rulesets
      args.push(
        '--config=p/security-audit',
        '--config=p/secrets',
        '--config=p/owasp-top-ten'
      );
    }

    // Add custom rules
    if (this.config.customRules && this.config.customRules.length > 0) {
      for (const rule of this.config.customRules) {
        args.push('--config', rule);
      }
    }

    // Add severity filter
    if (this.config.severity) {
      const severityLevels = ['INFO', 'WARNING', 'ERROR'];
      const minSeverity = this.mapToSemgrepSeverity(
        this.config.severity[this.config.severity.length - 1]
      );
      args.push('--severity', severityLevels.slice(
        severityLevels.indexOf(minSeverity)
      ).join(','));
    }

    // Add exclude patterns
    if (options?.excludePaths) {
      for (const pattern of options.excludePaths) {
        args.push('--exclude', pattern);
      }
    }

    // Add include patterns
    if (options?.includePaths) {
      for (const pattern of options.includePaths) {
        args.push('--include', pattern);
      }
    }

    // Add max file size limit
    args.push('--max-target-bytes', '5000000'); // 5MB

    // Add the target path
    args.push('/src');

    const volumes = [`${path}:/src:ro`];

    const result = await this.executeDocker(
      this.config.docker!.image,
      args,
      volumes
    );

    if (result.exitCode !== 0 && !result.stdout) {
      // Semgrep returns non-zero exit code when findings are found
      // Check if we have JSON output
      if (!result.stderr.includes('"results"')) {
        throw new Error(`Semgrep scan failed: ${result.stderr}`);
      }
    }

    // Parse results from stdout or stderr
    const output = result.stdout || result.stderr;
    const scanData = JSON.parse(output);
    
    return this.parseSemgrepResults(scanData);
  }

  private parseSemgrepResults(data: any): SecurityFinding[] {
    const findings: SecurityFinding[] = [];
    const results = data.results || [];

    for (const result of results) {
      const finding: SecurityFinding = {
        id: result.check_id || `semgrep-${Date.now()}-${findings.length}`,
        type: this.categorizeRule(result.check_id),
        severity: this.mapSeverity(result.extra?.severity || 'WARNING'),
        title: result.extra?.message || result.check_id,
        description: result.extra?.metadata?.description || 
                    'Security issue detected by Semgrep',
        location: {
          file: result.path.replace('/src/', ''),
          line: result.start?.line,
          column: result.start?.col,
          endLine: result.end?.line,
          endColumn: result.end?.col
        },
        remediation: result.extra?.fix || 
                    result.extra?.metadata?.remediation || 
                    'Review and fix the security issue',
        references: this.extractReferences(result.extra)
      };

      // Add CWE if available
      if (result.extra?.metadata?.cwe) {
        finding.cwe = Array.isArray(result.extra.metadata.cwe) ? 
          result.extra.metadata.cwe[0] : 
          result.extra.metadata.cwe;
      }

      // Add OWASP if available
      if (result.extra?.metadata?.owasp) {
        finding.owasp = Array.isArray(result.extra.metadata.owasp) ?
          result.extra.metadata.owasp.join(', ') :
          result.extra.metadata.owasp;
      }

      findings.push(finding);
    }

    // Filter findings
    const filteredFindings = findings
      .filter(f => !this.shouldIgnoreFinding(f))
      .filter(f => this.filterBySeverity([f]).length > 0);

    return filteredFindings;
  }

  private categorizeRule(ruleId: string): string {
    if (!ruleId) return 'security';

    const lowerRuleId = ruleId.toLowerCase();
    
    if (lowerRuleId.includes('injection') || lowerRuleId.includes('sqli')) {
      return 'injection';
    } else if (lowerRuleId.includes('xss') || lowerRuleId.includes('cross-site')) {
      return 'xss';
    } else if (lowerRuleId.includes('auth')) {
      return 'authentication';
    } else if (lowerRuleId.includes('crypto')) {
      return 'cryptography';
    } else if (lowerRuleId.includes('secret') || lowerRuleId.includes('password')) {
      return 'secret';
    } else if (lowerRuleId.includes('path') || lowerRuleId.includes('traversal')) {
      return 'path-traversal';
    } else if (lowerRuleId.includes('xxe') || lowerRuleId.includes('xml')) {
      return 'xxe';
    } else if (lowerRuleId.includes('deserialization')) {
      return 'deserialization';
    } else {
      return 'security';
    }
  }

  private mapSeverity(semgrepSeverity: string): SecurityFinding['severity'] {
    const severityMap: Record<string, SecurityFinding['severity']> = {
      'ERROR': 'high',
      'WARNING': 'medium',
      'INFO': 'low',
      'CRITICAL': 'critical',
      'HIGH': 'high',
      'MEDIUM': 'medium',
      'LOW': 'low'
    };

    return severityMap[semgrepSeverity?.toUpperCase()] || 'info';
  }

  private mapToSemgrepSeverity(severity: string): string {
    const severityMap: Record<string, string> = {
      'critical': 'ERROR',
      'high': 'ERROR',
      'medium': 'WARNING',
      'low': 'INFO',
      'info': 'INFO'
    };

    return severityMap[severity] || 'INFO';
  }

  private extractReferences(extra: any): string[] {
    const references: string[] = [];

    if (extra?.metadata?.references) {
      if (Array.isArray(extra.metadata.references)) {
        references.push(...extra.metadata.references);
      } else {
        references.push(extra.metadata.references);
      }
    }

    if (extra?.metadata?.source) {
      references.push(extra.metadata.source);
    }

    return references;
  }
}