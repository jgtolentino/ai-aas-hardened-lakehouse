/**
 * Figma Dev Mode Agent - MCP Hub Integration
 * Enables Claude agent to run inside Figma Make with full repo access
 */

import { EventEmitter } from 'events';
import WebSocket from 'ws';
import { spawn, ChildProcess } from 'child_process';
import path from 'path';
import fs from 'fs/promises';

interface FigmaDevModeConfig {
  repoRoot: string;
  mcpHubPort: number;
  figmaBridgePort: number;
  supabaseProjectRef: string;
  githubRepo: string;
}

interface FrameMetadata {
  id: string;
  name: string;
  type: string;
  properties: Record<string, any>;
  designTokens: Record<string, any>;
  dataRequirements?: string[];
}

interface ComponentGenerationResult {
  componentPath: string;
  figmaConnectPath: string;
  migrationPath?: string;
  typesUpdated: boolean;
}

export class FigmaDevModeAgent extends EventEmitter {
  private config: FigmaDevModeConfig;
  private wsServer: WebSocket.Server;
  private supabaseProcess: ChildProcess | null = null;
  private connectedClients: Set<WebSocket> = new Set();

  constructor(config: FigmaDevModeConfig) {
    super();
    this.config = config;
    this.wsServer = new WebSocket.Server({ 
      port: config.figmaBridgePort,
      path: '/figma-dev-agent'
    });
    
    this.setupWebSocketServer();
    this.startSupabaseBridge();
    
    console.log(`🎨 Figma Dev Mode Agent running on ws://localhost:${config.figmaBridgePort}/figma-dev-agent`);
  }

  private setupWebSocketServer(): void {
    this.wsServer.on('connection', (ws: WebSocket) => {
      console.log('🔌 Figma Dev Mode client connected');
      this.connectedClients.add(ws);

      // Send capabilities to Figma
      ws.send(JSON.stringify({
        type: 'agent_ready',
        capabilities: {
          component_generation: true,
          database_migrations: true,
          github_integration: true,
          design_token_sync: true
        },
        mcp_tools: [
          'supabase_execute_sql',
          'supabase_create_migration', 
          'github_create_branch',
          'github_commit_file'
        ]
      }));

      ws.on('message', async (data: WebSocket.Data) => {
        try {
          const message = JSON.parse(data.toString());
          await this.handleFigmaMessage(ws, message);
        } catch (error) {
          console.error('❌ Error handling Figma message:', error);
          ws.send(JSON.stringify({
            type: 'error',
            message: error instanceof Error ? error.message : 'Unknown error'
          }));
        }
      });

      ws.on('close', () => {
        console.log('🔌 Figma Dev Mode client disconnected');
        this.connectedClients.delete(ws);
      });
    });
  }

  private async handleFigmaMessage(ws: WebSocket, message: any): Promise<void> {
    console.log(`📨 Figma message:`, message.type);

    switch (message.type) {
      case 'frame_selected':
        await this.handleFrameSelection(ws, message.frameData);
        break;
        
      case 'generate_component':
        await this.handleComponentGeneration(ws, message.frameData);
        break;
        
      case 'sync_design_tokens':
        await this.handleDesignTokenSync(ws, message.tokens);
        break;
        
      case 'create_migration':
        await this.handleMigrationCreation(ws, message.schemaData);
        break;
        
      default:
        ws.send(JSON.stringify({
          type: 'error',
          message: `Unknown message type: ${message.type}`
        }));
    }
  }

  private async handleFrameSelection(ws: WebSocket, frameData: FrameMetadata): Promise<void> {
    // Analyze frame for component generation potential
    const analysis = await this.analyzeFrameForComponent(frameData);
    
    ws.send(JSON.stringify({
      type: 'frame_analysis',
      frameId: frameData.id,
      analysis: {
        canGenerateComponent: analysis.isGeneratable,
        suggestedComponentName: analysis.componentName,
        dataRequirements: analysis.dataRequirements,
        migrationRequired: analysis.requiresDbChanges
      }
    }));
  }

  private async handleComponentGeneration(ws: WebSocket, frameData: FrameMetadata): Promise<void> {
    try {
      // Generate React component
      const result = await this.generateComponentFromFrame(frameData);
      
      // Create Figma Code Connect mapping
      await this.createCodeConnectMapping(frameData, result.componentPath);
      
      // Generate database migration if needed
      if (frameData.dataRequirements?.length) {
        await this.createDatabaseMigration(frameData);
      }
      
      // Commit to GitHub
      await this.commitToGitHub(result, frameData);
      
      ws.send(JSON.stringify({
        type: 'component_generated',
        success: true,
        result: {
          componentPath: result.componentPath,
          codeConnectPath: result.figmaConnectPath,
          migrationCreated: !!result.migrationPath,
          githubBranch: `figma-sync-${frameData.name.toLowerCase()}-${Date.now()}`
        }
      }));
      
    } catch (error) {
      console.error('❌ Component generation failed:', error);
      ws.send(JSON.stringify({
        type: 'component_generation_failed',
        error: error instanceof Error ? error.message : 'Unknown error'
      }));
    }
  }

