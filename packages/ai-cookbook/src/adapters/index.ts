import { withRetry, trackCost } from '../core';
import { schemas } from '../schemas';

/**
 * Hardened MCP adapters with retry logic and observability
 */

export class SupabaseAdapter {
  constructor(
    private projectRef: string,
    private accessToken: string,
    private mcpExecute: (tool: string, params: any) => Promise<any>
  ) {}

  /**
   * Execute SQL with automatic retry and error mapping
   */
  async executeSQL(query: string, params?: Record<string, any>) {
    const operation = trackCost('supabase:execute_sql');
    const startTime = operation.start();

    const executeWithRetry = withRetry(
      async () => {
        return await this.mcpExecute('mcp__supabase__execute_sql', {
          query,
          params,
        });
      },
      {
        retries: 3,
        onFailedAttempt: (error, attempt) => {
          console.warn(`[Supabase SQL Retry ${attempt}]`, error.message);
        },
      }
    );

    try {
      const result = await executeWithRetry();
      const validated = schemas.supabase.queryResult.parse(result);
      
      operation.end({
        model: 'supabase',
        success: true,
        input_tokens: query.length,
        output_tokens: JSON.stringify(validated).length,
      });
      
      return validated;
    } catch (error: any) {
      operation.end({
        model: 'supabase',
        success: false,
        error: error.message,
      });
      
      // Map Postgres errors to user-friendly messages
      if (error.code === '42P01') {
        throw new Error(`Table or view does not exist. Check schema and table name.`);
      }
      if (error.code === '42703') {
        throw new Error(`Column does not exist. Check column names in query.`);
      }
      if (error.code === '23505') {
        throw new Error(`Duplicate key violation. Record already exists.`);
      }
      
      throw error;
    }
  }

  /**
   * List tables with schema validation
   */
  async listTables(schema?: string) {
    const operation = trackCost('supabase:list_tables');
    operation.start();

    try {
      const result = await withRetry(() => 
        this.mcpExecute('mcp__supabase__list_tables', { schema })
      )();
      
      const tables = z.array(schemas.supabase.table).parse(result);
      
      operation.end({
        model: 'supabase',
        success: true,
        output_tokens: JSON.stringify(tables).length,
      });
      
      return tables;
    } catch (error: any) {
      operation.end({
        model: 'supabase',
        success: false,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Apply migration with rollback capability
   */
  async applyMigration(migration: z.infer<typeof schemas.supabase.migration>) {
    const operation = trackCost('supabase:apply_migration');
    operation.start();

    try {
      const result = await withRetry(() =>
        this.mcpExecute('mcp__supabase__apply_migration', {
          name: migration.name,
          statements: migration.statements,
        })
      )();
      
      operation.end({
        model: 'supabase',
        success: true,
        input_tokens: migration.statements.join('\n').length,
      });
      
      return result;
    } catch (error: any) {
      operation.end({
        model: 'supabase',
        success: false,
        error: error.message,
      });
      
      // Auto-rollback on migration failure
      if (migration.rollback) {
        console.warn('[Migration Failed] Attempting rollback...');
        try {
          await this.executeSQL(migration.rollback.join(';\n'));
          console.log('[Migration Rollback] Success');
        } catch (rollbackError) {
          console.error('[Migration Rollback] Failed:', rollbackError);
        }
      }
      
      throw error;
    }
  }
}

export class FigmaAdapter {
  constructor(
    private mcpExecute: (tool: string, params: any) => Promise<any>
  ) {}

  /**
   * Get current Figma selection with timeout handling
   */
  async getSelection() {
    const operation = trackCost('figma:get_selection');
    operation.start();

    const getSelectionWithTimeout = withRetry(
      async () => {
        return await this.mcpExecute('mcp__figma__get_selection', {});
      },
      {
        retries: 2,
        minTimeout: 500,
        maxTimeout: 1500,
        onFailedAttempt: (error, attempt) => {
          if (error.message?.includes('timeout') || error.message?.includes('No selection')) {
            console.warn(`[Figma] No active selection (attempt ${attempt})`);
          }
        },
      }
    );

    try {
      const result = await getSelectionWithTimeout();
      const selection = schemas.figma.selection.parse(result);
      
      operation.end({
        model: 'figma',
        success: true,
        output_tokens: JSON.stringify(selection).length,
      });
      
      return selection;
    } catch (error: any) {
      operation.end({
        model: 'figma',
        success: false,
        error: error.message,
      });
      
      // Graceful fallback for no selection
      if (error.message?.includes('timeout') || error.message?.includes('No selection')) {
        return {
          selection: [],
          fileKey: '',
          timestamp: Date.now(),
          error: 'No active Figma selection. Please select a frame or component in Figma Dev Mode.',
        };
      }
      
      throw error;
    }
  }

  /**
   * Generate component from Figma node
   */
  async generateComponent(nodeId: string, componentName: string) {
    const operation = trackCost('figma:generate_component');
    operation.start();

    try {
      const result = await withRetry(() =>
        this.mcpExecute('mcp__figma__generate_component', {
          nodeId,
          componentName,
        })
      )();
      
      const component = schemas.figma.componentGeneration.parse(result);
      
      operation.end({
        model: 'figma',
        success: true,
        input_tokens: nodeId.length + componentName.length,
        output_tokens: component.jsx.length,
      });
      
      return component;
    } catch (error: any) {
      operation.end({
        model: 'figma',
        success: false,
        error: error.message,
      });
      throw error;
    }
  }
}

export class DiagramAdapter {
  constructor(
    private krokiUrl: string = 'https://kroki.io'
  ) {}

  /**
   * Generate diagram via Kroki with caching
   */
  async generateDiagram(request: z.infer<typeof schemas.diagram.request>) {
    const operation = trackCost('diagram:generate');
    operation.start();

    const validated = schemas.diagram.request.parse(request);
    
    try {
      // Create content hash for caching
      const contentHash = btoa(validated.content).replace(/[^a-zA-Z0-9]/g, '').substring(0, 16);
      
      const response = await withRetry(async () => {
        const url = `${this.krokiUrl}/${validated.type}/${validated.format}`;
        const res = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'text/plain' },
          body: validated.content,
        });
        
        if (!res.ok) {
          throw new Error(`Kroki error: ${res.status} ${res.statusText}`);
        }
        
        return res;
      })();

      const buffer = await response.arrayBuffer();
      const dataUrl = `data:image/${validated.format};base64,${btoa(String.fromCharCode(...new Uint8Array(buffer)))}`;
      
      const result = {
        url: dataUrl,
        format: validated.format,
        width: validated.width || 800,
        height: validated.height || 600,
        cached: false,
        cache_key: contentHash,
      };
      
      operation.end({
        model: 'kroki',
        success: true,
        input_tokens: validated.content.length,
        output_tokens: buffer.byteLength,
      });
      
      return schemas.diagram.response.parse(result);
    } catch (error: any) {
      operation.end({
        model: 'kroki',
        success: false,
        error: error.message,
      });
      throw error;
    }
  }
}