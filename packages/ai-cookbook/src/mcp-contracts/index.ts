import { z } from 'zod';

/**
 * Typed MCP tool contracts for TBWA platform
 * Ensures consistent tool interfaces across all agents
 */

// Supabase MCP tool contracts
export const supabaseMCPContract = {
  'mcp__supabase__execute_sql': {
    input: z.object({
      query: z.string(),
      params: z.record(z.string(), z.any()).optional(),
    }),
    output: z.object({
      data: z.array(z.record(z.string(), z.any())).nullable(),
      error: z.any().nullable(),
      count: z.number().nullable(),
    }),
  },
  
  'mcp__supabase__list_tables': {
    input: z.object({
      schema: z.string().optional(),
    }),
    output: z.array(z.object({
      table_name: z.string(),
      table_schema: z.string(),
      table_type: z.string(),
    })),
  },
  
  'mcp__supabase__apply_migration': {
    input: z.object({
      name: z.string(),
      statements: z.array(z.string()),
    }),
    output: z.object({
      success: z.boolean(),
      applied_at: z.string(),
      checksum: z.string().optional(),
    }),
  },
  
  'mcp__supabase__generate_types': {
    input: z.object({
      schemas: z.array(z.string()).optional(),
      output_file: z.string().optional(),
    }),
    output: z.object({
      types: z.string(),
      file_path: z.string().optional(),
    }),
  },
} as const;

// Figma MCP tool contracts
export const figmaMCPContract = {
  'mcp__figma__get_selection': {
    input: z.object({
      timeout: z.number().optional().default(3000),
    }),
    output: z.object({
      selection: z.array(z.object({
        id: z.string(),
        name: z.string(),
        type: z.string(),
        properties: z.record(z.string(), z.any()),
      })),
      fileKey: z.string(),
      timestamp: z.number(),
    }),
  },
  
  'mcp__figma__inspect_node': {
    input: z.object({
      nodeId: z.string(),
      fileKey: z.string(),
    }),
    output: z.object({
      node: z.object({
        id: z.string(),
        name: z.string(),
        type: z.string(),
        properties: z.record(z.string(), z.any()),
        styles: z.record(z.string(), z.any()),
        constraints: z.record(z.string(), z.any()),
      }),
      children: z.array(z.any()).optional(),
    }),
  },
  
  'mcp__figma__generate_component': {
    input: z.object({
      nodeId: z.string(),
      componentName: z.string(),
      outputPath: z.string().optional(),
      includeCodeConnect: z.boolean().optional().default(true),
    }),
    output: z.object({
      componentCode: z.string(),
      codeConnectMapping: z.string(),
      filePath: z.string(),
      props: z.record(z.string(), z.any()),
    }),
  },
} as const;

// GitHub MCP tool contracts
export const githubMCPContract = {
  'mcp__github__create_branch': {
    input: z.object({
      branch: z.string(),
      from_branch: z.string().optional().default('main'),
    }),
    output: z.object({
      name: z.string(),
      sha: z.string(),
      url: z.string(),
    }),
  },
  
  'mcp__github__create_pull_request': {
    input: z.object({
      title: z.string(),
      body: z.string(),
      head: z.string(),
      base: z.string().optional().default('main'),
      draft: z.boolean().optional().default(false),
    }),
    output: z.object({
      number: z.number(),
      url: z.string(),
      html_url: z.string(),
      state: z.string(),
    }),
  },
} as const;

// File system MCP tool contracts
export const filesystemMCPContract = {
  'Read': {
    input: z.object({
      file_path: z.string(),
      offset: z.number().optional(),
      limit: z.number().optional(),
    }),
    output: z.string(),
  },
  
  'Write': {
    input: z.object({
      file_path: z.string(),
      content: z.string(),
    }),
    output: z.object({
      success: z.boolean(),
      bytes_written: z.number().optional(),
    }),
  },
  
  'Edit': {
    input: z.object({
      file_path: z.string(),
      old_string: z.string(),
      new_string: z.string(),
      replace_all: z.boolean().optional().default(false),
    }),
    output: z.object({
      success: z.boolean(),
      changes_made: z.number(),
    }),
  },
} as const;

// Diagram Bridge MCP tool contracts
export const diagramMCPContract = {
  'mcp__diagram__generate': {
    input: z.object({
      type: z.enum(['mermaid', 'plantuml', 'graphviz', 'drawio']),
      content: z.string(),
      format: z.enum(['png', 'svg', 'pdf']).default('png'),
      theme: z.string().optional(),
      width: z.number().optional(),
      height: z.number().optional(),
    }),
    output: z.object({
      url: z.string(),
      format: z.string(),
      width: z.number(),
      height: z.number(),
      cache_key: z.string(),
    }),
  },
  
  'mcp__diagram__validate': {
    input: z.object({
      type: z.enum(['mermaid', 'plantuml', 'graphviz', 'drawio']),
      content: z.string(),
    }),
    output: z.object({
      valid: z.boolean(),
      errors: z.array(z.string()),
      warnings: z.array(z.string()),
    }),
  },
} as const;

// Combined MCP contracts
export const mcpContracts = {
  supabase: supabaseMCPContract,
  figma: figmaMCPContract,
  github: githubMCPContract,
  filesystem: filesystemMCPContract,
  diagram: diagramMCPContract,
} as const;

// Type inference helpers
export type MCPTool<T extends keyof typeof mcpContracts> = typeof mcpContracts[T];
export type SupabaseMCPTools = keyof typeof supabaseMCPContract;
export type FigmaMCPTools = keyof typeof figmaMCPContract;
export type GitHubMCPTools = keyof typeof githubMCPContract;
export type FilesystemMCPTools = keyof typeof filesystemMCPContract;
export type DiagramMCPTools = keyof typeof diagramMCPContract;

// Tool validation helper
export function validateMCPCall<
  T extends keyof typeof mcpContracts,
  U extends keyof typeof mcpContracts[T]
>(
  category: T,
  tool: U,
  input: unknown
): z.infer<typeof mcpContracts[T][U]['input']> {
  const contract = mcpContracts[category][tool];
  return contract.input.parse(input);
}

// Result validation helper
export function validateMCPResult<
  T extends keyof typeof mcpContracts,
  U extends keyof typeof mcpContracts[T]
>(
  category: T,
  tool: U,
  output: unknown
): z.infer<typeof mcpContracts[T][U]['output']> {
  const contract = mcpContracts[category][tool];
  return contract.output.parse(output);
}