#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { createClient, SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";

// Scout Schema Types
interface SessionHistory {
  id?: number;
  session_id?: string;
  user_id?: string;
  timestamp?: string;
  message_type?: 'user' | 'assistant' | 'system';
  content?: any;
  metadata?: any;
  embedding?: number[];
  created_at?: string;
  updated_at?: string;
}

interface Agent {
  id?: number;
  agent_id?: string;
  name: string;
  type: string;
  capabilities?: any;
  configuration?: any;
  status?: string;
  version?: string;
  created_at?: string;
  updated_at?: string;
}

interface ScoutEvent {
  id?: number;
  event_id?: string;
  event_type: string;
  source?: string;
  payload?: any;
  processed?: boolean;
  created_at?: string;
}

interface KnowledgeBase {
  id?: number;
  doc_id?: string;
  title: string;
  content?: string;
  metadata?: any;
  embedding?: number[];
  source_url?: string;
  created_at?: string;
  updated_at?: string;
}

class SupabaseScoutMCP {
  private server: Server;
  private supabase: SupabaseClient | null = null;
  
  // Tool definitions
  private tools: Tool[] = [
    // Session History Operations
    {
      name: "scout_create_session",
      description: "Create a new session history entry in Scout",
      inputSchema: {
        type: "object",
        properties: {
          user_id: { type: "string", description: "User ID" },
          message_type: { 
            type: "string", 
            enum: ["user", "assistant", "system"],
            description: "Type of message" 
          },
          content: { type: "object", description: "Message content (JSON)" },
          metadata: { type: "object", description: "Optional metadata" }
        },
        required: ["message_type", "content"]
      }
    },
    {
      name: "scout_get_sessions",
      description: "Get session history from Scout",
      inputSchema: {
        type: "object",
        properties: {
          user_id: { type: "string", description: "Filter by user ID" },
          session_id: { type: "string", description: "Filter by session ID" },
          limit: { type: "number", description: "Number of results to return", default: 10 }
        }
      }
    },
    
    // Agent Operations
    {
      name: "scout_register_agent",
      description: "Register a new agent in Scout",
      inputSchema: {
        type: "object",
        properties: {
          name: { type: "string", description: "Unique agent name" },
          type: { type: "string", description: "Agent type (registry, scraper, mcp, etc.)" },
          capabilities: { type: "object", description: "Agent capabilities (JSON)" },
          configuration: { type: "object", description: "Agent configuration" }
        },
        required: ["name", "type"]
      }
    },
    {
      name: "scout_list_agents",
      description: "List all registered agents",
      inputSchema: {
        type: "object",
        properties: {
          status: { type: "string", description: "Filter by status (active, inactive)" },
          type: { type: "string", description: "Filter by agent type" }
        }
      }
    },
    {
      name: "scout_update_agent_status",
      description: "Update an agent's status",
      inputSchema: {
        type: "object",
        properties: {
          name: { type: "string", description: "Agent name" },
          status: { type: "string", description: "New status" }
        },
        required: ["name", "status"]
      }
    },
    
    // Event Operations
    {
      name: "scout_create_event",
      description: "Create a new Scout event",
      inputSchema: {
        type: "object",
        properties: {
          event_type: { type: "string", description: "Type of event" },
          source: { type: "string", description: "Event source" },
          payload: { type: "object", description: "Event payload (JSON)" }
        },
        required: ["event_type"]
      }
    },
    {
      name: "scout_get_events",
      description: "Get Scout events",
      inputSchema: {
        type: "object",
        properties: {
          event_type: { type: "string", description: "Filter by event type" },
          processed: { type: "boolean", description: "Filter by processed status" },
          limit: { type: "number", description: "Number of results", default: 10 }
        }
      }
    },
    {
      name: "scout_mark_event_processed",
      description: "Mark an event as processed",
      inputSchema: {
        type: "object",
        properties: {
          event_id: { type: "string", description: "Event ID to mark as processed" }
        },
        required: ["event_id"]
      }
    },
    
    // Knowledge Base Operations
    {
      name: "scout_add_knowledge",
      description: "Add a document to the knowledge base",
      inputSchema: {
        type: "object",
        properties: {
          title: { type: "string", description: "Document title" },
          content: { type: "string", description: "Document content" },
          metadata: { type: "object", description: "Document metadata" },
          source_url: { type: "string", description: "Source URL if applicable" }
        },
        required: ["title", "content"]
      }
    },
    {
      name: "scout_search_knowledge",
      description: "Search the knowledge base",
      inputSchema: {
        type: "object",
        properties: {
          query: { type: "string", description: "Search query" },
          limit: { type: "number", description: "Number of results", default: 10 }
        },
        required: ["query"]
      }
    },
    
    // Migration Operations
    {
      name: "scout_run_migration",
      description: "Run a SQL migration on the Scout schema",
      inputSchema: {
        type: "object",
        properties: {
          sql: { type: "string", description: "SQL migration to execute" },
          description: { type: "string", description: "Migration description" }
        },
        required: ["sql"]
      }
    },
    {
      name: "scout_get_schema_info",
      description: "Get information about Scout schema tables",
      inputSchema: {
        type: "object",
        properties: {
          table_name: { type: "string", description: "Table name to inspect (optional)" }
        }
      }
    }
  ];
  
