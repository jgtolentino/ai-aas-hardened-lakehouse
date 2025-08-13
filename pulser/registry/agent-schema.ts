export interface AgentCapability {
  name: string;
  description: string;
  inputSchema?: Record<string, any>;
  outputSchema?: Record<string, any>;
  permissions: string[];
}

export interface AgentMetadata {
  id: string;
  name: string;
  version: string;
  description: string;
  author?: string;
  tags: string[];
  status: 'active' | 'inactive' | 'deprecated' | 'testing';
  createdAt: Date;
  updatedAt: Date;
}

export interface AgentConfig {
  metadata: AgentMetadata;
  type: 'executor' | 'transformer' | 'analyzer' | 'generator' | 'validator';
  runtime: 'node' | 'python' | 'deno' | 'bruno';
  capabilities: AgentCapability[];
  dependencies?: string[];
  environment?: Record<string, string>;
  limits?: {
    maxExecutionTime?: number;
    maxMemoryMB?: number;
    maxConcurrent?: number;
  };
  security: {
    allowedHosts?: string[];
    deniedActions?: string[];
    requiredPermissions?: string[];
    sandboxed: boolean;
  };
  routing?: {
    priority: number;
    patterns: string[];
    conditions?: Record<string, any>;
  };
}

export interface AgentInstance {
  config: AgentConfig;
  state: 'idle' | 'busy' | 'error' | 'offline';
  metrics: {
    totalExecutions: number;
    successRate: number;
    averageExecutionTime: number;
    lastExecutionTime?: Date;
    errorCount: number;
  };
  healthCheck?: {
    lastCheck: Date;
    status: 'healthy' | 'unhealthy' | 'unknown';
    details?: string;
  };
}

export interface AgentRegistry {
  agents: Map<string, AgentInstance>;
  register(config: AgentConfig): Promise<void>;
  unregister(agentId: string): Promise<void>;
  get(agentId: string): AgentInstance | undefined;
  list(filter?: Partial<AgentMetadata>): AgentInstance[];
  update(agentId: string, updates: Partial<AgentConfig>): Promise<void>;
  healthCheck(agentId: string): Promise<boolean>;
}