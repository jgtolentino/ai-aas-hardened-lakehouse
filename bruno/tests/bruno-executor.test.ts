import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';
import { BrunoExecutor } from '../executor/bruno-executor';
import { PolicyEngine } from '../security/policy-engine';
import { sandboxManager } from '../sandbox/sandbox-manager';
import type { BrunoJob } from '../executor/types';

// Mock sandbox manager
jest.mock('../sandbox/sandbox-manager', () => ({
  sandboxManager: {
    createSandbox: jest.fn(),
    destroySandbox: jest.fn(),
    destroyAllSandboxes: jest.fn()
  }
}));

describe('Bruno Executor', () => {
  let executor: BrunoExecutor;
  let mockSandbox: any;

  beforeEach(() => {
    executor = new BrunoExecutor();
    
    // Mock sandbox
    mockSandbox = {
      id: 'test-sandbox',
      config: { type: 'process' },
      workDir: '/tmp/test-sandbox',
      cleanup: jest.fn()
    };
    
    (sandboxManager.createSandbox as jest.Mock).mockResolvedValue(mockSandbox);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('Job Execution', () => {
    it('should execute a simple shell command', async () => {
      const job: BrunoJob = {
        id: 'test-1',
        type: 'shell',
        command: 'echo "Hello Bruno"',
        permissions: ['process:execute']
      };

      const result = await executor.execute(job);
      
      expect(result.status).toBe('success');
      expect(result.jobId).toBe('test-1');
      expect(sandboxManager.createSandbox).toHaveBeenCalled();
      expect(sandboxManager.destroySandbox).toHaveBeenCalledWith(mockSandbox.id);
    });

    it('should block dangerous commands', async () => {
      const job: BrunoJob = {
        id: 'test-2',
        type: 'shell',
        command: 'rm -rf /',
        permissions: ['process:execute']
      };

      const result = await executor.execute(job);
      
      expect(result.status).toBe('failure');
      expect(result.error).toContain('not allowed by security policy');
    });

    it('should enforce timeout', async () => {
      const job: BrunoJob = {
        id: 'test-3',
        type: 'shell',
        command: 'sleep 10',
        permissions: ['process:execute'],
        timeout: 100 // 100ms timeout
      };

      const result = await executor.execute(job);
      
      expect(result.status).toBe('timeout');
      expect(result.error).toContain('exceeded timeout');
    });

    it('should execute scripts', async () => {
      const job: BrunoJob = {
        id: 'test-4',
        type: 'script',
        script: 'console.log("Script executed"); console.log(JSON.stringify({result: "success"}));',
        permissions: ['process:execute']
      };

      const result = await executor.execute(job);
      
      expect(result.status).toBe('success');
    });
  });

  describe('Security Policies', () => {
    it('should deny job without required permissions', async () => {
      const job: BrunoJob = {
        id: 'test-5',
        type: 'file',
        permissions: [], // No permissions
        payload: {
          operation: 'write',
          path: 'test.txt',
          content: 'data'
        }
      };

      const result = await executor.execute(job);
      
      expect(result.status).toBe('failure');
      expect(result.error).toContain('Security policy violation');
    });

    it('should allow job with correct permissions', async () => {
      const job: BrunoJob = {
        id: 'test-6',
        type: 'file',
        permissions: ['file:write'],
        payload: {
          operation: 'write',
          path: 'test.txt',
          content: 'data'
        }
      };

      const result = await executor.execute(job);
      
      expect(result.status).toBe('success');
    });

    it('should detect and log security events', async () => {
      const job: BrunoJob = {
        id: 'test-7',
        type: 'shell',
        command: 'sudo apt-get update',
        permissions: ['process:execute']
      };

      const result = await executor.execute(job);
      
      expect(result.status).toBe('failure');
      expect(result.securityEvents).toBeDefined();
      expect(result.securityEvents?.length).toBeGreaterThan(0);
    });
  });

  describe('File Operations', () => {
    it('should prevent path traversal', async () => {
      const job: BrunoJob = {
        id: 'test-8',
        type: 'file',
        permissions: ['file:read'],
        payload: {
          operation: 'read',
          path: '../../../etc/passwd'
        }
      };

      const result = await executor.execute(job);
      
      expect(result.status).toBe('failure');
      expect(result.error).toContain('Path traversal attempt blocked');
    });

    it('should allow safe file operations', async () => {
      const job: BrunoJob = {
        id: 'test-9',
        type: 'file',
        permissions: ['file:write'],
        payload: {
          operation: 'write',
          path: 'safe-file.txt',
          content: 'Safe content'
        }
      };

      const result = await executor.execute(job);
      
      expect(result.status).toBe('success');
    });
  });

  describe('Resource Management', () => {
    it('should respect concurrent job limits', async () => {
      executor.setMaxConcurrentJobs(2);
      
      const jobs = Array.from({ length: 3 }, (_, i) => ({
        id: `concurrent-${i}`,
        type: 'shell' as const,
        command: 'sleep 1',
        permissions: ['process:execute']
      }));

      const results = await Promise.all(jobs.map(job => executor.execute(job)));
      
      expect(results.filter(r => r.status === 'failure' && r.error?.includes('Too many concurrent jobs')).length).toBe(1);
    });

    it('should track active jobs', async () => {
      const job: BrunoJob = {
        id: 'test-10',
        type: 'shell',
        command: 'echo "test"',
        permissions: ['process:execute']
      };

      const promise = executor.execute(job);
      
      // Check active jobs during execution
      const activeJobs = executor.getActiveJobs();
      expect(activeJobs.length).toBeGreaterThan(0);
      
      await promise;
      
      // Check active jobs after completion
      const activeJobsAfter = executor.getActiveJobs();
      expect(activeJobsAfter.length).toBe(0);
    });
  });

  describe('Job History', () => {
    it('should maintain job history', async () => {
      const job: BrunoJob = {
        id: 'history-test',
        type: 'shell',
        command: 'echo "history"',
        permissions: ['process:execute']
      };

      await executor.execute(job);
      
      const history = executor.getJobHistory('history-test');
      expect(history).toBeDefined();
      expect(history?.jobId).toBe('history-test');
    });

    it('should clear job history', async () => {
      const job: BrunoJob = {
        id: 'clear-test',
        type: 'shell',
        command: 'echo "clear"',
        permissions: ['process:execute']
      };

      await executor.execute(job);
      executor.clearJobHistory();
      
      const history = executor.getJobHistory('clear-test');
      expect(history).toBeUndefined();
    });
  });
});