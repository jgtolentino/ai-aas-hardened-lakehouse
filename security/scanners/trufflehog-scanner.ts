import { BaseScanner } from './base-scanner';
import type { SecurityScanResult, SecurityFinding, ScannerConfig } from './types';
import { join } from 'path';

export class TruffleHogScanner extends BaseScanner {
  constructor() {
    super({
      name: 'trufflehog',
      type: 'secrets',
      enabled: true,
      docker: {
        image: 'trufflesecurity/trufflehog:latest'
      },
      timeout: 900000, // 15 minutes
      severity: ['critical', 'high'] // Secrets are always high/critical
    });
  }

  async scan(target: string, options?: any): Promise<SecurityScanResult> {
    const startTime = new Date();
    
    try {
      const scanType = this.determineScanType(target, options);
      let findings: SecurityFinding[] = [];

      switch (scanType) {
        case 'filesystem':
          findings = await this.scanFilesystem(target, options);
          break;
        case 'git':
          findings = await this.scanGitRepo(target, options);
          break;
        case 'docker':
          findings = await this.scanDockerImage(target, options);
          break;
        default:
          throw new Error(`Unknown scan type: ${scanType}`);
      }
      
      return this.createScanResult(
        'trufflehog',
        'secrets',
        findings,
        'success',
        {
          target,
          scanType,
          verified: options?.verify || false
        }
      );
    } catch (error) {
      return this.createScanResult(
        'trufflehog',
        'secrets',
        [],
        'failure',
        { error: error.message }
      );
    }
  }

  private determineScanType(target: string, options?: any): string {
    if (options?.type) {
      return options.type;
    }
    
    // Auto-detect based on target
    if (target.endsWith('.git') || target.includes('github.com')) {
      return 'git';
    } else if (target.includes(':') && !target.includes('/')) {
      return 'docker';
    } else {
      return 'filesystem';
    }
  }

  private async scanFilesystem(
    path: string,
    options?: any
  ): Promise<SecurityFinding[]> {
    const absolutePath = join(process.cwd(), path);
    
    const args = [
      'filesystem',
      '--json',
      '--no-update'
    ];

    // Add verification flag
    if (options?.verify) {
      args.push('--verify');
    }

    // Add concurrency
    args.push('--concurrency', '5');

    // Add exclude patterns
    if (options?.excludePaths) {
      for (const pattern of options.excludePaths) {
        args.push('--exclude-paths', pattern);
      }
    }

    // Add include patterns
    if (options?.includePaths) {
      for (const pattern of options.includePaths) {
        args.push('--include-paths', pattern);
      }
    }

    // Add the target path
    args.push('/scan');

    const volumes = [`${absolutePath}:/scan:ro`];

    const result = await this.executeDocker(
      this.config.docker!.image,
      args,
      volumes
    );

    // TruffleHog outputs JSON lines, not a single JSON object
    return this.parseTruffleHogResults(result.stdout);
  }

  private async scanGitRepo(
    repo: string,
    options?: any
  ): Promise<SecurityFinding[]> {
    const args = [
      'git',
      '--json',
      '--no-update'
    ];

    // Add verification flag
    if (options?.verify) {
      args.push('--verify');
    }

    // Add branch
    if (options?.branch) {
      args.push('--branch', options.branch);
    }

    // Add commit range
    if (options?.since) {
      args.push('--since-commit', options.since);
    }

    // Add concurrency
    args.push('--concurrency', '5');

    // Add the repository URL
    args.push(repo);

    const result = await this.executeDocker(
      this.config.docker!.image,
      args,
      this.config.docker!.volumes
    );

    return this.parseTruffleHogResults(result.stdout);
  }

  private async scanDockerImage(
    image: string,
    options?: any
  ): Promise<SecurityFinding[]> {
    const args = [
      'docker',
      '--json',
      '--no-update',
      '--image', image
    ];

    // Add verification flag
    if (options?.verify) {
      args.push('--verify');
    }

    const volumes = ['/var/run/docker.sock:/var/run/docker.sock'];

    const result = await this.executeDocker(
      this.config.docker!.image,
      args,
      volumes
    );

    return this.parseTruffleHogResults(result.stdout);
  }

