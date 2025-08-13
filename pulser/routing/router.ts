import type { AgentInstance } from '../registry/agent-schema';
import { agentRegistry } from '../registry/agent-registry';

export interface RoutingRequest {
  type: 'task' | 'query' | 'command';
  category?: string;
  payload: any;
  context?: {
    source?: string;
    priority?: 'low' | 'medium' | 'high' | 'critical';
    timeout?: number;
    requiredCapabilities?: string[];
  };
}

export interface RoutingDecision {
  agentId: string;
  score: number;
  reason: string;
  alternativeAgents?: string[];
}

export interface RoutingStrategy {
  name: string;
  evaluate(request: RoutingRequest, agents: AgentInstance[]): RoutingDecision | null;
}

// Built-in routing strategies

export class CapabilityBasedStrategy implements RoutingStrategy {
  name = 'capability-based';

  evaluate(request: RoutingRequest, agents: AgentInstance[]): RoutingDecision | null {
    const requiredCapabilities = request.context?.requiredCapabilities || [];
    
    // Filter agents that have all required capabilities
    const capableAgents = agents.filter(agent => {
      const agentCapabilities = agent.config.capabilities.map(c => c.name);
      return requiredCapabilities.every(req => agentCapabilities.includes(req));
    });

    if (capableAgents.length === 0) {
      return null;
    }

    // Score agents based on capability match and metrics
    const scored = capableAgents.map(agent => {
      let score = 0;
      
      // Base score from capability count
      score += agent.config.capabilities.length * 10;
      
      // Bonus for success rate
      score += agent.metrics.successRate;
      
      // Penalty for error count
      score -= agent.metrics.errorCount * 5;
      
      // Bonus for idle state
      if (agent.state === 'idle') {
        score += 20;
      }
      
      return { agent, score };
    });

    // Sort by score and pick the best
    scored.sort((a, b) => b.score - a.score);
    const best = scored[0];

    return {
      agentId: best.agent.config.metadata.id,
      score: best.score,
      reason: `Best match for capabilities: ${requiredCapabilities.join(', ')}`,
      alternativeAgents: scored.slice(1, 4).map(s => s.agent.config.metadata.id)
    };
  }
}

export class LoadBalancingStrategy implements RoutingStrategy {
  name = 'load-balancing';

  evaluate(request: RoutingRequest, agents: AgentInstance[]): RoutingDecision | null {
    // Filter active and idle agents
    const availableAgents = agents.filter(
      agent => agent.config.metadata.status === 'active' && agent.state === 'idle'
    );

    if (availableAgents.length === 0) {
      return null;
    }

    // Find agent with lowest execution count
    let leastBusy = availableAgents[0];
    let minExecutions = leastBusy.metrics.totalExecutions;

    for (const agent of availableAgents) {
      if (agent.metrics.totalExecutions < minExecutions) {
        leastBusy = agent;
        minExecutions = agent.metrics.totalExecutions;
      }
    }

    return {
      agentId: leastBusy.config.metadata.id,
      score: 100 - minExecutions,
      reason: `Least busy agent with ${minExecutions} total executions`,
      alternativeAgents: availableAgents
        .filter(a => a !== leastBusy)
        .map(a => a.config.metadata.id)
    };
  }
}

export class TypeBasedStrategy implements RoutingStrategy {
  name = 'type-based';

  evaluate(request: RoutingRequest, agents: AgentInstance[]): RoutingDecision | null {
    // Map request types to agent types
    const typeMapping: Record<string, string[]> = {
      'task': ['executor', 'transformer'],
      'query': ['analyzer', 'validator'],
      'command': ['executor', 'generator']
    };

    const preferredTypes = typeMapping[request.type] || [];
    
    // Filter agents by type
    const matchingAgents = agents.filter(
      agent => preferredTypes.includes(agent.config.type)
    );

    if (matchingAgents.length === 0) {
      return null;
    }

    // Pick the first available
    const selected = matchingAgents.find(a => a.state === 'idle') || matchingAgents[0];

    return {
      agentId: selected.config.metadata.id,
      score: 80,
      reason: `Matched agent type ${selected.config.type} for request type ${request.type}`,
      alternativeAgents: matchingAgents
        .filter(a => a !== selected)
        .map(a => a.config.metadata.id)
    };
  }
}

