#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import pg from 'pg';
import { execSync } from 'child_process';

const { Client } = pg;

// Get Supabase connection details from Keychain
function getSupabaseCredentials() {
  try {
    const pat = execSync(
      'security find-generic-password -a "supabase" -s "supabase-pat" -w',
      { encoding: 'utf8' }
    ).trim();
    
    // Parse the connection string from environment or use defaults
    return {
      host: 'aws-0-us-west-1.pooler.supabase.com',
      port: 5432,
      database: 'postgres',
      user: 'postgres.vmdyznckaqmdjzxnfitl',
      password: pat,
      ssl: { rejectUnauthorized: false }
    };
  } catch (error) {
    console.error('Failed to retrieve credentials from Keychain:', error.message);
    process.exit(1);
  }
}

// Initialize PostgreSQL client
const credentials = getSupabaseCredentials();
let client = null;

async function ensureConnection() {
  if (!client) {
    client = new Client(credentials);
    await client.connect();
  }
}

// Create MCP server
const server = new Server(
  {
    name: 'mcp-scout-postgres',
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

  await ensureConnection();

  if (name === 'execute_sql') {
    try {
      const { query } = args;
      const result = await client.query(query);
      
      // Format response based on query type
      let response = '';
      
      if (result.command === 'SELECT') {
        response = `Rows returned: ${result.rowCount}\n\n${JSON.stringify(result.rows, null, 2)}`;
      } else if (result.command === 'INSERT' || result.command === 'UPDATE' || result.command === 'DELETE') {
        response = `${result.command} affected ${result.rowCount} rows`;
        if (result.rows.length > 0) {
          response += `\n\nReturned:\n${JSON.stringify(result.rows, null, 2)}`;
        }
      } else {
        response = `${result.command} executed successfully`;
      }

      return {
        content: [
          {
            type: 'text',
            text: response
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

  if (name === 'list_scout_tables') {
    try {
      const query = `
        SELECT 
          tablename as table_name,
          pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
        FROM pg_tables 
        WHERE schemaname = 'public' 
          AND tablename LIKE 'scout_%'
        ORDER BY tablename;
      `;
      
      const result = await client.query(query);
      
      return {
        content: [
          {
            type: 'text',
            text: `Scout tables in database:\n${result.rows.map(r => `- ${r.table_name} (${r.size})`).join('\n')}`
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
      
      const query = `
        SELECT 
          column_name,
          data_type,
          character_maximum_length,
          is_nullable,
          column_default
        FROM information_schema.columns
        WHERE table_schema = 'public' 
          AND table_name = $1
        ORDER BY ordinal_position;
      `;
      
      const result = await client.query(query, [table_name]);
      
      return {
        content: [
          {
            type: 'text',
            text: `Table ${table_name} structure:\n${JSON.stringify(result.rows, null, 2)}`
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

  if (name === 'run_migration') {
    try {
      const { migration_file } = args;
      
      // Read migration file
      const fs = await import('fs');
      const path = await import('path');
      
      const migrationPath = path.join('/Users/tbwa/ai-aas-hardened-lakehouse/supabase/migrations', migration_file);
      const migrationSQL = fs.readFileSync(migrationPath, 'utf8');
      
      // Execute migration
      await client.query('BEGIN');
      try {
        await client.query(migrationSQL);
        await client.query('COMMIT');
        
        return {
          content: [
            {
              type: 'text',
              text: `Migration ${migration_file} executed successfully`
            }
          ]
        };
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Error running migration: ${error.message}`
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
        description: 'Execute any SQL query on Scout database',
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
        name: 'list_scout_tables',
        description: 'List all scout_ prefixed tables in the database',
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
      },
      {
        name: 'run_migration',
        description: 'Run a migration file from the supabase/migrations directory',
        inputSchema: {
          type: 'object',
          properties: {
            migration_file: {
              type: 'string',
              description: 'Name of the migration file (e.g., 001_scout_schema.sql)'
            }
          },
          required: ['migration_file']
        }
      }
    ]
  };
});

// Handle shutdown gracefully
process.on('SIGINT', async () => {
  if (client) {
    await client.end();
  }
  process.exit(0);
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Scout PostgreSQL MCP server started successfully');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
