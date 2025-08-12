import { spawn, ChildProcess } from 'child_process';
import { mkdtempSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import type { SandboxConfig, BrunoExecutionContext } from '../executor/types';

export interface Sandbox {
  id: string;
  config: SandboxConfig;
  process?: ChildProcess;
  workDir: string;
  startTime: Date;
  cleanup: () => Promise<void>;
}

export class SandboxManager {
  private sandboxes: Map<string, Sandbox> = new Map();
  private dockerAvailable: boolean = false;

  constructor() {
    this.checkDockerAvailability();
  }

  private async checkDockerAvailability(): Promise<void> {
    try {
      const { execSync } = require('child_process');
      execSync('docker --version', { stdio: 'ignore' });
      this.dockerAvailable = true;
      console.log('[Bruno] Docker is available for sandboxing');
    } catch {
      this.dockerAvailable = false;
      console.warn('[Bruno] Docker not available, using process isolation');
    }
  }

  async createSandbox(context: BrunoExecutionContext): Promise<Sandbox> {
    const config: SandboxConfig = {
      id: context.sandboxId,
      type: this.dockerAvailable ? 'docker' : 'process',
      resources: {
        cpuShares: context.limits.cpu,
        memoryMB: context.limits.memory,
        diskMB: context.limits.disk,
        networkEnabled: context.limits.network
      },
      environment: context.environment,
      securityOptions: {
        noNewPrivileges: true,
        readOnlyRootFilesystem: false,
        allowPrivilegeEscalation: false,
        capabilities: {
          drop: ['ALL'],
          add: ['CHOWN', 'SETUID', 'SETGID']
        }
      }
    };

    let sandbox: Sandbox;

    switch (config.type) {
      case 'docker':
        sandbox = await this.createDockerSandbox(config, context);
        break;
      case 'process':
        sandbox = await this.createProcessSandbox(config, context);
        break;
      default:
        throw new Error(`Unsupported sandbox type: ${config.type}`);
    }

    this.sandboxes.set(sandbox.id, sandbox);
    return sandbox;
  }

  private async createDockerSandbox(config: SandboxConfig, context: BrunoExecutionContext): Promise<Sandbox> {
    // Create temporary directory for sandbox
    const workDir = mkdtempSync(join(tmpdir(), 'bruno-sandbox-'));

    // Docker run command with security options
    const dockerArgs = [
      'run',
      '--rm',
      '-i',
      `--name=bruno-${config.id}`,
      `--workdir=/workspace`,
      `-v`, `${workDir}:/workspace:rw`,
      `--memory=${config.resources.memoryMB}m`,
      `--cpus=${config.resources.cpuShares / 100}`,
      '--security-opt=no-new-privileges',
      '--cap-drop=ALL'
    ];

    // Add capabilities
    for (const cap of config.securityOptions.capabilities.add) {
      dockerArgs.push(`--cap-add=${cap}`);
    }

    // Add environment variables
    for (const [key, value] of Object.entries(config.environment)) {
      dockerArgs.push('-e', `${key}=${value}`);
    }

    // Network isolation
    if (!config.resources.networkEnabled) {
      dockerArgs.push('--network=none');
    }

    // Use a minimal base image
    dockerArgs.push('node:18-alpine', 'sh');

    const dockerProcess = spawn('docker', dockerArgs, {
      stdio: ['pipe', 'pipe', 'pipe']
    });

    const cleanup = async () => {
      try {
        // Kill docker container
        spawn('docker', ['kill', `bruno-${config.id}`], { stdio: 'ignore' });
        
        // Remove temporary directory
        rmSync(workDir, { recursive: true, force: true });
      } catch (error) {
        console.error('[Bruno] Sandbox cleanup error:', error);
      }
    };

    return {
      id: config.id,
      config,
      process: dockerProcess,
      workDir,
      startTime: new Date(),
      cleanup
    };
  }

  private async createProcessSandbox(config: SandboxConfig, context: BrunoExecutionContext): Promise<Sandbox> {
    // Create temporary directory for sandbox
    const workDir = mkdtempSync(join(tmpdir(), 'bruno-sandbox-'));

    // Process-based isolation (less secure but works everywhere)
    const processOptions = {
      cwd: workDir,
      env: {
        ...process.env,
        ...config.environment,
        // Override potentially dangerous environment variables
        PATH: '/usr/local/bin:/usr/bin:/bin',
        HOME: workDir,
        TMPDIR: workDir,
        NODE_ENV: 'sandbox'
      },
      stdio: ['pipe', 'pipe', 'pipe'] as any,
      // Limit process resources (platform-dependent)
      ...(process.platform === 'linux' && {
        uid: process.getuid?.() || 1000,
        gid: process.getgid?.() || 1000
      })
    };

    const cleanup = async () => {
      try {
        rmSync(workDir, { recursive: true, force: true });
      } catch (error) {
        console.error('[Bruno] Sandbox cleanup error:', error);
      }
    };

    return {
      id: config.id,
      config,
      workDir,
      startTime: new Date(),
      cleanup
    };
  }

  async destroySandbox(sandboxId: string): Promise<void> {
    const sandbox = this.sandboxes.get(sandboxId);
    if (!sandbox) {
      return;
    }

    // Kill process if running
    if (sandbox.process && !sandbox.process.killed) {
      sandbox.process.kill('SIGTERM');
      
      // Force kill after timeout
      setTimeout(() => {
        if (sandbox.process && !sandbox.process.killed) {
          sandbox.process.kill('SIGKILL');
        }
      }, 5000);
    }

    // Run cleanup
    await sandbox.cleanup();

    // Remove from registry
    this.sandboxes.delete(sandboxId);
  }

  async destroyAllSandboxes(): Promise<void> {
    const sandboxIds = Array.from(this.sandboxes.keys());
    
    await Promise.all(
      sandboxIds.map(id => this.destroySandbox(id))
    );
  }

  getSandbox(sandboxId: string): Sandbox | undefined {
    return this.sandboxes.get(sandboxId);
  }

  getActiveSandboxes(): Sandbox[] {
    return Array.from(this.sandboxes.values());
  }

  async enforceResourceLimits(sandboxId: string): Promise<void> {
    const sandbox = this.sandboxes.get(sandboxId);
    if (!sandbox) return;

    // Monitor resource usage
    if (sandbox.config.type === 'docker') {
      try {
        const { execSync } = require('child_process');
        const stats = execSync(`docker stats --no-stream --format "{{json .}}" bruno-${sandboxId}`);
        const usage = JSON.parse(stats.toString());
        
        // Parse and check usage
        const memoryUsage = this.parseMemoryUsage(usage.MemUsage);
        const cpuUsage = parseFloat(usage.CPUPerc);

        if (memoryUsage > sandbox.config.resources.memoryMB) {
          console.warn(`[Bruno] Sandbox ${sandboxId} exceeding memory limit`);
          await this.destroySandbox(sandboxId);
        }

        if (cpuUsage > sandbox.config.resources.cpuShares) {
          console.warn(`[Bruno] Sandbox ${sandboxId} exceeding CPU limit`);
        }
      } catch (error) {
        // Stats collection failed, ignore
      }
    }
  }

  private parseMemoryUsage(memString: string): number {
    // Parse Docker memory usage string (e.g., "100MiB / 512MiB")
    const match = memString.match(/(\d+(?:\.\d+)?)\s*([KMG]iB)/);
    if (!match) return 0;

    const value = parseFloat(match[1]);
    const unit = match[2];

    switch (unit) {
      case 'KiB': return value / 1024;
      case 'MiB': return value;
      case 'GiB': return value * 1024;
      default: return value;
    }
  }
}

// Export singleton instance
export const sandboxManager = new SandboxManager();