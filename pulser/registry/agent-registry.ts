import { EventEmitter } from 'events';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import type { AgentConfig, AgentInstance, AgentRegistry } from './agent-schema';

export class PulserAgentRegistry extends EventEmitter implements AgentRegistry {
  private agents: Map<string, AgentInstance> = new Map();
  private registryPath: string;
  private autoSave: boolean;

  constructor(options?: { registryPath?: string; autoSave?: boolean }) {
    super();
    this.registryPath = options?.registryPath || join(process.cwd(), 'pulser/registry/data');
    this.autoSave = options?.autoSave ?? true;
    this.loadRegistry();
  }

  async register(config: AgentConfig): Promise<void> {
    const agentId = config.metadata.id;

    // Validate configuration
    this.validateConfig(config);

    // Check if agent already exists
    if (this.agents.has(agentId)) {
      throw new Error(`Agent ${agentId} is already registered`);
    }

    // Create agent instance
    const instance: AgentInstance = {
      config,
      state: 'idle',
      metrics: {
        totalExecutions: 0,
        successRate: 0,
        averageExecutionTime: 0,
        errorCount: 0
      },
      healthCheck: {
        lastCheck: new Date(),
        status: 'unknown'
      }
    };

    // Register agent
    this.agents.set(agentId, instance);
    this.emit('agent:registered', { agentId, config });

    // Save registry
    if (this.autoSave) {
      await this.saveRegistry();
    }

    console.log(`[Pulser] Agent registered: ${config.metadata.name} v${config.metadata.version}`);
  }

  async unregister(agentId: string): Promise<void> {
    if (!this.agents.has(agentId)) {
      throw new Error(`Agent ${agentId} not found`);
    }

    const instance = this.agents.get(agentId)!;
    
    // Check if agent is busy
    if (instance.state === 'busy') {
      throw new Error(`Cannot unregister agent ${agentId} while it's busy`);
    }

    // Remove agent
    this.agents.delete(agentId);
    this.emit('agent:unregistered', { agentId });

    // Save registry
    if (this.autoSave) {
      await this.saveRegistry();
    }

    console.log(`[Pulser] Agent unregistered: ${agentId}`);
  }

  get(agentId: string): AgentInstance | undefined {
    return this.agents.get(agentId);
  }

  list(filter?: Partial<AgentConfig['metadata']>): AgentInstance[] {
    let instances = Array.from(this.agents.values());

    if (filter) {
      instances = instances.filter(instance => {
        const metadata = instance.config.metadata;
        return Object.entries(filter).every(([key, value]) => {
          if (key === 'tags' && Array.isArray(value)) {
            return value.some(tag => metadata.tags.includes(tag));
          }
          return metadata[key as keyof typeof metadata] === value;
        });
      });
    }

    return instances;
  }

  async update(agentId: string, updates: Partial<AgentConfig>): Promise<void> {
    const instance = this.agents.get(agentId);
    if (!instance) {
      throw new Error(`Agent ${agentId} not found`);
    }

    // Merge updates
    instance.config = {
      ...instance.config,
      ...updates,
      metadata: {
        ...instance.config.metadata,
        ...updates.metadata,
        updatedAt: new Date()
      }
    };

    // Validate updated config
    this.validateConfig(instance.config);

    this.emit('agent:updated', { agentId, updates });

    // Save registry
    if (this.autoSave) {
      await this.saveRegistry();
    }
  }

  async healthCheck(agentId: string): Promise<boolean> {
    const instance = this.agents.get(agentId);
    if (!instance) {
      throw new Error(`Agent ${agentId} not found`);
    }

    try {
      // Perform basic health check
      const isHealthy = instance.state !== 'error' && instance.state !== 'offline';
      
      // Update health status
      instance.healthCheck = {
        lastCheck: new Date(),
        status: isHealthy ? 'healthy' : 'unhealthy',
        details: isHealthy ? 'Agent is responsive' : 'Agent is not responding'
      };

      this.emit('agent:health-checked', { agentId, healthy: isHealthy });
      return isHealthy;
    } catch (error) {
      instance.healthCheck = {
        lastCheck: new Date(),
        status: 'unhealthy',
        details: error instanceof Error ? error.message : 'Unknown error'
      };
      return false;
    }
  }

