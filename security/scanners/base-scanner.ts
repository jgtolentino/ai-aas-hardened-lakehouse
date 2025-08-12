import { EventEmitter } from 'events';
import { spawn } from 'child_process';
import { existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import type { Scanner, ScannerConfig, SecurityScanResult, SecurityFinding } from './types';

export abstract class BaseScanner extends EventEmitter implements Scanner {
  protected config: ScannerConfig;
  
  constructor(config: ScannerConfig) {
    super();
    this.config = config;
  }

  get name(): string {
    return this.config.name;
  }

  get type(): ScannerConfig['type'] {
    return this.config.type;
  }

  abstract scan(target: string, options?: any): Promise<SecurityScanResult>;
  
  async isAvailable(): Promise<boolean> {
    if (this.config.docker) {
      return this.checkDockerImage(this.config.docker.image);
    }
    if (this.config.command) {
      return this.checkCommand(this.config.command);
    }
    return false;
  }

  async getVersion(): Promise<string> {
    try {
      if (this.config.command) {
        const versionCmd = `${this.config.command} --version`;
        const result = await this.executeCommand(versionCmd);
        return result.stdout.trim();
      }
      return 'unknown';
    } catch {
      return 'unknown';
    }
  }

  protected async executeCommand(
    command: string,
    args: string[] = [],
    options: any = {}
  ): Promise<{ stdout: string; stderr: string; exitCode: number }> {
    return new Promise((resolve, reject) => {
      const timeout = this.config.timeout || 300000; // 5 minutes default
      let stdout = '';
      let stderr = '';
      let timedOut = false;

      const child = spawn(command, args, {
        ...options,
        shell: true
      });

      const timer = setTimeout(() => {
        timedOut = true;
        child.kill('SIGTERM');
      }, timeout);

      child.stdout?.on('data', (data) => {
        stdout += data.toString();
      });

      child.stderr?.on('data', (data) => {
        stderr += data.toString();
      });

      child.on('exit', (code) => {
        clearTimeout(timer);
        if (timedOut) {
          reject(new Error(`Command timed out after ${timeout}ms`));
        } else {
          resolve({
            stdout,
            stderr,
            exitCode: code || 0
          });
        }
      });

      child.on('error', (error) => {
        clearTimeout(timer);
        reject(error);
      });
    });
  }

  protected async executeDocker(
    image: string,
    args: string[],
    volumes: string[] = [],
    env: Record<string, string> = {}
  ): Promise<{ stdout: string; stderr: string; exitCode: number }> {
    const dockerArgs = ['run', '--rm'];
    
    // Add volumes
    for (const volume of volumes) {
      dockerArgs.push('-v', volume);
    }
    
    // Add environment variables
    for (const [key, value] of Object.entries(env)) {
      dockerArgs.push('-e', `${key}=${value}`);
    }
    
    // Add image and command args
    dockerArgs.push(image, ...args);
    
    return this.executeCommand('docker', dockerArgs);
  }

  protected async checkCommand(command: string): Promise<boolean> {
    try {
      const result = await this.executeCommand(`which ${command.split(' ')[0]}`);
      return result.exitCode === 0;
    } catch {
      return false;
    }
  }

  protected async checkDockerImage(image: string): Promise<boolean> {
    try {
      const result = await this.executeCommand(`docker image inspect ${image}`);
      return result.exitCode === 0;
    } catch {
      // Try to pull the image
      try {
        const pullResult = await this.executeCommand(`docker pull ${image}`);
        return pullResult.exitCode === 0;
      } catch {
        return false;
      }
    }
  }

  protected createScanResult(
    scanner: string,
    scanType: ScannerConfig['type'],
    findings: SecurityFinding[],
    status: 'success' | 'failure' | 'partial' = 'success',
    metadata?: any
  ): SecurityScanResult {
    const summary = {
      total: findings.length,
      critical: findings.filter(f => f.severity === 'critical').length,
      high: findings.filter(f => f.severity === 'high').length,
      medium: findings.filter(f => f.severity === 'medium').length,
      low: findings.filter(f => f.severity === 'low').length,
      info: findings.filter(f => f.severity === 'info').length
    };

    return {
      scanId: `${scanner}-${Date.now()}`,
      scanner,
      scanType,
      startTime: new Date(),
      endTime: new Date(),
      status,
      findings,
      summary,
      metadata
    };
  }

  protected shouldIgnoreFinding(finding: SecurityFinding): boolean {
    if (!this.config.ignorePatterns || this.config.ignorePatterns.length === 0) {
      return false;
    }

    const findingStr = JSON.stringify(finding).toLowerCase();
    return this.config.ignorePatterns.some(pattern => {
      const regex = new RegExp(pattern.toLowerCase());
      return regex.test(findingStr);
    });
  }

  protected filterBySeverity(findings: SecurityFinding[]): SecurityFinding[] {
    if (!this.config.severity || this.config.severity.length === 0) {
      return findings;
    }

    return findings.filter(finding => 
      this.config.severity!.includes(finding.severity)
    );
  }

  protected ensureOutputDirectory(path: string): void {
    if (!existsSync(path)) {
      mkdirSync(path, { recursive: true });
    }
  }
}