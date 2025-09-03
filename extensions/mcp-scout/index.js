#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { createClient } from '@supabase/supabase-js';
import { execSync } from 'child_process';

// Get Supabase PAT from macOS Keychain
function getSupabasePAT() {
  try {
    const token = execSync(
      'security find-generic-password -a "supabase" -s "supabase-pat" -w',
      { encoding: 'utf8' }
    ).trim();
    return token;
  } catch (error) {
    console.error('Failed to retrieve Supabase PAT from Keychain:', error.message);
    process.exit(1);
  }
}

// Initialize Supabase client
const SUPABASE_URL = 'https://vmdyznckaqmdjzxnfitl.supabase.co';
const SUPABASE_PAT = getSupabasePAT();

const supabase = createClient(SUPABASE_URL, SUPABASE_PAT, {
  auth: {
    persistSession: false,
    autoRefreshToken: false
  }
});

// Create MCP server
const server = new Server(
  {
    name: 'mcp-scout',
    version: '1.0.0'
  },
  {
    capabilities: {
      tools: {}
    }
  }
);

// Execute SQL tool
server.setRequestHandler('tools/call', async (request) => {
  const { name, arguments: args } = request.params;

  if (name === 'execute_sql') {
    try {
      const { query } = args;
      
      // Execute raw SQL
      const { data, error } = await supabase.rpc('exec_sql', { 
        sql_query: query 
      });

      if (error) {
        // If RPC doesn't exist, try direct query
        const result = await supabase.from('scout_metrics').select('*').limit(0);
        
        // For DDL operations, we need to use the Management API
        if (query.toLowerCase().includes('create') || 
            query.toLowerCase().includes('alter') || 
            query.toLowerCase().includes('drop')) {
          
          // Execute DDL via Supabase Management API
          const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc`, {
            method: 'POST',
            headers: {
              'apikey': SUPABASE_PAT,
              'Authorization': `Bearer ${SUPABASE_PAT}`,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              query: query
            })
          });

          const result = await response.json();
          return {
            content: [
              {
                type: 'text',
                text: `SQL executed successfully:\n${JSON.stringify(result, null, 2)}`
              }
            ]
          };
        }
        
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`
            }
          ]
        };
      }

      return {
        content: [
          {
            type: 'text',
            text: `Query executed successfully:\n${JSON.stringify(data, null, 2)}`
          }
        ]
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Error executing SQL: ${error.message}`
          }
        ]
      };
    }
  }

  if (name === 'list_tables') {
    try {
      const { data, error } = await supabase
        .from('information_schema.tables')
        .select('table_name')
        .eq('table_schema', 'public');

      if (error) throw error;

      return {
        content: [
          {
            type: 'text',
            text: `Tables in database:\n${data.map(t => `- ${t.table_name}`).join('\n')}`
          }
        ]
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Error listing tables: ${error.message}`
          }
        ]
      };
    }
  }

  if (name === 'describe_table') {
    try {
      const { table_name } = args;
      
      const { data, error } = await supabase
        .from('information_schema.columns')
        .select('column_name, data_type, is_nullable, column_default')
        .eq('table_schema', 'public')
        .eq('table_name', table_name);

      if (error) throw error;

      return {
        content: [
          {
            type: 'text',
            text: `Table ${table_name} structure:\n${JSON.stringify(data, null, 2)}`
          }
        ]
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Error describing table: ${error.message}`
          }
        ]
      };
    }
  }

  throw new Error(`Unknown tool: ${name}`);
});

// List available tools
server.setRequestHandler('tools/list', async () => {
  return {
    tools: [
      {
        name: 'execute_sql',
        description: 'Execute SQL query on Scout database',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'SQL query to execute'
            }
          },
          required: ['query']
        }
      },
      {
        name: 'list_tables',
        description: 'List all tables in the Scout database',
        inputSchema: {
          type: 'object',
          properties: {}
        }
      },
      {
        name: 'describe_table',
        description: 'Describe structure of a specific table',
        inputSchema: {
          type: 'object',
          properties: {
            table_name: {
              type: 'string',
              description: 'Name of the table to describe'
            }
          },
          required: ['table_name']
        }
      }
    ]
  };
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Scout MCP server started successfully');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
