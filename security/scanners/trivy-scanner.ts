import { BaseScanner } from './base-scanner';
import type { SecurityScanResult, SecurityFinding, ScannerConfig } from './types';
import { join } from 'path';

export class TrivyScanner extends BaseScanner {
  constructor() {
    super({
      name: 'trivy',
      type: 'container',
      enabled: true,
      docker: {
        image: 'aquasec/trivy:latest',
        volumes: ['/var/run/docker.sock:/var/run/docker.sock']
      },
      timeout: 600000, // 10 minutes
      severity: ['critical', 'high', 'medium']
    });
  }

  async scan(target: string, options?: any): Promise<SecurityScanResult> {
    const startTime = new Date();
    
    try {
      // Determine scan type
      const scanType = this.determineScanType(target, options);
      
      switch (scanType) {
        case 'image':
          return await this.scanImage(target, options, startTime);
        case 'filesystem':
          return await this.scanFilesystem(target, options, startTime);
        case 'repository':
          return await this.scanRepository(target, options, startTime);
        default:
          throw new Error(`Unknown scan type: ${scanType}`);
      }
    } catch (error) {
      return this.createScanResult(
        'trivy',
        'container',
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
    if (target.includes(':') && !target.includes('/')) {
      return 'image';
    } else if (target.startsWith('http') || target.endsWith('.git')) {
      return 'repository';
    } else {
      return 'filesystem';
    }
  }

  private async scanImage(
    image: string, 
    options: any,
    startTime: Date
  ): Promise<SecurityScanResult> {
    const args = [
      'image',
      '--format', 'json',
      '--severity', (this.config.severity || ['CRITICAL', 'HIGH', 'MEDIUM']).join(','),
      '--quiet'
    ];

    if (options?.ignoreUnfixed) {
      args.push('--ignore-unfixed');
    }

    args.push(image);

    const result = await this.executeDocker(
      this.config.docker!.image,
      args,
      this.config.docker!.volumes
    );

    if (result.exitCode !== 0 && !result.stdout) {
      throw new Error(`Trivy scan failed: ${result.stderr}`);
    }

    const scanData = JSON.parse(result.stdout);
    const findings = this.parseTrivyResults(scanData);
    
    return this.createScanResult(
      'trivy',
      'container',
      findings,
      'success',
      { 
        image,
        scanType: 'image',
        layers: scanData.Results?.length || 0
      }
    );
  }

  private async scanFilesystem(
    path: string,
    options: any,
    startTime: Date
  ): Promise<SecurityScanResult> {
    const absolutePath = join(process.cwd(), path);
    
    const args = [
      'filesystem',
      '--format', 'json',
      '--severity', (this.config.severity || ['CRITICAL', 'HIGH', 'MEDIUM']).join(','),
      '--quiet'
    ];

    if (options?.scanners) {
      args.push('--scanners', options.scanners.join(','));
    } else {
      args.push('--scanners', 'vuln,secret,config');
    }

    args.push('/scan');

    const volumes = [
      `${absolutePath}:/scan:ro`
    ];

    const result = await this.executeDocker(
      this.config.docker!.image,
      args,
      volumes
    );

    if (result.exitCode !== 0 && !result.stdout) {
      throw new Error(`Trivy scan failed: ${result.stderr}`);
    }

    const scanData = JSON.parse(result.stdout);
    const findings = this.parseTrivyResults(scanData);
    
    return this.createScanResult(
      'trivy',
      'dependency',
      findings,
      'success',
      { 
        path,
        scanType: 'filesystem',
        scanners: options?.scanners || ['vuln', 'secret', 'config']
      }
    );
  }

  private async scanRepository(
    repo: string,
    options: any,
    startTime: Date
  ): Promise<SecurityScanResult> {
    const args = [
      'repository',
      '--format', 'json',
      '--severity', (this.config.severity || ['CRITICAL', 'HIGH', 'MEDIUM']).join(','),
      '--quiet',
      repo
    ];

    if (options?.branch) {
      args.push('--branch', options.branch);
    }

    if (options?.commit) {
      args.push('--commit', options.commit);
    }

    const result = await this.executeDocker(
      this.config.docker!.image,
      args,
      this.config.docker!.volumes
    );

    if (result.exitCode !== 0 && !result.stdout) {
      throw new Error(`Trivy scan failed: ${result.stderr}`);
    }

    const scanData = JSON.parse(result.stdout);
    const findings = this.parseTrivyResults(scanData);
    
    return this.createScanResult(
      'trivy',
      'dependency',
      findings,
      'success',
      { 
        repository: repo,
        scanType: 'repository',
        branch: options?.branch,
        commit: options?.commit
      }
    );
  }

  private parseTrivyResults(data: any): SecurityFinding[] {
    const findings: SecurityFinding[] = [];

    // Handle different Trivy output formats
    const results = data.Results || [data];

    for (const result of results) {
      const vulnerabilities = result.Vulnerabilities || [];
      const secrets = result.Secrets || [];
      const misconfigurations = result.Misconfigurations || [];

      // Parse vulnerabilities
      for (const vuln of vulnerabilities) {
        findings.push({
          id: vuln.VulnerabilityID || `trivy-${Date.now()}-${findings.length}`,
          type: 'vulnerability',
          severity: this.mapSeverity(vuln.Severity),
          title: vuln.Title || `${vuln.PkgName} - ${vuln.VulnerabilityID}`,
          description: vuln.Description || 'No description available',
          location: {
            file: result.Target || vuln.PkgPath
          },
          cve: vuln.VulnerabilityID,
          cwe: vuln.CweIDs?.[0],
          remediation: vuln.FixedVersion ? 
            `Upgrade ${vuln.PkgName} to version ${vuln.FixedVersion}` : 
            'No fix available',
          references: vuln.References || []
        });
      }

      // Parse secrets
      for (const secret of secrets) {
        findings.push({
          id: `trivy-secret-${Date.now()}-${findings.length}`,
          type: 'secret',
          severity: 'high',
          title: `Secret found: ${secret.Title}`,
          description: `${secret.Category}: ${secret.Title}`,
          location: {
            file: secret.Target,
            line: secret.StartLine,
            endLine: secret.EndLine
          },
          remediation: 'Remove the secret and rotate credentials'
        });
      }

      // Parse misconfigurations
      for (const misconfig of misconfigurations) {
        findings.push({
          id: misconfig.ID || `trivy-config-${Date.now()}-${findings.length}`,
          type: 'misconfiguration',
          severity: this.mapSeverity(misconfig.Severity),
          title: misconfig.Title,
          description: misconfig.Description,
          location: {
            file: result.Target,
            line: misconfig.CauseMetadata?.StartLine,
            endLine: misconfig.CauseMetadata?.EndLine
          },
          remediation: misconfig.Resolution,
          references: misconfig.References || []
        });
      }
    }

    // Filter findings
    const filteredFindings = findings
      .filter(f => !this.shouldIgnoreFinding(f))
      .filter(f => this.filterBySeverity([f]).length > 0);

    return filteredFindings;
  }

  private mapSeverity(trivySeverity: string): SecurityFinding['severity'] {
    const severityMap: Record<string, SecurityFinding['severity']> = {
      'CRITICAL': 'critical',
      'HIGH': 'high',
      'MEDIUM': 'medium',
      'LOW': 'low',
      'UNKNOWN': 'info'
    };

    return severityMap[trivySeverity?.toUpperCase()] || 'info';
  }
}