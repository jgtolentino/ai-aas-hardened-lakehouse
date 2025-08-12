export interface BrunoJob {
  id: string;
  type: 'shell' | 'script' | 'api' | 'database' | 'file';
  command?: string;
  script?: string;
  payload?: any;
  permissions: string[];
  environment?: Record<string, string>;
  workingDirectory?: string;
  timeout?: number;
  retryPolicy?: {
    maxRetries: number;
    backoffMs: number;
  };
  metadata?: {
    source: string;
    agentId?: string;
    requestId?: string;
    userId?: string;
  };
}

export interface BrunoExecutionContext {
  jobId: string;
  sandboxId: string;
  startTime: Date;
  environment: Record<string, string>;
  permissions: Set<string>;
  workingDirectory: string;
  limits: {
    cpu: number;
    memory: number;
    disk: number;
    network: boolean;
    timeout: number;
  };
}

export interface BrunoResult {
  jobId: string;
  status: 'success' | 'failure' | 'timeout' | 'cancelled';
  exitCode?: number;
  stdout?: string;
  stderr?: string;
  output?: any;
  error?: string;
  duration: number;
  resourceUsage?: {
    cpuTime: number;
    memoryPeak: number;
    diskIO: number;
  };
  securityEvents?: SecurityEvent[];
}

export interface SecurityEvent {
  timestamp: Date;
  type: 'permission_denied' | 'resource_exceeded' | 'suspicious_activity' | 'policy_violation';
  severity: 'low' | 'medium' | 'high' | 'critical';
  details: string;
  action: 'blocked' | 'allowed' | 'logged';
}

export interface BrunoPolicy {
  name: string;
  description: string;
  rules: PolicyRule[];
  enforcement: 'strict' | 'permissive' | 'audit';
}

export interface PolicyRule {
  id: string;
  type: 'allow' | 'deny';
  resource: string;
  actions: string[];
  conditions?: Record<string, any>;
}

export interface SandboxConfig {
  id: string;
  type: 'docker' | 'vm' | 'process' | 'wasm';
  image?: string;
  resources: {
    cpuShares: number;
    memoryMB: number;
    diskMB: number;
    networkEnabled: boolean;
  };
  mounts?: {
    source: string;
    target: string;
    readonly: boolean;
  }[];
  environment: Record<string, string>;
  securityOptions: {
    noNewPrivileges: boolean;
    readOnlyRootFilesystem: boolean;
    allowPrivilegeEscalation: boolean;
    capabilities: {
      drop: string[];
      add: string[];
    };
  };
}