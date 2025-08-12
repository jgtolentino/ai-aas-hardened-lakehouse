import { readFileSync, readdirSync, statSync } from 'fs';
import { join, extname } from 'path';
import * as yaml from 'js-yaml';
import { agentRegistry } from '../registry/agent-registry';
import type { AgentConfig } from '../registry/agent-schema';

export class AgentLoader {
  private agentPaths: string[];
  private loadedAgents: Set<string> = new Set();

  constructor(agentPaths: string[] = []) {
    this.agentPaths = agentPaths.length > 0 
      ? agentPaths 
      : [join(process.cwd(), 'pulser/agents')];
  }

  async loadAllAgents(): Promise<number> {
    let loadedCount = 0;

    for (const path of this.agentPaths) {
      try {
        const count = await this.loadAgentsFromPath(path);
        loadedCount += count;
      } catch (error) {
        console.error(`[AgentLoader] Failed to load agents from ${path}:`, error);
      }
    }

    console.log(`[AgentLoader] Total agents loaded: ${loadedCount}`);
    return loadedCount;
  }

  async loadAgentsFromPath(path: string): Promise<number> {
    let loadedCount = 0;

    try {
      const files = readdirSync(path);
      
      for (const file of files) {
        const filePath = join(path, file);
        const stat = statSync(filePath);

        if (stat.isDirectory()) {
          // Recursively load from subdirectories
          loadedCount += await this.loadAgentsFromPath(filePath);
        } else if (this.isAgentFile(file)) {
          try {
            await this.loadAgentFile(filePath);
            loadedCount++;
          } catch (error) {
            console.error(`[AgentLoader] Failed to load ${filePath}:`, error);
          }
        }
      }
    } catch (error) {
      console.error(`[AgentLoader] Error reading directory ${path}:`, error);
    }

    return loadedCount;
  }

  async loadAgentFile(filePath: string): Promise<void> {
    const ext = extname(filePath).toLowerCase();
    let config: any;

    try {
      const content = readFileSync(filePath, 'utf-8');

      switch (ext) {
        case '.yaml':
        case '.yml':
          config = yaml.load(content);
          break;
        case '.json':
          config = JSON.parse(content);
          break;
        default:
          throw new Error(`Unsupported file format: ${ext}`);
      }

      // Validate and transform config
      const agentConfig = this.validateAndTransform(config, filePath);
      
      // Check if already loaded
      if (this.loadedAgents.has(agentConfig.metadata.id)) {
        console.warn(`[AgentLoader] Agent ${agentConfig.metadata.id} already loaded, skipping`);
        return;
      }

      // Register agent
      await agentRegistry.register(agentConfig);
      this.loadedAgents.add(agentConfig.metadata.id);

      console.log(`[AgentLoader] Loaded agent: ${agentConfig.metadata.name} from ${filePath}`);
    } catch (error) {
      throw new Error(`Failed to load agent from ${filePath}: ${error}`);
    }
  }

  private isAgentFile(filename: string): boolean {
    const ext = extname(filename).toLowerCase();
    return ['.yaml', '.yml', '.json'].includes(ext) && 
           !filename.startsWith('.') &&
           !filename.includes('.test.') &&
           !filename.includes('.spec.');
  }

  private validateAndTransform(config: any, filePath: string): AgentConfig {
    // Add timestamps if not present
    if (!config.metadata.createdAt) {
      config.metadata.createdAt = new Date();
    }
    if (!config.metadata.updatedAt) {
      config.metadata.updatedAt = new Date();
    }

    // Ensure arrays
    config.metadata.tags = config.metadata.tags || [];
    config.capabilities = config.capabilities || [];

    // Validate required fields
    const required = ['metadata', 'type', 'runtime', 'capabilities', 'security'];
    for (const field of required) {
      if (!config[field]) {
        throw new Error(`Missing required field: ${field}`);
      }
    }

    // Add default security settings if not specified
    config.security = {
      sandboxed: true,
      allowedHosts: [],
      deniedActions: [],
      requiredPermissions: [],
      ...config.security
    };

    // Add default limits if not specified
    config.limits = {
      maxExecutionTime: 300000, // 5 minutes
      maxMemoryMB: 256,
      maxConcurrent: 1,
      ...config.limits
    };

    return config as AgentConfig;
  }

  async reloadAgent(agentId: string): Promise<void> {
    // Find the agent file
    for (const path of this.agentPaths) {
      const files = this.findAgentFiles(path);
      
      for (const file of files) {
        try {
          const content = readFileSync(file, 'utf-8');
          const config = file.endsWith('.json') 
            ? JSON.parse(content) 
            : yaml.load(content) as any;
          
          if (config.metadata?.id === agentId) {
            // Unregister old version
            try {
              await agentRegistry.unregister(agentId);
              this.loadedAgents.delete(agentId);
            } catch (error) {
              // Agent might not be registered
            }
            
            // Load new version
            await this.loadAgentFile(file);
            return;
          }
        } catch (error) {
          continue;
        }
      }
    }
    
    throw new Error(`Agent ${agentId} not found in any configured path`);
  }

  private findAgentFiles(dir: string, files: string[] = []): string[] {
    try {
      const entries = readdirSync(dir);
      
      for (const entry of entries) {
        const fullPath = join(dir, entry);
        const stat = statSync(fullPath);
        
        if (stat.isDirectory()) {
          this.findAgentFiles(fullPath, files);
        } else if (this.isAgentFile(entry)) {
          files.push(fullPath);
        }
      }
    } catch (error) {
      // Ignore errors reading directories
    }
    
    return files;
  }

  getLoadedAgents(): string[] {
    return Array.from(this.loadedAgents);
  }

  addAgentPath(path: string): void {
    if (!this.agentPaths.includes(path)) {
      this.agentPaths.push(path);
    }
  }
}

// Export singleton instance
export const agentLoader = new AgentLoader();