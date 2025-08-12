import { EventEmitter } from 'events';
import { spawn } from 'child_process';
import { writeFileSync, readFileSync, existsSync } from 'fs';
import { join } from 'path';
import type { 
  BrunoJob, 
  BrunoResult, 
  BrunoExecutionContext, 
  SecurityEvent 
} from './types';
import { PolicyEngine } from '../security/policy-engine';
import { sandboxManager } from '../sandbox/sandbox-manager';
import { createHash } from 'crypto';

export class BrunoExecutor extends EventEmitter {
  private policyEngine: PolicyEngine;
  private activeJobs: Map<string, BrunoExecutionContext> = new Map();
  private jobHistory: Map<string, BrunoResult> = new Map();
  private maxConcurrentJobs: number = 10;

  constructor() {
    super();
    this.policyEngine = new PolicyEngine();
    this.setupCleanup();
  }

  private setupCleanup(): void {
    // Cleanup on exit
    process.on('exit', () => {
      sandboxManager.destroyAllSandboxes();
    });

    process.on('SIGINT', () => {
      sandboxManager.destroyAllSandboxes();
      process.exit(0);
    });

    process.on('SIGTERM', () => {
      sandboxManager.destroyAllSandboxes();
      process.exit(0);
    });
  }

  async execute(job: BrunoJob): Promise<BrunoResult> {
    const startTime = Date.now();
    
    try {
      // Validate job against security policies
      const validation = this.policyEngine.validateJob(job);
      if (!validation.allowed) {
        return this.createFailureResult(job.id, 'Security policy violation', validation.violations, startTime);
      }

      // Check concurrent job limit
      if (this.activeJobs.size >= this.maxConcurrentJobs) {
        return this.createFailureResult(job.id, 'Too many concurrent jobs', [], startTime);
      }

      // Create execution context
      const context = this.createExecutionContext(job);
      this.activeJobs.set(job.id, context);
      this.emit('job:started', { jobId: job.id, context });

      // Create sandbox
      const sandbox = await sandboxManager.createSandbox(context);

      // Execute job based on type
      let result: BrunoResult;
      switch (job.type) {
        case 'shell':
          result = await this.executeShellCommand(job, context, sandbox);
          break;
        case 'script':
          result = await this.executeScript(job, context, sandbox);
          break;
        case 'file':
          result = await this.executeFileOperation(job, context, sandbox);
          break;
        case 'api':
          result = await this.executeApiCall(job, context);
          break;
        case 'database':
          result = await this.executeDatabaseQuery(job, context);
          break;
        default:
          result = this.createFailureResult(job.id, `Unsupported job type: ${job.type}`, [], startTime);
      }

      // Cleanup
      await sandboxManager.destroySandbox(sandbox.id);
      this.activeJobs.delete(job.id);
      this.jobHistory.set(job.id, result);
      
      this.emit('job:completed', { jobId: job.id, result });
      return result;

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      const result = this.createFailureResult(job.id, errorMessage, [], startTime);
      
      this.activeJobs.delete(job.id);
      this.jobHistory.set(job.id, result);
      this.emit('job:failed', { jobId: job.id, error: errorMessage });
      
      return result;
    }
  }

  private createExecutionContext(job: BrunoJob): BrunoExecutionContext {
    const sandboxId = `${job.id}-${Date.now()}`;
    
    return {
      jobId: job.id,
      sandboxId,
      startTime: new Date(),
      environment: {
        ...this.getBaseEnvironment(),
        ...job.environment,
        BRUNO_JOB_ID: job.id,
        BRUNO_SANDBOX_ID: sandboxId
      },
      permissions: new Set(job.permissions),
      workingDirectory: job.workingDirectory || '/workspace',
      limits: {
        cpu: 50, // 50% of one CPU
        memory: 512, // 512MB
        disk: 1024, // 1GB
        network: job.permissions.includes('network'),
        timeout: job.timeout || 300000 // 5 minutes default
      }
    };
  }

