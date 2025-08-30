#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { schemas, DiagramRequest, DiagramResponse } from '@scout/ai-cookbook/schemas';
import { createHash } from 'crypto';
import fetch from 'node-fetch';

/**
 * Diagram Bridge MCP Server
 * 
 * Provides diagram generation capabilities via Kroki service
 * Supports Mermaid, PlantUML, Graphviz, Draw.io, and more
 */

class DiagramBridgeMCPServer {
  private server: Server;
  private krokiUrl: string;
  private cache: Map<string, DiagramResponse> = new Map();

  constructor() {
    this.server = new Server(
      {
        name: 'diagram-bridge-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.krokiUrl = process.env.KROKI_URL || 'https://kroki.io';
    this.setupToolHandlers();
  }

  private setupToolHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'generate_diagram',
          description: 'Generate diagrams from text using Kroki service (Mermaid, PlantUML, Graphviz, Draw.io)',
          inputSchema: {
            type: 'object',
            properties: {
              type: {
                type: 'string',
                enum: ['mermaid', 'plantuml', 'graphviz', 'drawio', 'ditaa', 'blockdiag', 'seqdiag', 'actdiag', 'nwdiag', 'c4plantuml'],
                description: 'Type of diagram to generate'
              },
              content: {
                type: 'string',
                description: 'Diagram source code'
              },
              format: {
                type: 'string',
                enum: ['png', 'svg', 'pdf'],
                default: 'png',
                description: 'Output format'
              },
              theme: {
                type: 'string',
                description: 'Theme to apply (if supported by diagram type)'
              },
              width: {
                type: 'number',
                description: 'Width in pixels (for raster formats)'
              },
              height: {
                type: 'number',
                description: 'Height in pixels (for raster formats)'
              }
            },
            required: ['type', 'content']
          }
        },
        {
          name: 'validate_diagram',
          description: 'Validate diagram syntax without generating image',
          inputSchema: {
            type: 'object',
            properties: {
              type: {
                type: 'string',
                enum: ['mermaid', 'plantuml', 'graphviz', 'drawio', 'ditaa', 'blockdiag'],
                description: 'Type of diagram to validate'
              },
              content: {
                type: 'string',
                description: 'Diagram source code to validate'
              }
            },
            required: ['type', 'content']
          }
        },
        {
          name: 'list_supported_formats',
          description: 'List all supported diagram types and output formats',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        }
      ]
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'generate_diagram':
            return await this.generateDiagram(args);
          case 'validate_diagram':
            return await this.validateDiagram(args);
          case 'list_supported_formats':
            return await this.listSupportedFormats();
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error: any) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  private async generateDiagram(args: any) {
    const request: DiagramRequest = schemas.diagram.request.parse(args);
    
    // Check cache first
    const cacheKey = this.createCacheKey(request);
    if (this.cache.has(cacheKey)) {
      const cached = this.cache.get(cacheKey)!;
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              ...cached,
              cached: true,
            }),
          },
        ],
      };
    }

    try {
      // Generate diagram via Kroki
      const result = await this.callKroki(request);
      
      // Cache the result
      this.cache.set(cacheKey, result);
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(result),
          },
        ],
      };
    } catch (error: any) {
      // Enhanced error messages for common issues
      let errorMessage = error.message;
      
      if (error.message.includes('400')) {
        errorMessage = `Diagram syntax error: ${error.message}. Please check your ${request.type} syntax.`;
      } else if (error.message.includes('404')) {
        errorMessage = `Diagram type '${request.type}' not supported or Kroki service unavailable.`;
      } else if (error.message.includes('503')) {
        errorMessage = 'Kroki service temporarily unavailable. Please try again later.';
      }
      
      throw new Error(errorMessage);
    }
  }

  private async validateDiagram(args: any) {
    const { type, content } = args;
    
    try {
      // Attempt to generate SVG (lightweight) to validate syntax
      const testRequest: DiagramRequest = {
        type,
        content,
        format: 'svg',
      };
      
      await this.callKroki(testRequest);
      
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              valid: true,
              errors: [],
              warnings: [],
            }),
          },
        ],
      };
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              valid: false,
              errors: [error.message],
              warnings: [],
            }),
          },
        ],
      };
    }
  }

  private async listSupportedFormats() {
    const supportedFormats = {
      diagram_types: [
        'mermaid',
        'plantuml',
        'graphviz',
        'drawio',
        'ditaa',
        'blockdiag',
        'seqdiag',
        'actdiag',
        'nwdiag',
        'c4plantuml',
        'erd',
        'excalidraw',
        'pikchr',
        'structurizr',
        'vega',
        'vegalite',
        'wavedrom'
      ],
      output_formats: ['png', 'svg', 'pdf'],
      kroki_endpoint: this.krokiUrl,
      cache_enabled: true,
      max_cache_size: this.cache.size,
    };

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(supportedFormats, null, 2),
        },
      ],
    };
  }

  private async callKroki(request: DiagramRequest): Promise<DiagramResponse> {
    const { type, content, format = 'png', width, height } = request;
    
    // Construct Kroki URL
    const url = `${this.krokiUrl}/${type}/${format}`;
    
    // Make request to Kroki
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'text/plain',
        'User-Agent': 'TBWA-DiagramBridge-MCP/1.0.0',
      },
      body: content,
      timeout: 15000, // 15 second timeout
    });

    if (!response.ok) {
      const errorBody = await response.text().catch(() => '');
      throw new Error(`Kroki API error: ${response.status} ${response.statusText}${errorBody ? ` - ${errorBody}` : ''}`);
    }

    // Get the image data
    const buffer = await response.arrayBuffer();
    
    // Convert to data URL for easy embedding
    const base64 = Buffer.from(buffer).toString('base64');
    const mimeType = format === 'svg' ? 'image/svg+xml' : `image/${format}`;
    const dataUrl = `data:${mimeType};base64,${base64}`;
    
    // Get actual dimensions (approximated for non-SVG formats)
    const actualWidth = width || (format === 'svg' ? this.extractSVGWidth(base64) : 800);
    const actualHeight = height || (format === 'svg' ? this.extractSVGHeight(base64) : 600);
    
    const result: DiagramResponse = {
      url: dataUrl,
      format,
      width: actualWidth,
      height: actualHeight,
      cached: false,
      cache_key: this.createCacheKey(request),
    };
    
    return schemas.diagram.response.parse(result);
  }

  private createCacheKey(request: DiagramRequest): string {
    const keyData = `${request.type}:${request.format}:${request.content}:${request.width || ''}:${request.height || ''}`;
    return createHash('sha256').update(keyData).digest('hex').substring(0, 16);
  }

  private extractSVGWidth(base64: string): number {
    try {
      const svg = Buffer.from(base64, 'base64').toString('utf8');
      const widthMatch = svg.match(/width="([^"]+)"/);
      return widthMatch ? parseInt(widthMatch[1]) : 800;
    } catch {
      return 800;
    }
  }

  private extractSVGHeight(base64: string): number {
    try {
      const svg = Buffer.from(base64, 'base64').toString('utf8');
      const heightMatch = svg.match(/height="([^"]+)"/);
      return heightMatch ? parseInt(heightMatch[1]) : 600;
    } catch {
      return 600;
    }
  }

  async start() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
  }
}

// Start server if called directly
if (import.meta.url === `file://${process.argv[1]}`) {
  const server = new DiagramBridgeMCPServer();
  server.start().catch((error) => {
    console.error('Server failed to start:', error);
    process.exit(1);
  });
}

export { DiagramBridgeMCPServer };