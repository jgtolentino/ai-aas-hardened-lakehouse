#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { execFileSync } from 'node:child_process';
import { Pool } from 'pg';

// Keychain integration for secure credential retrieval
function getFromKeychain(accountName) {
  try {
    return execFileSync('security', [
      'find-generic-password',
      '-s', 'ai-aas-hardened-lakehouse.supabase',
      '-a', accountName,
      '-w'
    ], { encoding: 'utf8' }).trim();
  } catch (error) {
    return '';
  }
}

// Get DATABASE_URL from keychain or environment (prefer keychain)
const DATABASE_URL = process.env.DATABASE_URL || getFromKeychain('DATABASE_URL');
const ALLOW_WRITE = process.env.ALLOW_WRITE === 'true' || getFromKeychain('ALLOW_WRITE') === 'true';

if (!DATABASE_URL) {
  console.error('Error: DATABASE_URL missing. Please store in Keychain:');
  console.error('security add-generic-password -s "ai-aas-hardened-lakehouse.supabase" -a "DATABASE_URL" -w "postgresql://..."');
  process.exit(1);
}

// Initialize PostgreSQL connection pool with security settings
const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  max: 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
  statement_timeout: 30000
});

// Test connection on startup
try {
  const client = await pool.connect();
  await client.query('SELECT 1');
  client.release();
  console.error('Database connection established successfully');
} catch (error) {
  console.error('Failed to connect to database:', error.message);
  process.exit(1);
}