  private getBaseEnvironment(): Record<string, string> {
    return {
      NODE_ENV: 'production',
      PATH: '/usr/local/bin:/usr/bin:/bin',
      HOME: '/workspace',
      USER: 'bruno',
      SHELL: '/bin/sh',
      // Security headers
      BRUNO_SECURITY: 'enforced',
      BRUNO_SANDBOX: 'active'
    };
  }

  private async executeShellCommand(job: BrunoJob, context: BrunoExecutionContext, sandbox: any): Promise<BrunoResult> {
    if (!job.command) {
      return this.createFailureResult(job.id, 'No command specified', [], Date.now());
    }

    // Validate command against policies
    if (!this.isCommandAllowed(job.command)) {
      return this.createFailureResult(
        job.id, 
        'Command not allowed by security policy', 
        [{
          timestamp: new Date(),
          type: 'permission_denied',
          severity: 'high',
          details: `Blocked command: ${job.command}`,
          action: 'blocked'
        }], 
        Date.now()
      );
    }

    return new Promise((resolve) => {
      const timeout = setTimeout(() => {
        if (sandbox.process) {
          sandbox.process.kill('SIGTERM');
        }
        resolve(this.createTimeoutResult(job.id, context.limits.timeout, Date.now()));
      }, context.limits.timeout);

      let stdout = '';
      let stderr = '';
      let processExited = false;

      const handleOutput = (isDocker: boolean) => {
        if (isDocker && sandbox.process) {
          // For Docker, we need to execute the command inside the container
          sandbox.process.stdin?.write(`${job.command}\nexit\n`);
          
          sandbox.process.stdout?.on('data', (data: Buffer) => {
            stdout += data.toString();
          });

          sandbox.process.stderr?.on('data', (data: Buffer) => {
            stderr += data.toString();
          });

          sandbox.process.on('exit', (code) => {
            if (!processExited) {
              processExited = true;
              clearTimeout(timeout);
              resolve(this.createSuccessResult(job.id, code || 0, stdout, stderr, Date.now()));
            }
          });
        } else {
          // For process isolation, spawn the command directly
          const child = spawn('sh', ['-c', job.command], {
            cwd: sandbox.workDir,
            env: context.environment,
            stdio: 'pipe'
          });

          child.stdout.on('data', (data: Buffer) => {
            stdout += data.toString();
          });

          child.stderr.on('data', (data: Buffer) => {
            stderr += data.toString();
          });

          child.on('exit', (code) => {
            if (!processExited) {
              processExited = true;
              clearTimeout(timeout);
              resolve(this.createSuccessResult(job.id, code || 0, stdout, stderr, Date.now()));
            }
          });

          // Store process reference for cleanup
          sandbox.process = child;
        }
      };

      handleOutput(sandbox.config.type === 'docker');
    });
  }

  private async executeScript(job: BrunoJob, context: BrunoExecutionContext, sandbox: any): Promise<BrunoResult> {
    if (!job.script) {
      return this.createFailureResult(job.id, 'No script specified', [], Date.now());
    }

    // Create script file in sandbox
    const scriptHash = createHash('sha256').update(job.script).digest('hex').substring(0, 8);
    const scriptPath = join(sandbox.workDir, `script-${scriptHash}.js`);
    
    try {
      writeFileSync(scriptPath, job.script);
      
      // Execute script using Node.js
      const nodeJob: BrunoJob = {
        ...job,
        type: 'shell',
        command: `node ${scriptPath}`
      };
      
      return await this.executeShellCommand(nodeJob, context, sandbox);
    } catch (error) {
      return this.createFailureResult(
        job.id, 
        `Script execution failed: ${error}`, 
        [], 
        Date.now()
      );
    }
  }

