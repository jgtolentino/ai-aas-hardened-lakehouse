import { z } from 'zod';

// Figma-related schemas
export const FigmaNodeSchema = z.object({
  id: z.string(),
  name: z.string(),
  type: z.string(),
  visible: z.boolean().optional(),
  locked: z.boolean().optional(),
  children: z.array(z.lazy(() => FigmaNodeSchema)).optional(),
  fills: z.array(z.any()).optional(),
  strokes: z.array(z.any()).optional(),
  effects: z.array(z.any()).optional(),
  constraints: z.object({
    horizontal: z.string(),
    vertical: z.string(),
  }).optional(),
  absoluteBoundingBox: z.object({
    x: z.number(),
    y: z.number(),
    width: z.number(),
    height: z.number(),
  }).optional(),
});

export const FigmaSelectionSchema = z.object({
  selection: z.array(FigmaNodeSchema),
  fileKey: z.string(),
  nodeId: z.string().optional(),
  timestamp: z.number(),
});

export const ComponentGenerationSchema = z.object({
  componentName: z.string(),
  filePath: z.string(),
  props: z.record(z.string(), z.any()),
  imports: z.array(z.string()),
  codeConnectMapping: z.object({
    figmaNode: z.string(),
    component: z.string(),
    variant: z.record(z.string(), z.any()).optional(),
  }),
});

// Supabase-related schemas
export const SupabaseTableSchema = z.object({
  table_name: z.string(),
  table_schema: z.string(),
  table_type: z.enum(['BASE TABLE', 'VIEW', 'MATERIALIZED VIEW']),
  is_insertable_into: z.enum(['YES', 'NO']),
});

export const SupabaseQueryResultSchema = z.object({
  data: z.array(z.record(z.string(), z.any())).nullable(),
  error: z.object({
    message: z.string(),
    details: z.string().optional(),
    hint: z.string().optional(),
    code: z.string().optional(),
  }).nullable(),
  count: z.number().nullable(),
  status: z.number(),
  statusText: z.string(),
});

export const MigrationSchema = z.object({
  version: z.string(),
  name: z.string(),
  statements: z.array(z.string()),
  checksum: z.string().optional(),
});

// MCP tool result schemas
export const MCPToolResultSchema = z.object({
  content: z.array(z.object({
    type: z.enum(['text', 'image', 'resource']),
    text: z.string().optional(),
    data: z.string().optional(),
    mimeType: z.string().optional(),
  })),
  isError: z.boolean().optional(),
});

// Cost tracking schemas
export const CostTrackingSchema = z.object({
  operation: z.string(),
  model: z.string().optional(),
  input_tokens: z.number().optional(),
  output_tokens: z.number().optional(),
  duration_ms: z.number(),
  cost_usd: z.number().optional(),
  success: z.boolean(),
  error: z.string().optional(),
  timestamp: z.string(),
});

// Agent task schemas
export const AgentTaskSchema = z.object({
  task_id: z.string(),
  agent_name: z.string(),
  task_type: z.string(),
  inputs: z.record(z.string(), z.any()),
  outputs: z.record(z.string(), z.any()).optional(),
  status: z.enum(['pending', 'running', 'completed', 'failed']),
  created_at: z.string(),
  completed_at: z.string().optional(),
  error: z.string().optional(),
});

// Diagram generation schemas
export const DiagramRequestSchema = z.object({
  type: z.enum(['mermaid', 'plantuml', 'graphviz', 'drawio']),
  content: z.string(),
  format: z.enum(['png', 'svg', 'pdf']).default('png'),
  theme: z.string().optional(),
  width: z.number().optional(),
  height: z.number().optional(),
});

export const DiagramResponseSchema = z.object({
  url: z.string().url(),
  format: z.string(),
  width: z.number(),
  height: z.number(),
  cached: z.boolean(),
  cache_key: z.string(),
});

// Unified schemas export
export const schemas = {
  figma: {
    node: FigmaNodeSchema,
    selection: FigmaSelectionSchema,
    componentGeneration: ComponentGenerationSchema,
  },
  supabase: {
    table: SupabaseTableSchema,
    queryResult: SupabaseQueryResultSchema,
    migration: MigrationSchema,
  },
  mcp: {
    toolResult: MCPToolResultSchema,
  },
  tracking: {
    cost: CostTrackingSchema,
    agentTask: AgentTaskSchema,
  },
  diagram: {
    request: DiagramRequestSchema,
    response: DiagramResponseSchema,
  },
} as const;

export type FigmaNode = z.infer<typeof FigmaNodeSchema>;
export type FigmaSelection = z.infer<typeof FigmaSelectionSchema>;
export type ComponentGeneration = z.infer<typeof ComponentGenerationSchema>;
export type SupabaseTable = z.infer<typeof SupabaseTableSchema>;
export type SupabaseQueryResult = z.infer<typeof SupabaseQueryResultSchema>;
export type Migration = z.infer<typeof MigrationSchema>;
export type MCPToolResult = z.infer<typeof MCPToolResultSchema>;
export type CostTracking = z.infer<typeof CostTrackingSchema>;
export type AgentTask = z.infer<typeof AgentTaskSchema>;
export type DiagramRequest = z.infer<typeof DiagramRequestSchema>;
export type DiagramResponse = z.infer<typeof DiagramResponseSchema>;