  private async generateComponentFromFrame(frameData: FrameMetadata): Promise<ComponentGenerationResult> {
    const componentName = this.sanitizeComponentName(frameData.name);
    const componentDir = path.join(
      this.config.repoRoot, 
      'apps/scout-dashboard/src/components/generated'
    );
    
    // Ensure directory exists
    await fs.mkdir(componentDir, { recursive: true });
    
    // Generate component code
    const componentCode = this.generateReactComponent(frameData, componentName);
    const componentPath = path.join(componentDir, `${componentName}.tsx`);
    await fs.writeFile(componentPath, componentCode);
    
    // Generate Figma Code Connect mapping
    const figmaConnectCode = this.generateFigmaConnect(frameData, componentName);
    const figmaConnectPath = path.join(componentDir, `${componentName}.figma.tsx`);
    await fs.writeFile(figmaConnectPath, figmaConnectCode);
    
    return {
      componentPath,
      figmaConnectPath,
      typesUpdated: false
    };
  }

  private generateReactComponent(frameData: FrameMetadata, componentName: string): string {
    return `/**
 * ${componentName} Component
 * Generated from Figma frame: ${frameData.name}
 * Generated at: ${new Date().toISOString()}
 */

import React from 'react';
import { cn } from '@/lib/utils';

interface ${componentName}Props {
  className?: string;
  ${frameData.properties?.variant ? `variant?: '${Object.keys(frameData.properties.variant).join("' | '")}';` : ''}
  ${frameData.dataRequirements?.map(req => `${req}?: any;`).join('\n  ') || ''}
}

export function ${componentName}({ 
  className,
  ${frameData.properties?.variant ? 'variant = "default",' : ''}
  ${frameData.dataRequirements?.map(req => `${req},`).join('\n  ') || ''}
  ...props 
}: ${componentName}Props) {
  return (
    <div 
      className={cn(
        "figma-generated-component",
        ${frameData.properties?.variant ? 'variant === "primary" && "bg-primary text-primary-foreground",' : ''}
        ${frameData.properties?.variant ? 'variant === "secondary" && "bg-secondary text-secondary-foreground",' : ''}
        className
      )}
      {...props}
    >
      {/* Frame content: ${frameData.name} */}
      ${frameData.properties?.text ? `<span>{${frameData.properties.text}}</span>` : ''}
      {/* TODO: Implement component based on Figma design */}
    </div>
  );
}

export default ${componentName};`;
  }

  private generateFigmaConnect(frameData: FrameMetadata, componentName: string): string {
    return `/**
 * Figma Code Connect mapping for ${componentName}
 * Maps Figma properties to React props
 */

import figma from '@figma/code-connect';
import { ${componentName} } from './${componentName}';

figma.connect(${componentName}, '${frameData.id}', {
  example: ({ variant, ${frameData.dataRequirements?.join(', ') || ''} }) => (
    <${componentName}
      ${frameData.properties?.variant ? 'variant={figma.enum("Variant", {\n        "Primary": "primary",\n        "Secondary": "secondary"\n      })}' : ''}
      ${frameData.dataRequirements?.map(req => 
        `${req}={figma.string("${req.charAt(0).toUpperCase() + req.slice(1)}")}`
      ).join('\n      ') || ''}
    />
  ),
  props: {
    ${frameData.properties?.variant ? 'variant: figma.enum("Variant"),' : ''}
    ${frameData.dataRequirements?.map(req => 
      `${req}: figma.string("${req.charAt(0).toUpperCase() + req.slice(1)}")`
    ).join(',\n    ') || ''}
  }
});`;
  }

  private async createCodeConnectMapping(frameData: FrameMetadata, componentPath: string): Promise<void> {
    // Update Code Connect registry
    const codeConnectConfig = path.join(
      this.config.repoRoot,
      'apps/scout-dashboard/code-connect.config.json'
    );
    
    try {
      const config = JSON.parse(await fs.readFile(codeConnectConfig, 'utf-8'));
      config.mappings = config.mappings || {};
      config.mappings[frameData.id] = {
        component: componentPath,
        figmaUrl: `https://www.figma.com/design/${frameData.id}`,
        lastUpdated: new Date().toISOString()
      };
      
      await fs.writeFile(codeConnectConfig, JSON.stringify(config, null, 2));
    } catch (error) {
      console.error('⚠️ Failed to update Code Connect config:', error);
    }
  }

