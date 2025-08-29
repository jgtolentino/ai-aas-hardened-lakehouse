#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { createClient } from '@supabase/supabase-js';

// Initialize Supabase client
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('Missing Supabase credentials. Set SUPABASE_URL and SUPABASE_KEY environment variables.');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// Create MCP server
const server = new Server(
  {
    name: 'supabase-mcp',
    version: '1.0.0',
  },
  {
    capabilities: {
      resources: {},
      tools: {
        querySupabase: {
          name: 'query_supabase',
          description: 'Execute a Supabase query',
          inputSchema: {
            type: 'object',
            properties: {
              table: {
                type: 'string',
                description: 'Table name to query'
              },
              select: {
                type: 'string',
                description: 'Columns to select (default: *)'
              },
              where: {
                type: 'object',
                description: 'Filter conditions'
              },
              limit: {
                type: 'number',
                description: 'Limit number of results'
              },
              order: {
                type: 'object',
                description: 'Order by configuration'
              }
            },
            required: ['table']
          }
        },
        insertSupabase: {
          name: 'insert_supabase',
          description: 'Insert data into Supabase',
          inputSchema: {
            type: 'object',
            properties: {
              table: {
                type: 'string',
                description: 'Table name to insert into'
              },
              data: {
                type: 'object',
                description: 'Data to insert'
              }
            },
            required: ['table', 'data']
          }
        },
        updateSupabase: {
          name: 'update_supabase',
          description: 'Update data in Supabase',
          inputSchema: {
            type: 'object',
            properties: {
              table: {
                type: 'string',
                description: 'Table name to update'
              },
              data: {
                type: 'object',
                description: 'Data to update'
              },
              where: {
                type: 'object',
                description: 'Filter conditions'
              }
            },
            required: ['table', 'data']
          }
        }
      }
    }
  }
);

// Query tool
server.setRequestHandler('tools/query_supabase', async (params) => {
  try {
    const { table, select = '*', where, limit, order } = params;
    
    let query = supabase.from(table).select(select);
    
    if (where) {
      Object.entries(where).forEach(([column, value]) => {
        query = query.eq(column, value);
      });
    }
    
    if (limit) {
      query = query.limit(limit);
    }
    
    if (order) {
      Object.entries(order).forEach(([column, direction]) => {
        query = query.order(column, { ascending: direction === 'asc' });
      });
    }
    
    const { data, error } = await query;
    
    if (error) {
      return {
        content: [{
          type: 'text',
          text: `Error: ${error.message}`
        }]
      };
    }
    
    return {
      content: [{
        type: 'text',
        text: JSON.stringify(data, null, 2)
      }]
    };
  } catch (error) {
    return {
      content: [{
        type: 'text',
        text: `Unexpected error: ${error.message}`
      }]
    };
  }
});

// Insert tool
server.setRequestHandler('tools/insert_supabase', async (params) => {
  try {
    const { table, data } = params;
    
    const { data: result, error } = await supabase
      .from(table)
      .insert(data)
      .select();
    
    if (error) {
      return {
        content: [{
          type: 'text',
          text: `Error: ${error.message}`
        }]
      };
    }
    
    return {
      content: [{
        type: 'text',
        text: `Inserted successfully: ${JSON.stringify(result, null, 2)}`
      }]
    };
  } catch (error) {
    return {
      content: [{
        type: 'text',
        text: `Unexpected error: ${error.message}`
      }]
    };
  }
});

// Update tool
server.setRequestHandler('tools/update_supabase', async (params) => {
  try {
    const { table, data, where } = params;
    
    let query = supabase.from(table).update(data);
    
    if (where) {
      Object.entries(where).forEach(([column, value]) => {
        query = query.eq(column, value);
      });
    }
    
    const { data: result, error } = await query.select();
    
    if (error) {
      return {
        content: [{
          type: 'text',
          text: `Error: ${error.message}`
        }]
      };
    }
    
    return {
      content: [{
        type: 'text',
        text: `Updated successfully: ${JSON.stringify(result, null, 2)}`
      }]
    };
  } catch (error) {
    return {
      content: [{
        type: 'text',
        text: `Unexpected error: ${error.message}`
      }]
    };
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Supabase MCP server running on stdio');
}

main().catch(console.error);
