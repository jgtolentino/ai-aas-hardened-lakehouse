/**
 * Figma Bridge Adapter for MCP Hub
 * Enables write operations in Figma via local plugin bridge
 */
import WebSocket from 'ws';
import { EventEmitter } from 'events';

export interface FigmaBridgeConfig {
  port: number;
  timeout: number;
  maxClients: number;
}

export interface BridgeCommand {
  type: string;
  id?: string;
  data?: any;
  timestamp?: number;
}

export class FigmaBridge extends EventEmitter {
  private wss: WebSocket.Server;
  private clients: Set<WebSocket> = new Set();
  private config: FigmaBridgeConfig;
  private pendingCommands: Map<string, { resolve: Function; reject: Function; timeout: NodeJS.Timeout }> = new Map();

  constructor(config: FigmaBridgeConfig) {
    super();
    this.config = config;
    this.wss = new WebSocket.Server({ 
      port: config.port,
      path: '/figma-bridge'
    });
    
    this.setupServer();
    console.log(`🎨 Figma Bridge listening on ws://localhost:${config.port}/figma-bridge`);
  }

  private setupServer(): void {
    this.wss.on('connection', (ws: WebSocket, req) => {
      console.log(`🔌 Figma plugin connected from ${req.socket.remoteAddress}`);
      
      if (this.clients.size >= this.config.maxClients) {
        ws.close(1013, 'Maximum clients reached');
        return;
      }

      this.clients.add(ws);
      this.emit('client_connected', { clientCount: this.clients.size });

      ws.on('message', (data: WebSocket.Data) => {
        try {
          const message = JSON.parse(data.toString());
          this.handlePluginMessage(ws, message);
        } catch (error) {
          console.error('❌ Invalid message from Figma plugin:', error);
        }
      });

      ws.on('close', (code: number, reason: Buffer) => {
        console.log(`🔌 Figma plugin disconnected: ${code} ${reason}`);
        this.clients.delete(ws);
        this.emit('client_disconnected', { clientCount: this.clients.size });
      });

      ws.on('error', (error: Error) => {
        console.error('❌ Figma plugin WebSocket error:', error);
        this.clients.delete(ws);
      });

      // Send welcome message
      ws.send(JSON.stringify({
        type: 'welcome',
        message: 'Connected to Claude MCP Hub',
        capabilities: [
          'create-sticky',
          'create-frame', 
          'create-component',
          'rename-selection',
          'place-component',
          'create-dashboard-layout',
          'apply-brand-tokens',
          'log-usage'
        ]
      }));
    });
  }

  private handlePluginMessage(ws: WebSocket, message: any): void {
    console.log(`📨 Message from Figma plugin:`, message);

    // Handle command responses
    if (message.id && this.pendingCommands.has(message.id)) {
      const pending = this.pendingCommands.get(message.id)!;
      clearTimeout(pending.timeout);
      this.pendingCommands.delete(message.id);

      if (message.ok) {
        pending.resolve(message);
      } else {
        pending.reject(new Error(message.error || 'Command failed'));
      }
      return;
    }

    // Handle usage logs - forward to Supabase
    if (message.type === 'store-usage-log') {
      this.emit('usage_log', message.data);
      return;
    }

    // Handle other plugin events
    this.emit('plugin_message', { ws, message });
  }