  private parseTruffleHogResults(output: string): SecurityFinding[] {
    const findings: SecurityFinding[] = [];
    const lines = output.split('\n').filter(line => line.trim());

    for (const line of lines) {
      try {
        const result = JSON.parse(line);
        
        // Skip if not a valid finding
        if (!result.DetectorName || !result.Raw) {
          continue;
        }

        const finding: SecurityFinding = {
          id: `trufflehog-${result.DetectorName}-${Date.now()}-${findings.length}`,
          type: 'secret',
          severity: result.Verified ? 'critical' : 'high',
          title: `${result.DetectorName} secret detected`,
          description: this.getSecretDescription(result),
          location: this.extractLocation(result),
          remediation: this.getRemediation(result),
          references: this.getReferences(result)
        };

        // Add metadata
        if (result.Verified) {
          finding.description += ' (VERIFIED - Active credential!)';
        }

        findings.push(finding);
      } catch (error) {
        // Skip invalid JSON lines
        continue;
      }
    }

    // Filter findings
    const filteredFindings = findings
      .filter(f => !this.shouldIgnoreFinding(f))
      .filter(f => this.filterBySeverity([f]).length > 0);

    return filteredFindings;
  }

  private getSecretDescription(result: any): string {
    const descriptions: Record<string, string> = {
      'AWS': 'AWS Access Key detected',
      'Azure': 'Azure credentials detected',
      'GCP': 'Google Cloud credentials detected',
      'Github': 'GitHub token detected',
      'Gitlab': 'GitLab token detected',
      'Slack': 'Slack token detected',
      'Private Key': 'Private cryptographic key detected',
      'JWT': 'JSON Web Token detected',
      'NPM': 'NPM token detected',
      'PyPI': 'PyPI token detected',
      'Stripe': 'Stripe API key detected',
      'SendGrid': 'SendGrid API key detected',
      'Twilio': 'Twilio credentials detected',
      'Generic API Key': 'API key pattern detected',
      'Generic Secret': 'Secret pattern detected'
    };

    const detector = result.DetectorName;
    let description = descriptions[detector] || `${detector} secret detected`;

    if (result.DecoderName) {
      description += ` (${result.DecoderName} encoded)`;
    }

    return description;
  }

  private extractLocation(result: any): SecurityFinding['location'] {
    const location: SecurityFinding['location'] = {};

    if (result.SourceMetadata) {
      const meta = result.SourceMetadata;
      
      if (meta.Data && meta.Data.Filesystem) {
        location.file = meta.Data.Filesystem.file;
        location.line = meta.Data.Filesystem.line;
      } else if (meta.Data && meta.Data.Git) {
        location.file = meta.Data.Git.file;
        location.line = meta.Data.Git.line;
      }
    }

    return location;
  }

  private getRemediation(result: any): string {
    const remediations: Record<string, string> = {
      'AWS': '1. Rotate the AWS access key immediately\n2. Check CloudTrail for unauthorized usage\n3. Remove from code and use AWS IAM roles or environment variables',
      'Azure': '1. Regenerate Azure credentials\n2. Check Azure Activity Log for unauthorized access\n3. Use Azure Key Vault or managed identities',
      'GCP': '1. Revoke and rotate GCP credentials\n2. Check Cloud Audit Logs\n3. Use GCP Secret Manager or service accounts',
      'Github': '1. Revoke the GitHub token immediately\n2. Check repository access logs\n3. Use GitHub Apps or deploy keys with minimal permissions',
      'Private Key': '1. Generate new key pair\n2. Update all systems using the key\n3. Never commit private keys - use secure key management',
      'JWT': '1. Invalidate the JWT if possible\n2. Rotate signing keys\n3. Implement proper JWT storage and handling',
      'Generic API Key': '1. Revoke and regenerate the API key\n2. Check API logs for unauthorized usage\n3. Use environment variables or secret management tools'
    };

    const detector = result.DetectorName;
    return remediations[detector] || 
      '1. Revoke and rotate the credential immediately\n' +
      '2. Check logs for unauthorized access\n' +
      '3. Remove from code and use secure secret management';
  }

  private getReferences(result: any): string[] {
    const references: string[] = [];

    // Add detector-specific references
    const detectorRefs: Record<string, string[]> = {
      'AWS': [
        'https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html',
        'https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html'
      ],
      'Azure': [
        'https://docs.microsoft.com/en-us/azure/security/fundamentals/identity-management-best-practices'
      ],
      'GCP': [
        'https://cloud.google.com/docs/authentication/best-practices-applications'
      ],
      'Github': [
        'https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token'
      ]
    };

    if (detectorRefs[result.DetectorName]) {
      references.push(...detectorRefs[result.DetectorName]);
    }

    // Add generic secret management references
    references.push(
      'https://owasp.org/www-project-cheat-sheets/cheatsheets/Secrets_Management_Cheat_Sheet.html'
    );

    return references;
  }
}