  private async executeFileOperation(job: BrunoJob, context: BrunoExecutionContext, sandbox: any): Promise<BrunoResult> {
    // File operations are restricted to sandbox workspace
    const operation = job.payload?.operation;
    const path = job.payload?.path;
    const content = job.payload?.content;

    if (!operation || !path) {
      return this.createFailureResult(job.id, 'Invalid file operation parameters', [], Date.now());
    }

    // Ensure path is within sandbox
    const safePath = join(sandbox.workDir, path.replace(/^\/+/, ''));
    if (!safePath.startsWith(sandbox.workDir)) {
      return this.createFailureResult(job.id, 'Path traversal attempt blocked', [], Date.now());
    }

    try {
      let output: any;
      
      switch (operation) {
        case 'read':
          if (!context.permissions.has('file:read')) {
            throw new Error('Permission denied: file:read');
          }
          output = readFileSync(safePath, 'utf-8');
          break;
          
        case 'write':
          if (!context.permissions.has('file:write')) {
            throw new Error('Permission denied: file:write');
          }
          writeFileSync(safePath, content || '');
          output = { success: true, path: path };
          break;
          
        case 'exists':
          output = existsSync(safePath);
          break;
          
        default:
          throw new Error(`Unsupported file operation: ${operation}`);
      }

      return this.createSuccessResult(job.id, 0, JSON.stringify(output), '', Date.now());
    } catch (error) {
      return this.createFailureResult(job.id, error instanceof Error ? error.message : 'File operation failed', [], Date.now());
    }
  }

  private async executeApiCall(job: BrunoJob, context: BrunoExecutionContext): Promise<BrunoResult> {
    // API calls are restricted by network policies
    if (!context.permissions.has('network')) {
      return this.createFailureResult(job.id, 'Network access denied', [], Date.now());
    }

    // This would integrate with fetch or axios with proper restrictions
    return this.createFailureResult(job.id, 'API execution not yet implemented', [], Date.now());
  }

  private async executeDatabaseQuery(job: BrunoJob, context: BrunoExecutionContext): Promise<BrunoResult> {
    // Database queries go through Supabase MCP
    if (!context.permissions.has('database:read') && !context.permissions.has('database:write')) {
      return this.createFailureResult(job.id, 'Database access denied', [], Date.now());
    }

    // This would integrate with Supabase client
    return this.createFailureResult(job.id, 'Database execution not yet implemented', [], Date.now());
  }

  private isCommandAllowed(command: string): boolean {
    // Basic command validation (enhance with more sophisticated checks)
    const dangerousPatterns = [
      /rm\s+-rf\s+\//,
      /:\(\)\{.*\|.*&\s*\};:/,  // Fork bomb
      /dd\s+if=\/dev\/zero/,
      /chmod\s+777\s+\//,
      /sudo\s+/,
      /su\s+-/
    ];

    return !dangerousPatterns.some(pattern => pattern.test(command));
  }

  private createSuccessResult(jobId: string, exitCode: number, stdout: string, stderr: string, startTime: number): BrunoResult {
    return {
      jobId,
      status: 'success',
      exitCode,
      stdout,
      stderr,
      duration: Date.now() - startTime,
      securityEvents: this.policyEngine.getSecurityEvents(10)
    };
  }

  private createFailureResult(jobId: string, error: string, securityEvents: SecurityEvent[], startTime: number): BrunoResult {
    return {
      jobId,
      status: 'failure',
      error,
      duration: Date.now() - startTime,
      securityEvents: [...securityEvents, ...this.policyEngine.getSecurityEvents(10)]
    };
  }

  private createTimeoutResult(jobId: string, timeout: number, startTime: number): BrunoResult {
    return {
      jobId,
      status: 'timeout',
      error: `Job exceeded timeout of ${timeout}ms`,
      duration: Date.now() - startTime,
      securityEvents: this.policyEngine.getSecurityEvents(10)
    };
  }

  // Public API
  
  getActiveJobs(): BrunoExecutionContext[] {
    return Array.from(this.activeJobs.values());
  }

  getJobHistory(jobId?: string): BrunoResult | BrunoResult[] | undefined {
    if (jobId) {
      return this.jobHistory.get(jobId);
    }
    return Array.from(this.jobHistory.values());
  }

  clearJobHistory(): void {
    this.jobHistory.clear();
  }

  getSecurityEvents(limit?: number): SecurityEvent[] {
    return this.policyEngine.getSecurityEvents(limit);
  }

  setMaxConcurrentJobs(max: number): void {
    this.maxConcurrentJobs = max;
  }
}

// Export singleton instance
export const brunoExecutor = new BrunoExecutor();