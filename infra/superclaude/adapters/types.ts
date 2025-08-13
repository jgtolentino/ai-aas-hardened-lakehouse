export interface ExecIntent {
  kind: 'execute_via_bruno' | 'route_to_agent' | 'mcp_operation';
  job?: string;
  agent?: string;
  args: Record<string, any>;
  metadata?: {
    requestId?: string;
    timestamp?: string;
    source?: string;
  };
}

export interface SuperClaudeEvent {
  persona: string;
  task: string;
  payload: any;
  context?: {
    projectRef?: string;
    feature?: string;
    workspace?: string;
  };
}

export interface PersonaMapping {
  persona: string;
  agent: string;
  capabilities: string[];
  restrictions?: string[];
}

export interface AdapterConfig {
  personaMappings: PersonaMapping[];
  defaultAgent: string;
  brunoEndpoint?: string;
  securityMode: 'strict' | 'permissive';
}