import { describe, it, expect, beforeAll } from '@jest/globals';
import { handleSCCommand } from '../adapters/sc_to_pulser';
import { enforceBrunoOnly, validateExecIntent } from '../guards/exec_guard';
import type { SuperClaudeEvent, ExecIntent } from '../adapters/types';

describe('SuperClaude Integration Tests', () => {
  describe('Adapter Tests', () => {
    it('should route System Architect to PRD generation', async () => {
      const event: SuperClaudeEvent = {
        persona: 'System Architect',
        task: 'Create PRD',
        payload: { title: 'Test Feature', requirements: ['req1', 'req2'] },
        context: { feature: 'test-feature' }
      };

      const result = await handleSCCommand(event);
      
      expect(result.kind).toBe('execute_via_bruno');
      expect(result.job).toBe('pulser:generate_prd');
      expect(result.args.out).toBe('PRD-test-feature.md');
    });

    it('should route Frontend Developer to TSX generation', async () => {
      const event: SuperClaudeEvent = {
        persona: 'Frontend Developer',
        task: 'Create component',
        payload: { 
          module: 'Dashboard',
          components: ['Chart', 'Table']
        }
      };

      const result = await handleSCCommand(event);
      
      expect(result.kind).toBe('execute_via_bruno');
      expect(result.job).toBe('dash:codegen_tsx');
      expect(result.args.components).toEqual(['Chart', 'Table']);
    });

    it('should route Security Engineer to scanning', async () => {
      const event: SuperClaudeEvent = {
        persona: 'Security Engineer',
        task: 'Scan repository',
        payload: {}
      };

      const result = await handleSCCommand(event);
      
      expect(result.kind).toBe('execute_via_bruno');
      expect(result.job).toBe('sec:scan_repo');
      expect(result.args.tools).toContain('semgrep');
      expect(result.args.tools).toContain('trivy');
    });

    it('should route Scribe to Maya agent', async () => {
      const event: SuperClaudeEvent = {
        persona: 'Scribe',
        task: 'Document API',
        payload: { api: 'user-service', version: 'v2' }
      };

      const result = await handleSCCommand(event);
      
      expect(result.kind).toBe('route_to_agent');
      expect(result.agent).toBe('maya');
      expect(result.args.format).toBe('mdx');
    });

    it('should reject unknown personas', async () => {
      const event: SuperClaudeEvent = {
        persona: 'Unknown Person',
        task: 'Do something',
        payload: {}
      };

      await expect(handleSCCommand(event)).rejects.toThrow('Unknown persona');
    });

    it('should add metadata to all intents', async () => {
      const event: SuperClaudeEvent = {
        persona: 'System Architect',
        task: 'Test',
        payload: {}
      };

      const result = await handleSCCommand(event);
      
      expect(result.metadata).toBeDefined();
      expect(result.metadata?.requestId).toMatch(/^[0-9a-f-]+$/);
      expect(result.metadata?.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/);
      expect(result.metadata?.source).toBe('superclaude:System Architect');
    });
  });

  describe('Security Guard Tests', () => {
    it('should block non-Bruno execution', () => {
      const intent: ExecIntent = {
        kind: 'execute_via_bruno' as any,
        args: {}
      };
      
      // Change to invalid kind
      (intent as any).kind = 'direct_exec';
      
      expect(() => enforceBrunoOnly(intent)).toThrow('[SECURITY] Direct execution blocked');
    });

    it('should pass Bruno execution', () => {
      const intent: ExecIntent = {
        kind: 'execute_via_bruno',
        job: 'test:job',
        args: {}
      };
      
      expect(() => enforceBrunoOnly(intent)).not.toThrow();
    });

    it('should detect sensitive data in payload', () => {
      const intent: ExecIntent = {
        kind: 'execute_via_bruno',
        job: 'test:job',
        args: {
          api_key: 'secret123',
          data: 'normal'
        }
      };
      
      expect(() => validateExecIntent(intent)).toThrow('[SECURITY] Potential sensitive data');
    });

    it('should allow clean payloads', () => {
      const intent: ExecIntent = {
        kind: 'execute_via_bruno',
        job: 'test:job',
        args: {
          name: 'test',
          count: 42,
          enabled: true
        }
      };
      
      expect(() => validateExecIntent(intent)).not.toThrow();
    });
  });
});