  private validateConfig(config: AgentConfig): void {
    // Validate required fields
    if (!config.metadata.id || !config.metadata.name || !config.metadata.version) {
      throw new Error('Agent metadata must include id, name, and version');
    }

    // Validate agent type
    const validTypes = ['executor', 'transformer', 'analyzer', 'generator', 'validator'];
    if (!validTypes.includes(config.type)) {
      throw new Error(`Invalid agent type: ${config.type}`);
    }

    // Validate runtime
    const validRuntimes = ['node', 'python', 'deno', 'bruno'];
    if (!validRuntimes.includes(config.runtime)) {
      throw new Error(`Invalid runtime: ${config.runtime}`);
    }

    // Validate capabilities
    if (!config.capabilities || config.capabilities.length === 0) {
      throw new Error('Agent must have at least one capability');
    }

    // Validate security settings
    if (!config.security || typeof config.security.sandboxed !== 'boolean') {
      throw new Error('Agent must have security configuration with sandboxed flag');
    }
  }

  private loadRegistry(): void {
    const registryFile = join(this.registryPath, 'registry.json');
    
    if (existsSync(registryFile)) {
      try {
        const data = JSON.parse(readFileSync(registryFile, 'utf-8'));
        
        // Restore agents with proper date objects
        data.agents.forEach((agentData: any) => {
          agentData.config.metadata.createdAt = new Date(agentData.config.metadata.createdAt);
          agentData.config.metadata.updatedAt = new Date(agentData.config.metadata.updatedAt);
          if (agentData.metrics.lastExecutionTime) {
            agentData.metrics.lastExecutionTime = new Date(agentData.metrics.lastExecutionTime);
          }
          if (agentData.healthCheck) {
            agentData.healthCheck.lastCheck = new Date(agentData.healthCheck.lastCheck);
          }
          this.agents.set(agentData.config.metadata.id, agentData);
        });
        
        console.log(`[Pulser] Loaded ${this.agents.size} agents from registry`);
      } catch (error) {
        console.error('[Pulser] Failed to load registry:', error);
      }
    }
  }

  private async saveRegistry(): Promise<void> {
    const registryFile = join(this.registryPath, 'registry.json');
    
    // Ensure directory exists
    if (!existsSync(this.registryPath)) {
      mkdirSync(this.registryPath, { recursive: true });
    }

    // Convert Map to array for JSON serialization
    const data = {
      version: '1.0',
      timestamp: new Date().toISOString(),
      agents: Array.from(this.agents.values())
    };

    try {
      writeFileSync(registryFile, JSON.stringify(data, null, 2));
    } catch (error) {
      console.error('[Pulser] Failed to save registry:', error);
      throw error;
    }
  }

  // Utility methods
  
  getAgentsByType(type: AgentConfig['type']): AgentInstance[] {
    return this.list({ type } as any);
  }

  getAgentsByRuntime(runtime: AgentConfig['runtime']): AgentInstance[] {
    return this.list({ runtime } as any);
  }

  getActiveAgents(): AgentInstance[] {
    return this.list({ status: 'active' });
  }

  getAgentMetrics(agentId: string): AgentInstance['metrics'] | undefined {
    return this.agents.get(agentId)?.metrics;
  }

  updateAgentState(agentId: string, state: AgentInstance['state']): void {
    const instance = this.agents.get(agentId);
    if (instance) {
      instance.state = state;
      this.emit('agent:state-changed', { agentId, state });
    }
  }

  recordExecution(agentId: string, success: boolean, executionTime: number): void {
    const instance = this.agents.get(agentId);
    if (instance) {
      const metrics = instance.metrics;
      metrics.totalExecutions++;
      metrics.lastExecutionTime = new Date();
      
      if (!success) {
        metrics.errorCount++;
      }
      
      // Update success rate
      metrics.successRate = ((metrics.totalExecutions - metrics.errorCount) / metrics.totalExecutions) * 100;
      
      // Update average execution time
      metrics.averageExecutionTime = 
        (metrics.averageExecutionTime * (metrics.totalExecutions - 1) + executionTime) / metrics.totalExecutions;
      
      this.emit('agent:execution-recorded', { agentId, success, executionTime });
    }
  }
}

// Export singleton instance
export const agentRegistry = new PulserAgentRegistry();