export class PriorityBasedStrategy implements RoutingStrategy {
  name = 'priority-based';

  evaluate(request: RoutingRequest, agents: AgentInstance[]): RoutingDecision | null {
    const priority = request.context?.priority || 'medium';
    
    // Filter agents by routing priority
    const eligibleAgents = agents.filter(agent => {
      const agentPriority = agent.config.routing?.priority || 50;
      
      switch (priority) {
        case 'critical':
          return agentPriority >= 80;
        case 'high':
          return agentPriority >= 60;
        case 'medium':
          return agentPriority >= 40;
        case 'low':
          return true;
      }
    });

    if (eligibleAgents.length === 0) {
      return null;
    }

    // Sort by priority and pick the highest
    eligibleAgents.sort((a, b) => 
      (b.config.routing?.priority || 50) - (a.config.routing?.priority || 50)
    );

    const selected = eligibleAgents[0];

    return {
      agentId: selected.config.metadata.id,
      score: selected.config.routing?.priority || 50,
      reason: `Highest priority agent for ${priority} priority request`,
      alternativeAgents: eligibleAgents.slice(1, 4).map(a => a.config.metadata.id)
    };
  }
}

export class PulserRouter {
  private strategies: Map<string, RoutingStrategy> = new Map();
  private defaultStrategy: string = 'capability-based';

  constructor() {
    // Register built-in strategies
    this.registerStrategy(new CapabilityBasedStrategy());
    this.registerStrategy(new LoadBalancingStrategy());
    this.registerStrategy(new TypeBasedStrategy());
    this.registerStrategy(new PriorityBasedStrategy());
  }

  registerStrategy(strategy: RoutingStrategy): void {
    this.strategies.set(strategy.name, strategy);
  }

  setDefaultStrategy(name: string): void {
    if (!this.strategies.has(name)) {
      throw new Error(`Strategy ${name} not found`);
    }
    this.defaultStrategy = name;
  }

  async route(request: RoutingRequest, strategyName?: string): Promise<RoutingDecision> {
    const strategy = this.strategies.get(strategyName || this.defaultStrategy);
    if (!strategy) {
      throw new Error(`Routing strategy ${strategyName || this.defaultStrategy} not found`);
    }

    // Get all active agents
    const agents = agentRegistry.getActiveAgents();
    if (agents.length === 0) {
      throw new Error('No active agents available');
    }

    // Apply strategy
    const decision = strategy.evaluate(request, agents);
    if (!decision) {
      throw new Error('No suitable agent found for request');
    }

    // Update agent state
    agentRegistry.updateAgentState(decision.agentId, 'busy');

    // Log routing decision
    console.log(`[Router] Routed to ${decision.agentId}: ${decision.reason}`);

    return decision;
  }

  async routeWithFallback(request: RoutingRequest, strategies: string[]): Promise<RoutingDecision> {
    for (const strategyName of strategies) {
      try {
        return await this.route(request, strategyName);
      } catch (error) {
        console.warn(`[Router] Strategy ${strategyName} failed:`, error);
        continue;
      }
    }
    
    throw new Error('All routing strategies failed');
  }

  async findBestAgent(request: RoutingRequest): Promise<RoutingDecision[]> {
    const results: RoutingDecision[] = [];
    
    // Try all strategies and collect results
    for (const [name, strategy] of this.strategies) {
      const agents = agentRegistry.getActiveAgents();
      const decision = strategy.evaluate(request, agents);
      
      if (decision) {
        results.push({
          ...decision,
          reason: `[${name}] ${decision.reason}`
        });
      }
    }

    // Sort by score
    results.sort((a, b) => b.score - a.score);
    
    return results;
  }

  getStrategies(): string[] {
    return Array.from(this.strategies.keys());
  }
}

// Export singleton instance
export const router = new PulserRouter();