  private async createDatabaseMigration(frameData: FrameMetadata): Promise<string | null> {
    if (!frameData.dataRequirements?.length) return null;
    
    const timestamp = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
    const migrationName = `${timestamp}_add_${frameData.name.toLowerCase()}_state_tracking.sql`;
    const migrationPath = path.join(
      this.config.repoRoot,
      'supabase/migrations',
      migrationName
    );
    
    const migrationSql = this.generateMigrationSql(frameData);
    await fs.writeFile(migrationPath, migrationSql);
    
    return migrationPath;
  }

  private generateMigrationSql(frameData: FrameMetadata): string {
    const tableName = `${frameData.name.toLowerCase()}_states`;
    
    return `-- Migration for Figma component: ${frameData.name}
-- Generated at: ${new Date().toISOString()}

CREATE TABLE IF NOT EXISTS scout.${tableName} (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  component_id TEXT NOT NULL,
  ${frameData.dataRequirements?.map(req => 
    `${req} JSONB,`
  ).join('\n  ') || ''}
  state_data JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE scout.${tableName} ENABLE ROW LEVEL SECURITY;

-- Policy for authenticated access
CREATE POLICY "${tableName}_access" ON scout.${tableName}
  FOR ALL USING (auth.role() = 'authenticated');

-- Update trigger
CREATE OR REPLACE FUNCTION scout.update_${tableName}_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ${tableName}_update_timestamp
  BEFORE UPDATE ON scout.${tableName}
  FOR EACH ROW
  EXECUTE FUNCTION scout.update_${tableName}_timestamp();

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_${tableName}_component_id 
  ON scout.${tableName}(component_id);

-- Comment
COMMENT ON TABLE scout.${tableName} IS 'Auto-generated from Figma component: ${frameData.name}';`;
  }

  private async commitToGitHub(result: ComponentGenerationResult, frameData: FrameMetadata): Promise<void> {
    const branchName = `figma-sync-${frameData.name.toLowerCase()}-${Date.now()}`;
    
    // Use git commands to create branch and commit
    const commands = [
      `cd ${this.config.repoRoot}`,
      `git checkout -b ${branchName}`,
      `git add ${result.componentPath}`,
      `git add ${result.figmaConnectPath}`,
      result.migrationPath ? `git add ${result.migrationPath}` : '',
      `git commit -m "feat: Add ${frameData.name} component from Figma

🎨 Generated from Figma Dev Mode Agent
Frame ID: ${frameData.id}
Component: ${result.componentPath}
${result.migrationPath ? `Migration: ${result.migrationPath}` : ''}

Co-Authored-By: Claude <noreply@anthropic.com>"`
    ].filter(Boolean);

    for (const command of commands) {
      await this.executeCommand(command);
    }
  }

  private async executeCommand(command: string): Promise<string> {
    return new Promise((resolve, reject) => {
      const process = spawn('bash', ['-c', command], {
        cwd: this.config.repoRoot,
        stdio: 'pipe'
      });

      let output = '';
      let error = '';

      process.stdout?.on('data', (data) => {
        output += data.toString();
      });

      process.stderr?.on('data', (data) => {
        error += data.toString();
      });

      process.on('close', (code) => {
        if (code === 0) {
          resolve(output);
        } else {
          reject(new Error(`Command failed: ${command}\n${error}`));
        }
      });
    });
  }

  private async analyzeFrameForComponent(frameData: FrameMetadata): Promise<{
    isGeneratable: boolean;
    componentName: string;
    dataRequirements: string[];
    requiresDbChanges: boolean;
  }> {
    // Analyze frame properties to determine if it's suitable for component generation
    const isGeneratable = frameData.type === 'COMPONENT' || 
                          frameData.name.includes('Component') ||
                          frameData.name.includes('Card') ||
                          frameData.name.includes('Dashboard');

    const componentName = this.sanitizeComponentName(frameData.name);
    
    // Infer data requirements from frame properties
    const dataRequirements: string[] = [];
    if (frameData.properties?.data_source) {
      dataRequirements.push('dataSource');
    }
    if (frameData.properties?.filters) {
      dataRequirements.push('filters');
    }
    if (frameData.name.toLowerCase().includes('kpi')) {
      dataRequirements.push('kpiValue', 'kpiLabel', 'trend');
    }

    return {
      isGeneratable,
      componentName,
      dataRequirements,
      requiresDbChanges: dataRequirements.length > 0
    };
  }

  private sanitizeComponentName(name: string): string {
    return name
      .replace(/[^a-zA-Z0-9]/g, '')
      .replace(/^[0-9]/, 'Component$&')
      .replace(/^[a-z]/, char => char.toUpperCase());
  }