// Create MCP server
const server = new Server(
  {
    name: 'scout-analytics-mcp',
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
      
      if (!query || typeof query !== 'string') {
        throw new Error('Query parameter is required and must be a string');
      }

      const lowerQuery = query.toLowerCase().trim();

      // Safety rails: Block dangerous operations unless ALLOW_WRITE=true
      const dangerousPatterns = [
        'drop\\s+(table|database|schema|index|view)',
        'alter\\s+(table|database|schema)',
        'truncate\\s+table',
        'delete\\s+from',
        'update\\s+.*set',
        'insert\\s+into',
        'create\\s+(table|database|schema)',
        'grant\\s+',
        'revoke\\s+',
        'set\\s+role'
      ];

      if (!ALLOW_WRITE) {
        for (const pattern of dangerousPatterns) {
          if (new RegExp(pattern, 'i').test(lowerQuery)) {
            throw new Error(`Write operation blocked: ${pattern.replace('\\\\s+', ' ')}. Set ALLOW_WRITE=true if needed.`);
          }
        }
      }

      // Query timeout and row limit for safety
      const MAX_ROWS = 200;
      const QUERY_TIMEOUT = 30000; // 30 seconds

      let finalQuery = query;
      
      // Add LIMIT if it's a SELECT and doesn't already have one
      if (lowerQuery.startsWith('select') && !lowerQuery.includes('limit')) {
        finalQuery = `${query} LIMIT ${MAX_ROWS}`;
      }

      // Execute with timeout
      const client = await pool.connect();
      let result;
      
      try {
        // Set statement timeout for this session
        await client.query(`SET statement_timeout = ${QUERY_TIMEOUT}`);
        result = await client.query(finalQuery);
      } finally {
        client.release();
      }

      // Limit rows returned
      let rows = result.rows;
      if (rows && rows.length > MAX_ROWS) {
        rows = rows.slice(0, MAX_ROWS);
        console.error(`Query returned ${result.rows.length} rows, limited to ${MAX_ROWS}`);
      }

      return {
        content: [
          {
            type: 'text',
            text: `Query executed successfully (${rows ? rows.length : 0} rows):\n${JSON.stringify(rows, null, 2)}`
          }
        ]
      };
    } catch (error) {
      // Don't log sensitive information
      const safeMessage = error.message.replace(/password[=:]\s*\S+/gi, 'password=***');
      return {
        content: [
          {
            type: 'text',
            text: `Error executing SQL: ${safeMessage}`
          }
        ]
      };
    }
  }

  if (name === 'list_tables') {
    try {
      const client = await pool.connect();
      let result;
      
      try {
        result = await client.query(`
          SELECT table_name, table_type 
          FROM information_schema.tables 
          WHERE table_schema = 'public' 
          ORDER BY table_name
        `);
      } finally {
        client.release();
      }

      const tables = result.rows;
      return {
        content: [
          {
            type: 'text',
            text: `Tables in database (${tables.length} found):\n${tables.map(t => `- ${t.table_name} (${t.table_type})`).join('\n')}`
          }
        ]
      };
    } catch (error) {
      const safeMessage = error.message.replace(/password[=:]\s*\S+/gi, 'password=***');
      return {
        content: [
          {
            type: 'text',
            text: `Error listing tables: ${safeMessage}`
          }
        ]
      };
    }
  }

  if (name === 'describe_table') {
    try {
      const { table_name } = args;
      
      if (!table_name || typeof table_name !== 'string') {
        throw new Error('table_name parameter is required and must be a string');
      }

      // Sanitize table name to prevent injection
      if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(table_name)) {
        throw new Error('Invalid table name format');
      }
      
      const client = await pool.connect();
      let result;
      
      try {
        result = await client.query(`
          SELECT 
            column_name, 
            data_type, 
            is_nullable, 
            column_default,
            ordinal_position
          FROM information_schema.columns 
          WHERE table_schema = 'public' 
            AND table_name = $1
          ORDER BY ordinal_position
        `, [table_name]);
      } finally {
        client.release();
      }

      const columns = result.rows;
      
      if (columns.length === 0) {
        return {
          content: [
            {
              type: 'text',
              text: `Table '${table_name}' not found or has no accessible columns`
            }
          ]
        };
      }

      return {
        content: [
          {
            type: 'text',
            text: `Table '${table_name}' structure (${columns.length} columns):\n${JSON.stringify(columns, null, 2)}`
          }
        ]
      };
    } catch (error) {
      const safeMessage = error.message.replace(/password[=:]\s*\S+/gi, 'password=***');
      return {
        content: [
          {
            type: 'text',
            text: `Error describing table: ${safeMessage}`
          }
        ]
      };
    }
  }

  // Health check tool for self-testing
  if (name === 'health_check') {
    try {
      const client = await pool.connect();
      let results = {
        database_connection: false,
        read_access: false,
        table_count: 0,
        rls_info: 'unknown'
      };
      
      try {
        // Test basic connection
        await client.query('SELECT 1');
        results.database_connection = true;

        // Test read access
        const tableResult = await client.query(`
          SELECT COUNT(*) as count 
          FROM information_schema.tables 
          WHERE table_schema = 'public'
        `);
        results.table_count = parseInt(tableResult.rows[0].count);
        results.read_access = true;

        // Check RLS status
        const rlsResult = await client.query(`
          SELECT COUNT(*) as count 
          FROM pg_tables 
          WHERE schemaname = 'public' 
            AND rowsecurity = true
        `);
        results.rls_info = `${rlsResult.rows[0].count} tables have RLS enabled`;

      } finally {
        client.release();
      }

      return {
        content: [
          {
            type: 'text',
            text: `Health Check Results:\n${JSON.stringify(results, null, 2)}`
          }
        ]
      };
    } catch (error) {
      const safeMessage = error.message.replace(/password[=:]\s*\S+/gi, 'password=***');
      return {
        content: [
          {
            type: 'text',
            text: `Health check failed: ${safeMessage}`
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
        description: 'Execute SQL query on Scout database (read-only by default, max 200 rows)',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'SQL query to execute (SELECT statements recommended for safety, 30s timeout)'
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
        description: 'Describe structure of a specific table including columns and data types',
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
        name: 'health_check',
        description: 'Verify database connection and access permissions',
        inputSchema: {
          type: 'object',
          properties: {}
        }
      }
    ]
  };
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Scout Analytics MCP server started successfully');
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});