  /**
   * Execute command in Figma plugin
   */
  async executeCommand(command: BridgeCommand): Promise<any> {
    if (this.clients.size === 0) {
      throw new Error('No Figma plugins connected');
    }

    const commandId = command.id || `cmd_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const commandWithId = { ...command, id: commandId, timestamp: Date.now() };

    return new Promise((resolve, reject) => {
      // Set up timeout
      const timeout = setTimeout(() => {
        this.pendingCommands.delete(commandId);
        reject(new Error(`Command timeout after ${this.config.timeout}ms`));
      }, this.config.timeout);

      // Store pending command
      this.pendingCommands.set(commandId, { resolve, reject, timeout });

      // Send to all connected clients (usually just one)
      const message = JSON.stringify(commandWithId);
      let sent = false;

      for (const client of this.clients) {
        if (client.readyState === WebSocket.OPEN) {
          client.send(message);
          sent = true;
        } else {
          this.clients.delete(client);
        }
      }

      if (!sent) {
        clearTimeout(timeout);
        this.pendingCommands.delete(commandId);
        reject(new Error('No active Figma plugins available'));
      }
    });
  }

  /**
   * Extract PRD content from Figma board
   */
  async extractPRDContent(boardUrl: string, extractionTargets: string[] = []): Promise<any> {
    return this.executeCommand({
      type: 'extract-prd-content',
      data: {
        boardUrl,
        extractionTargets: extractionTargets.length > 0 ? extractionTargets : [
          'user-stories',
          'requirements', 
          'wireframes',
          'user-flows',
          'acceptance-criteria',
          'technical-specs',
          'design-tokens',
          'components'
        ]
      }
    });
  }

  /**
   * Extract board structure and metadata
   */
  async getBoardStructure(boardUrl: string): Promise<any> {
    return this.executeCommand({
      type: 'get-board-structure',
      data: { boardUrl }
    });
  }

  /**
   * Extract text content from selected frames
   */
  async extractTextContent(frameIds: string[] = []): Promise<any> {
    return this.executeCommand({
      type: 'extract-text-content',
      data: { frameIds }
    });
  }

  /**
   * MCP Tools - These are exposed to Claude
   */
  
  async createSticky(text: string, options: { page?: string; x?: number; y?: number; color?: string } = {}): Promise<any> {
    return this.executeCommand({
      type: 'create-sticky',
      text,
      ...options
    });
  }

  async createFrame(name: string, width: number, height: number, options: { x?: number; y?: number } = {}): Promise<any> {
    return this.executeCommand({
      type: 'create-frame',
      name,
      width,
      height,
      ...options
    });
  }

  async createComponent(name: string, width: number, height: number): Promise<any> {
    return this.executeCommand({
      type: 'create-component',
      name,
      width,
      height
    });
  }

  async renameSelection(name: string): Promise<any> {
    return this.executeCommand({
      type: 'rename-selection',
      name
    });
  }

  async placeComponent(key: string, options: { name?: string; x?: number; y?: number } = {}): Promise<any> {
    return this.executeCommand({
      type: 'place-component',
      key,
      ...options
    });
  }

  async createDashboardLayout(title: string, grid: { cols: number; gutter: number }, tiles: any[]): Promise<any> {
    return this.executeCommand({
      type: 'create-dashboard-layout',
      title,
      grid,
      tiles
    });
  }

  async applyBrandTokens(tokens: Record<string, any>): Promise<any> {
    return this.executeCommand({
      type: 'apply-brand-tokens',
      tokens
    });
  }

  /**
   * Apply design patch specification for zero-click automation
   */
  async applyPatch(patchSpec: any): Promise<any> {
    return this.executeCommand({
      type: 'apply-patch',
      data: patchSpec
    });
  }

  /**
   * Clone and modify design for rebranding/retargeting
   */
  async cloneAndModify(sourceFileKey: string, sourceNodeId: string, modifications: any): Promise<any> {
    return this.executeCommand({
      type: 'clone-and-modify',
      data: {
        sourceFileKey,
        sourceNodeId,
        modifications
      }
    });
  }

  /**
   * Get connection status
   */
  getStatus(): { connected: boolean; clientCount: number; pendingCommands: number } {
    return {
      connected: this.clients.size > 0,
      clientCount: this.clients.size,
      pendingCommands: this.pendingCommands.size
    };
  }

  /**
   * Close bridge
   */
  close(): void {
    for (const client of this.clients) {
      client.close(1001, 'Server shutting down');
    }
    this.clients.clear();
    this.wss.close();
  }
}

// MCP Server integration
export function createFigmaMCPTools(bridge: FigmaBridge) {
  return {
    'figma_create_sticky': {
      description: 'Create a sticky note in FigJam',
      parameters: {
        type: 'object',
        properties: {
          text: { type: 'string', description: 'Text content of the sticky note' },
          x: { type: 'number', description: 'X position (optional)' },
          y: { type: 'number', description: 'Y position (optional)' },
          color: { type: 'string', enum: ['yellow', 'blue', 'green', 'pink'], description: 'Sticky note color' }
        },
        required: ['text']
      },
      handler: async (params: any) => bridge.createSticky(params.text, params)
    },

    'figma_create_frame': {
      description: 'Create a frame in Figma',
      parameters: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Frame name' },
          width: { type: 'number', description: 'Frame width in pixels' },
          height: { type: 'number', description: 'Frame height in pixels' },
          x: { type: 'number', description: 'X position (optional)' },
          y: { type: 'number', description: 'Y position (optional)' }
        },
        required: ['name', 'width', 'height']
      },
      handler: async (params: any) => bridge.createFrame(params.name, params.width, params.height, params)
    },

    'figma_create_component': {
      description: 'Create a component from selection in Figma',
      parameters: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'Component name' },
          width: { type: 'number', description: 'Component width' },
          height: { type: 'number', description: 'Component height' }
        },
        required: ['name', 'width', 'height']
      },
      handler: async (params: any) => bridge.createComponent(params.name, params.width, params.height)
    },

    'figma_rename_selection': {
      description: 'Rename selected elements in Figma',
      parameters: {
        type: 'object',
        properties: {
          name: { type: 'string', description: 'New name for selected elements' }
        },
        required: ['name']
      },
      handler: async (params: any) => bridge.renameSelection(params.name)
    },

    'figma_place_component': {
      description: 'Place a component instance in Figma',
      parameters: {
        type: 'object',
        properties: {
          key: { type: 'string', description: 'Component key from Figma' },
          name: { type: 'string', description: 'Instance name (optional)' },
          x: { type: 'number', description: 'X position (optional)' },
          y: { type: 'number', description: 'Y position (optional)' }
        },
        required: ['key']
      },
      handler: async (params: any) => bridge.placeComponent(params.key, params)
    },

    'figma_create_dashboard_layout': {
      description: 'Create a dashboard layout from DashboardML specification',
      parameters: {
        type: 'object',
        properties: {
          title: { type: 'string', description: 'Dashboard title' },
          grid: {
            type: 'object',
            properties: {
              cols: { type: 'number', description: 'Number of columns' },
              gutter: { type: 'number', description: 'Gutter size in pixels' }
            },
            required: ['cols', 'gutter']
          },
          tiles: {
            type: 'array',
            items: {
              type: 'object',
              properties: {
                id: { type: 'string' },
                type: { type: 'string' },
                x: { type: 'number' },
                y: { type: 'number' },
                w: { type: 'number' },
                h: { type: 'number' }
              }
            }
          }
        },
        required: ['title', 'grid', 'tiles']
      },
      handler: async (params: any) => bridge.createDashboardLayout(params.title, params.grid, params.tiles)
    },

    'figma_apply_brand_tokens': {
      description: 'Apply brand design tokens to selected elements',
      parameters: {
        type: 'object',
        properties: {
          tokens: {
            type: 'object',
            description: 'Design tokens (colors, typography, spacing)',
            additionalProperties: true
          }
        },
        required: ['tokens']
      },
      handler: async (params: any) => bridge.applyBrandTokens(params.tokens)
    },

    'figma_get_status': {
      description: 'Get Figma bridge connection status',
      parameters: { type: 'object', properties: {} },
      handler: async () => bridge.getStatus()
    },

    'figma_extract_prd_content': {
      description: 'Extract Product Requirements Document content from Figma board',
      parameters: {
        type: 'object',
        properties: {
          boardUrl: { type: 'string', description: 'Figma board URL' },
          extractionTargets: {
            type: 'array',
            items: { type: 'string' },
            description: 'Specific content types to extract (user-stories, requirements, wireframes, etc.)'
          }
        },
        required: ['boardUrl']
      },
      handler: async (params: any) => bridge.extractPRDContent(params.boardUrl, params.extractionTargets)
    },

    'figma_get_board_structure': {
      description: 'Get board structure and metadata from Figma board',
      parameters: {
        type: 'object',
        properties: {
          boardUrl: { type: 'string', description: 'Figma board URL' }
        },
        required: ['boardUrl']
      },
      handler: async (params: any) => bridge.getBoardStructure(params.boardUrl)
    },

    'figma_extract_text_content': {
      description: 'Extract text content from selected frames in Figma',
      parameters: {
        type: 'object',
        properties: {
          frameIds: {
            type: 'array',
            items: { type: 'string' },
            description: 'Frame IDs to extract text from (empty for all selected)'
          }
        }
      },
      handler: async (params: any) => bridge.extractTextContent(params.frameIds)
    },

    'figma_apply_patch': {
      description: 'Apply design patch specification for zero-click automation',
      parameters: {
        type: 'object',
        properties: {
          patchSpec: {
            type: 'object',
            description: 'Design patch specification with target and operations',
            additionalProperties: true
          }
        },
        required: ['patchSpec']
      },
      handler: async (params: any) => bridge.applyPatch(params.patchSpec)
    },

    'figma_clone_and_modify': {
      description: 'Clone and modify design for rebranding/retargeting',
      parameters: {
        type: 'object',
        properties: {
          sourceFileKey: { type: 'string', description: 'Source Figma file key' },
          sourceNodeId: { type: 'string', description: 'Source node ID to clone' },
          modifications: {
            type: 'object',
            description: 'Modifications to apply (brand tokens, text replacements, etc.)',
            additionalProperties: true
          }
        },
        required: ['sourceFileKey', 'sourceNodeId', 'modifications']
      },
      handler: async (params: any) => bridge.cloneAndModify(params.sourceFileKey, params.sourceNodeId, params.modifications)
    }
  };
}