  private async handleDesignTokenSync(ws: WebSocket, tokens: Record<string, any>): Promise<void> {
    try {
      // Update Tailwind config with new design tokens
      const tailwindConfigPath = path.join(
        this.config.repoRoot,
        'apps/scout-dashboard/tailwind.config.ts'
      );
      
      // Read current config
      const currentConfig = await fs.readFile(tailwindConfigPath, 'utf-8');
      
      // Update with new tokens (simplified implementation)
      const updatedConfig = this.injectDesignTokens(currentConfig, tokens);
      await fs.writeFile(tailwindConfigPath, updatedConfig);
      
      // Create CSS variables file
      const cssVariables = this.generateCSSVariables(tokens);
      const cssPath = path.join(
        this.config.repoRoot,
        'apps/scout-dashboard/src/styles/figma-tokens.css'
      );
      await fs.writeFile(cssPath, cssVariables);
      
      ws.send(JSON.stringify({
        type: 'design_tokens_synced',
        success: true,
        updatedFiles: [tailwindConfigPath, cssPath]
      }));
      
    } catch (error) {
      ws.send(JSON.stringify({
        type: 'design_tokens_sync_failed',
        error: error instanceof Error ? error.message : 'Unknown error'
      }));
    }
  }

  private injectDesignTokens(configContent: string, tokens: Record<string, any>): string {
    // Simple token injection (would need more sophisticated parsing in production)
    const tokenSection = `
    // Auto-generated Figma design tokens
    extend: {
      colors: {
        ${Object.entries(tokens.colors || {}).map(([key, value]) => 
          `'figma-${key}': '${value}',`
        ).join('\n        ')}
      },
      spacing: {
        ${Object.entries(tokens.spacing || {}).map(([key, value]) => 
          `'figma-${key}': '${value}',`
        ).join('\n        ')}
      }
    }`;
    
    // Insert before the closing brace of theme
    return configContent.replace(
      /theme:\s*{([^}]+)}/,
      `theme: {$1,${tokenSection}}`
    );
  }

  private generateCSSVariables(tokens: Record<string, any>): string {
    const cssVars = Object.entries(tokens)
      .flatMap(([category, values]) => 
        Object.entries(values as Record<string, any>).map(([key, value]) =>
          `  --figma-${category}-${key}: ${value};`
        )
      )
      .join('\n');

    return `:root {
  /* Auto-generated Figma design tokens */
  /* Generated at: ${new Date().toISOString()} */
${cssVars}
}

/* Utility classes for Figma tokens */
${Object.keys(tokens.colors || {}).map(key => 
  `.text-figma-${key} { color: var(--figma-colors-${key}); }`
).join('\n')}

${Object.keys(tokens.spacing || {}).map(key => 
  `.space-figma-${key} { margin: var(--figma-spacing-${key}); }`
).join('\n')}`;
  }

  private async handleMigrationCreation(ws: WebSocket, schemaData: any): Promise<void> {
    try {
      const migrationPath = await this.createDatabaseMigration(schemaData);
      
      // Apply migration via Supabase CLI
      await this.executeCommand(`cd ${this.config.repoRoot} && supabase db push`);
      
      ws.send(JSON.stringify({
        type: 'migration_created',
        success: true,
        migrationPath,
        applied: true
      }));
      
    } catch (error) {
      ws.send(JSON.stringify({
        type: 'migration_failed',
        error: error instanceof Error ? error.message : 'Unknown error'
      }));
    }
  }

  private startSupabaseBridge(): void {
    // Start Supabase MCP bridge for database operations
    this.supabaseProcess = spawn('npx', [
      '@supabase/mcp-server-supabase@latest',
      '--project-ref=' + this.config.supabaseProjectRef
    ], {
      cwd: this.config.repoRoot,
      stdio: 'pipe',
      env: {
        ...process.env,
        SUPABASE_ACCESS_TOKEN: process.env.SUPABASE_ACCESS_TOKEN
      }
    });

    this.supabaseProcess.on('error', (error) => {
      console.error('❌ Supabase MCP bridge failed:', error);
    });
  }

  public async shutdown(): Promise<void> {
    // Close WebSocket connections
    this.connectedClients.forEach(client => {
      client.close(1000, 'Server shutting down');
    });
    
    // Close WebSocket server
    this.wsServer.close();
    
    // Kill Supabase process
    if (this.supabaseProcess) {
      this.supabaseProcess.kill();
    }
    
    console.log('🛑 Figma Dev Mode Agent shut down');
  }
}

// Factory function for easy instantiation
export function createFigmaDevModeAgent(config: FigmaDevModeConfig): FigmaDevModeAgent {
  return new FigmaDevModeAgent(config);
}

export default FigmaDevModeAgent;`;