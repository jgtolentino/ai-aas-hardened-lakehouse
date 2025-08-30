import { z } from 'zod';
import { createJSONGuard } from '../core';

/**
 * Pre-built JSON guards for common AI operations
 * Ensures 100% JSON conformance and eliminates prose contamination
 */

// Component generation guard
export const componentGuard = createJSONGuard(
  z.object({
    componentName: z.string(),
    filePath: z.string(),
    imports: z.array(z.string()),
    props: z.record(z.string(), z.object({
      type: z.string(),
      required: z.boolean(),
      default: z.any().optional(),
    })),
    jsx: z.string(),
    exports: z.array(z.string()),
  })
);

// Database schema guard
export const schemaGuard = createJSONGuard(
  z.object({
    tables: z.array(z.object({
      name: z.string(),
      columns: z.array(z.object({
        name: z.string(),
        type: z.string(),
        nullable: z.boolean(),
        primary_key: z.boolean(),
        foreign_key: z.string().optional(),
      })),
      indexes: z.array(z.object({
        name: z.string(),
        columns: z.array(z.string()),
        unique: z.boolean(),
      })).optional(),
    })),
    views: z.array(z.object({
      name: z.string(),
      definition: z.string(),
    })).optional(),
  })
);

// Migration guard
export const migrationGuard = createJSONGuard(
  z.object({
    name: z.string(),
    statements: z.array(z.string()),
    rollback: z.array(z.string()).optional(),
    dependencies: z.array(z.string()).optional(),
  })
);

// Analytics query guard
export const analyticsGuard = createJSONGuard(
  z.object({
    query: z.string(),
    parameters: z.record(z.string(), z.any()).optional(),
    expected_columns: z.array(z.object({
      name: z.string(),
      type: z.string(),
    })),
    cache_ttl: z.number().optional(),
  })
);

// Task orchestration guard
export const taskGuard = createJSONGuard(
  z.object({
    tasks: z.array(z.object({
      id: z.string(),
      type: z.string(),
      description: z.string(),
      agent: z.string(),
      inputs: z.record(z.string(), z.any()),
      dependencies: z.array(z.string()),
      timeout: z.number().optional(),
    })),
    workflow_id: z.string(),
    priority: z.enum(['low', 'medium', 'high', 'critical']),
  })
);

// Diagram generation guard
export const diagramGuard = createJSONGuard(
  z.object({
    type: z.enum(['mermaid', 'plantuml', 'graphviz', 'drawio']),
    content: z.string(),
    title: z.string().optional(),
    description: z.string().optional(),
    format: z.enum(['png', 'svg', 'pdf']).default('png'),
  })
);

// Export all guards
export const guards = {
  component: componentGuard,
  schema: schemaGuard,
  migration: migrationGuard,
  analytics: analyticsGuard,
  task: taskGuard,
  diagram: diagramGuard,
} as const;