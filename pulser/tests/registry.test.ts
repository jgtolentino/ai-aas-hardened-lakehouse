import { describe, it, expect, beforeEach } from '@jest/globals';
import { PulserAgentRegistry } from '../registry/agent-registry';
import type { AgentConfig } from '../registry/agent-schema';

describe('Pulser Agent Registry', () => {
  let registry: PulserAgentRegistry;
  
  const mockAgentConfig: AgentConfig = {
    metadata: {
      id: 'test-agent-1',
      name: 'TestAgent',
      version: '1.0.0',
      description: 'Test agent for unit tests',
      tags: ['test', 'mock'],
      status: 'active',
      createdAt: new Date(),
      updatedAt: new Date()
    },
    type: 'executor',
    runtime: 'bruno',
    capabilities: [
      {
        name: 'test_capability',
        description: 'Test capability',
        permissions: ['file:read']
      }
    ],
    security: {
      sandboxed: true,
      allowedHosts: [],
      deniedActions: [],
      requiredPermissions: ['file:read']
    }
  };

  beforeEach(() => {
    registry = new PulserAgentRegistry({ autoSave: false });
  });

  describe('Agent Registration', () => {
    it('should register a valid agent', async () => {
      await registry.register(mockAgentConfig);
      const agent = registry.get('test-agent-1');
      
      expect(agent).toBeDefined();
      expect(agent?.config.metadata.name).toBe('TestAgent');
      expect(agent?.state).toBe('idle');
    });

    it('should reject duplicate agent IDs', async () => {
      await registry.register(mockAgentConfig);
      await expect(registry.register(mockAgentConfig)).rejects.toThrow('already registered');
    });

    it('should validate required fields', async () => {
      const invalidConfig = { ...mockAgentConfig };
      delete (invalidConfig as any).metadata.id;
      
      await expect(registry.register(invalidConfig)).rejects.toThrow();
    });

    it('should validate agent type', async () => {
      const invalidConfig = { ...mockAgentConfig, type: 'invalid' as any };
      await expect(registry.register(invalidConfig)).rejects.toThrow('Invalid agent type');
    });
  });

  describe('Agent Queries', () => {
    beforeEach(async () => {
      await registry.register(mockAgentConfig);
      await registry.register({
        ...mockAgentConfig,
        metadata: { ...mockAgentConfig.metadata, id: 'test-agent-2', name: 'TestAgent2' }
      });
    });

    it('should get agent by ID', () => {
      const agent = registry.get('test-agent-1');
      expect(agent?.config.metadata.id).toBe('test-agent-1');
    });

    it('should list all agents', () => {
      const agents = registry.list();
      expect(agents).toHaveLength(2);
    });

    it('should filter agents by status', () => {
      const agents = registry.list({ status: 'active' });
      expect(agents).toHaveLength(2);
      
      const inactiveAgents = registry.list({ status: 'inactive' });
      expect(inactiveAgents).toHaveLength(0);
    });

    it('should filter agents by tags', () => {
      const agents = registry.list({ tags: ['test'] } as any);
      expect(agents).toHaveLength(2);
    });
  });

  describe('Agent Updates', () => {
    beforeEach(async () => {
      await registry.register(mockAgentConfig);
    });

    it('should update agent configuration', async () => {
      await registry.update('test-agent-1', {
        metadata: { description: 'Updated description' }
      });
      
      const agent = registry.get('test-agent-1');
      expect(agent?.config.metadata.description).toBe('Updated description');
    });

    it('should update timestamps on modification', async () => {
      const originalTime = registry.get('test-agent-1')?.config.metadata.updatedAt;
      
      await new Promise(resolve => setTimeout(resolve, 10));
      
      await registry.update('test-agent-1', {
        metadata: { tags: ['updated'] }
      });
      
      const agent = registry.get('test-agent-1');
      expect(agent?.config.metadata.updatedAt.getTime()).toBeGreaterThan(originalTime!.getTime());
    });
  });

  describe('Agent Metrics', () => {
    beforeEach(async () => {
      await registry.register(mockAgentConfig);
    });

    it('should record successful execution', () => {
      registry.recordExecution('test-agent-1', true, 1000);
      
      const metrics = registry.getAgentMetrics('test-agent-1');
      expect(metrics?.totalExecutions).toBe(1);
      expect(metrics?.successRate).toBe(100);
      expect(metrics?.averageExecutionTime).toBe(1000);
      expect(metrics?.errorCount).toBe(0);
    });

    it('should record failed execution', () => {
      registry.recordExecution('test-agent-1', false, 500);
      
      const metrics = registry.getAgentMetrics('test-agent-1');
      expect(metrics?.totalExecutions).toBe(1);
      expect(metrics?.successRate).toBe(0);
      expect(metrics?.errorCount).toBe(1);
    });

    it('should calculate average execution time', () => {
      registry.recordExecution('test-agent-1', true, 1000);
      registry.recordExecution('test-agent-1', true, 2000);
      registry.recordExecution('test-agent-1', true, 3000);
      
      const metrics = registry.getAgentMetrics('test-agent-1');
      expect(metrics?.averageExecutionTime).toBe(2000);
    });
  });

  describe('Agent State Management', () => {
    beforeEach(async () => {
      await registry.register(mockAgentConfig);
    });

    it('should update agent state', () => {
      registry.updateAgentState('test-agent-1', 'busy');
      const agent = registry.get('test-agent-1');
      expect(agent?.state).toBe('busy');
    });

    it('should prevent unregistering busy agents', async () => {
      registry.updateAgentState('test-agent-1', 'busy');
      await expect(registry.unregister('test-agent-1')).rejects.toThrow('while it\'s busy');
    });
  });

  describe('Health Checks', () => {
    beforeEach(async () => {
      await registry.register(mockAgentConfig);
    });

    it('should perform health check on healthy agent', async () => {
      const isHealthy = await registry.healthCheck('test-agent-1');
      expect(isHealthy).toBe(true);
      
      const agent = registry.get('test-agent-1');
      expect(agent?.healthCheck?.status).toBe('healthy');
    });

    it('should detect unhealthy agent', async () => {
      registry.updateAgentState('test-agent-1', 'error');
      
      const isHealthy = await registry.healthCheck('test-agent-1');
      expect(isHealthy).toBe(false);
      
      const agent = registry.get('test-agent-1');
      expect(agent?.healthCheck?.status).toBe('unhealthy');
    });
  });
});