  constructor() {
    this.server = new Server(
      {
        name: "supabase-scout-mcp",
        version: "1.0.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );
    
    this.setupHandlers();
    this.initializeSupabase();
  }
  
  private initializeSupabase() {
    const supabaseUrl = process.env.SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;
    
    if (!supabaseUrl || !supabaseKey) {
      console.error("Missing Supabase credentials. Please set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY");
      return;
    }
    
    this.supabase = createClient(supabaseUrl, supabaseKey);
    console.log("Supabase client initialized");
  }
  
  private setupHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: this.tools,
      };
    });
    
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      if (!this.supabase) {
        throw new McpError(
          ErrorCode.InternalError,
          "Supabase client not initialized"
        );
      }
      
      const { name, arguments: args } = request.params;
      
      try {
        switch (name) {
          // Session History Operations
          case "scout_create_session":
            return await this.createSession(args as any);
          case "scout_get_sessions":
            return await this.getSessions(args as any);
          
          // Agent Operations
          case "scout_register_agent":
            return await this.registerAgent(args as any);
          case "scout_list_agents":
            return await this.listAgents(args as any);
          case "scout_update_agent_status":
            return await this.updateAgentStatus(args as any);
          
          // Event Operations
          case "scout_create_event":
            return await this.createEvent(args as any);
          case "scout_get_events":
            return await this.getEvents(args as any);
          case "scout_mark_event_processed":
            return await this.markEventProcessed(args as any);
          
          // Knowledge Base Operations
          case "scout_add_knowledge":
            return await this.addKnowledge(args as any);
          case "scout_search_knowledge":
            return await this.searchKnowledge(args as any);
          
          // Migration Operations
          case "scout_run_migration":
            return await this.runMigration(args as any);
          case "scout_get_schema_info":
            return await this.getSchemaInfo(args as any);
          
          default:
            throw new McpError(
              ErrorCode.MethodNotFound,
              `Unknown tool: ${name}`
            );
        }
      } catch (error: any) {
        throw new McpError(
          ErrorCode.InternalError,
          error.message || "Tool execution failed"
        );
      }
    });
  }
  
  // Session History Methods
  private async createSession(args: any) {
    const { data, error } = await this.supabase!
      .from('scout.session_history')
      .insert({
        user_id: args.user_id,
        message_type: args.message_type,
        content: args.content,
        metadata: args.metadata
      })
      .select()
      .single();
    
    if (error) throw error;
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(data, null, 2)
      }]
    };
  }
  
  private async getSessions(args: any) {
    let query = this.supabase!
      .from('scout.session_history')
      .select('*')
      .order('timestamp', { ascending: false });
    
    if (args.user_id) {
      query = query.eq('user_id', args.user_id);
    }
    if (args.session_id) {
      query = query.eq('session_id', args.session_id);
    }
    
    const { data, error } = await query.limit(args.limit || 10);
    
    if (error) throw error;
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(data, null, 2)
      }]
    };
  }
  
  // Agent Methods
  private async registerAgent(args: any) {
    const { data, error } = await this.supabase!
      .from('scout.agents')
      .insert({
        name: args.name,
        type: args.type,
        capabilities: args.capabilities,
        configuration: args.configuration,
        status: args.status || 'active'
      })
      .select()
      .single();
    
    if (error) throw error;
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(data, null, 2)
      }]
    };
  }
  
  private async listAgents(args: any) {
    let query = this.supabase!
      .from('scout.agents')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (args.status) {
      query = query.eq('status', args.status);
    }
    if (args.type) {
      query = query.eq('type', args.type);
    }
    
    const { data, error } = await query;
    
    if (error) throw error;
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(data, null, 2)
      }]
    };
  }
  
  private async updateAgentStatus(args: any) {
    const { data, error } = await this.supabase!
      .from('scout.agents')
      .update({ 
        status: args.status,
        updated_at: new Date().toISOString()
      })
      .eq('name', args.name)
      .select()
      .single();
    
    if (error) throw error;
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(data, null, 2)
      }]
    };
  }
  
  // Event Methods
  private async createEvent(args: any) {
    const { data, error } = await this.supabase!
      .from('scout.events')
      .insert({
        event_type: args.event_type,
        source: args.source,
        payload: args.payload
      })
      .select()
      .single();
    
    if (error) throw error;
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(data, null, 2)
      }]
    };
  }
  
  private async getEvents(args: any) {
    let query = this.supabase!
      .from('scout.events')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (args.event_type) {
      query = query.eq('event_type', args.event_type);
    }
    if (args.processed !== undefined) {
      query = query.eq('processed', args.processed);
    }
    
    const { data, error } = await query.limit(args.limit || 10);
    
    if (error) throw error;
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(data, null, 2)
      }]
    };
  }
  
  private async markEventProcessed(args: any) {
    const { data, error } = await this.supabase!
      .from('scout.events')
      .update({ processed: true })
      .eq('event_id', args.event_id)
      .select()
      .single();
    
    if (error) throw error;
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(data, null, 2)
      }]
    };
  }
  
  // Knowledge Base Methods
  private async addKnowledge(args: any) {
    const { data, error } = await this.supabase!
      .from('scout.knowledge_base')
      .insert({
        title: args.title,
        content: args.content,
        metadata: args.metadata,
        source_url: args.source_url
      })
      .select()
      .single();
    
    if (error) throw error;
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(data, null, 2)
      }]
    };
  }
  
  private async searchKnowledge(args: any) {
    // Use text search on title and content
    const { data, error } = await this.supabase!
      .from('scout.knowledge_base')
      .select('*')
      .or(`title.ilike.%${args.query}%,content.ilike.%${args.query}%`)
      .limit(args.limit || 10);
    
    if (error) throw error;
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(data, null, 2)
      }]
    };
  }
  
  // Migration Methods
  private async runMigration(args: any) {
    // Execute raw SQL migration
    const { data, error } = await this.supabase!
      .rpc('exec_sql', { sql_query: args.sql });
    
    if (error) throw error;
    
    return {
      content: [{
        type: "text",
        text: `Migration executed successfully: ${args.description || 'No description provided'}`
      }]
    };
  }
  
  private async getSchemaInfo(args: any) {
    let sql = `
      SELECT 
        table_name,
        column_name,
        data_type,
        is_nullable,
        column_default
      FROM information_schema.columns
      WHERE table_schema = 'scout'
    `;
    
    if (args.table_name) {
      sql += ` AND table_name = '${args.table_name}'`;
    }
    
    sql += ' ORDER BY table_name, ordinal_position';
    
    const { data, error } = await this.supabase!
      .rpc('exec_sql', { sql_query: sql });
    
    if (error) throw error;
    
    return {
      content: [{
        type: "text",
        text: JSON.stringify(data, null, 2)
      }]
    };
  }
  
  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Supabase Scout MCP server running on stdio");
  }
}

// Main execution
const server = new SupabaseScoutMCP();
server.run().catch(console.error);
