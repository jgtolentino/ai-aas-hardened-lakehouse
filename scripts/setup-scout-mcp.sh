#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Setting up Scout MCP Server with mcpb"

ROOT="$HOME/ai-aas-hardened-lakehouse"
cd "$ROOT"

# Install mcpb globally if not already installed
if ! command -v mcpb &> /dev/null; then
    echo "📦 Installing mcpb..."
    npm install -g @anthropics/mcpb
fi

# Create MCP server directory
mkdir -p mcp-servers/scout

cd mcp-servers/scout

# Initialize new MCP server project
echo "🔧 Initializing Scout MCP Server..."
cat > package.json <<'EOF'
{
  "name": "@tbwa/scout-mcp",
  "version": "1.0.0",
  "description": "Scout Schema MCP Server for Supabase PostgreSQL",
  "type": "module",
  "main": "dist/index.js",
  "scripts": {
    "build": "mcpb build",
    "dev": "mcpb dev",
    "test": "mcpb test"
  },
  "mcp": {
    "name": "scout-mcp",
    "description": "Execute SQL operations on Scout schema",
    "tools": [
      "execute_sql",
      "list_scout_tables",
      "describe_table",
      "run_migration",
      "verify_schema"
    ]
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "latest",
    "pg": "^8.11.3"
  },
  "devDependencies": {
    "@anthropics/mcpb": "latest",
    "@types/node": "^20.0.0",
    "@types/pg": "^8.10.0",
    "typescript": "^5.0.0"
  }
}
EOF

# Create TypeScript config
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "node",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "allowSyntheticDefaultImports": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF

# Create source directory
mkdir -p src

# Create main MCP server implementation
cat > src/index.ts <<'EOF'
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import pg from 'pg';
import { execSync } from 'child_process';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const { Client } = pg;

interface Credentials {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
  ssl: { rejectUnauthorized: boolean };
}

// Get Supabase credentials from keychain
function getSupabaseCredentials(): Credentials {
  try {
    const pat = execSync(
      'security find-generic-password -a "supabase" -s "supabase-pat" -w',
      { encoding: 'utf8' }
    ).trim();
    
    return {
      host: process.env.SUPABASE_HOST || 'aws-0-us-west-1.pooler.supabase.com',
      port: parseInt(process.env.SUPABASE_PORT || '5432'),
      database: process.env.SUPABASE_DB || 'postgres',
      user: process.env.SUPABASE_USER || 'postgres.vmdyznckaqmdjzxnfitl',
      password: pat,
      ssl: { rejectUnauthorized: false }
    };
  } catch (error: any) {
    console.error('Failed to retrieve credentials from Keychain:', error.message);
    process.exit(1);
  }
}

class ScoutMCPServer {
  private server: Server;
  private client: pg.Client | null = null;
  private credentials: Credentials;

  constructor() {
    this.credentials = getSupabaseCredentials();
    this.server = new Server(
      {
        name: 'scout-mcp',
        version: '1.0.0'
      },
      {
        capabilities: {
          tools: {}
        }
      }
    );

    this.setupHandlers();
  }

  private async ensureConnection(): Promise<void> {
    if (!this.client) {
      this.client = new Client(this.credentials);
      await this.client.connect();
      console.error('✅ Connected to Supabase PostgreSQL');
    }
  }

  private setupHandlers(): void {
    this.server.setRequestHandler('tools/list', async () => ({
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
          description: 'List all scout schema tables with sizes',
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
          description: 'Run a migration file from templates directory',
          inputSchema: {
            type: 'object',
            properties: {
              migration_file: {
                type: 'string',
                description: 'Name of migration file in supabase/templates'
              }
            },
            required: ['migration_file']
          }
        },
        {
          name: 'verify_schema',
          description: 'Verify Scout schema is properly installed',
          inputSchema: {
            type: 'object',
            properties: {}
          }
        }
      ]
    }));

    this.server.setRequestHandler('tools/call', async (request) => {
      const { name, arguments: args } = request.params;
      await this.ensureConnection();

      switch (name) {
        case 'execute_sql':
          return await this.executeSql(args.query);
        case 'list_scout_tables':
          return await this.listScoutTables();
        case 'describe_table':
          return await this.describeTable(args.table_name);
        case 'run_migration':
          return await this.runMigration(args.migration_file);
        case 'verify_schema':
          return await this.verifySchema();
        default:
          throw new Error(`Unknown tool: ${name}`);
      }
    });
  }

  private async executeSql(query: string) {
    try {
      const result = await this.client!.query(query);
      
      let response = '';
      
      if (result.command === 'SELECT') {
        response = `Rows returned: ${result.rowCount}\n\n${JSON.stringify(result.rows, null, 2)}`;
      } else if (['INSERT', 'UPDATE', 'DELETE'].includes(result.command)) {
        response = `${result.command} affected ${result.rowCount} rows`;
        if (result.rows.length > 0) {
          response += `\n\nReturned:\n${JSON.stringify(result.rows, null, 2)}`;
        }
      } else {
        response = `${result.command} executed successfully`;
      }

      return {
        content: [{
          type: 'text',
          text: response
        }]
      };
    } catch (error: any) {
      return {
        content: [{
          type: 'text',
          text: `Error executing SQL: ${error.message}`
        }]
      };
    }
  }

  private async listScoutTables() {
    try {
      const query = `
        SELECT 
          tablename as table_name,
          pg_size_pretty(pg_total_relation_size('scout.'||tablename)) as size
        FROM pg_tables 
        WHERE schemaname = 'scout'
        ORDER BY tablename;
      `;
      
      const result = await this.client!.query(query);
      
      return {
        content: [{
          type: 'text',
          text: `Scout tables:\n${result.rows.map(r => `- ${r.table_name} (${r.size})`).join('\n')}`
        }]
      };
    } catch (error: any) {
      return {
        content: [{
          type: 'text',
          text: `Error listing tables: ${error.message}`
        }]
      };
    }
  }

  private async describeTable(tableName: string) {
    try {
      const query = `
        SELECT 
          column_name,
          data_type,
          character_maximum_length,
          is_nullable,
          column_default
        FROM information_schema.columns
        WHERE table_schema = 'scout' 
          AND table_name = $1
        ORDER BY ordinal_position;
      `;
      
      const result = await this.client!.query(query, [tableName]);
      
      return {
        content: [{
          type: 'text',
          text: `Table scout.${tableName} structure:\n${JSON.stringify(result.rows, null, 2)}`
        }]
      };
    } catch (error: any) {
      return {
        content: [{
          type: 'text',
          text: `Error describing table: ${error.message}`
        }]
      };
    }
  }

  private async runMigration(migrationFile: string) {
    try {
      const migrationPath = path.join(
        process.env.HOME!,
        'ai-aas-hardened-lakehouse',
        'supabase',
        'templates',
        migrationFile
      );
      
      const migrationSQL = await fs.readFile(migrationPath, 'utf8');
      
      await this.client!.query('BEGIN');
      try {
        await this.client!.query(migrationSQL);
        await this.client!.query('COMMIT');
        
        return {
          content: [{
            type: 'text',
            text: `✅ Migration ${migrationFile} executed successfully`
          }]
        };
      } catch (error) {
        await this.client!.query('ROLLBACK');
        throw error;
      }
    } catch (error: any) {
      return {
        content: [{
          type: 'text',
          text: `Error running migration: ${error.message}`
        }]
      };
    }
  }

  private async verifySchema() {
    try {
      const query = `
        WITH checks(name, ok) AS (
          VALUES
            ('schema_scout', EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name='scout')),
            ('table_agents', to_regclass('scout.agents') IS NOT NULL),
            ('table_session_history', to_regclass('scout.session_history') IS NOT NULL),
            ('table_events', to_regclass('scout.events') IS NOT NULL),
            ('table_knowledge_base', to_regclass('scout.knowledge_base') IS NOT NULL),
            ('rls_enabled', EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='scout' AND tablename='agents' AND rowsecurity=true))
        )
        SELECT * FROM checks;
      `;
      
      const result = await this.client!.query(query);
      
      const allOk = result.rows.every(r => r.ok);
      const status = allOk ? '✅ All checks passed!' : '⚠️ Some checks failed';
      
      return {
        content: [{
          type: 'text',
          text: `${status}\n\n${result.rows.map(r => `${r.ok ? '✅' : '❌'} ${r.name}`).join('\n')}`
        }]
      };
    } catch (error: any) {
      return {
        content: [{
          type: 'text',
          text: `Error verifying schema: ${error.message}`
        }]
      };
    }
  }

  async start() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('🚀 Scout MCP Server started successfully');
  }

  async stop() {
    if (this.client) {
      await this.client.end();
    }
  }
}

// Handle shutdown gracefully
const server = new ScoutMCPServer();

process.on('SIGINT', async () => {
  await server.stop();
  process.exit(0);
});

// Start the server
server.start().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
EOF

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Build the MCP server
echo "🔨 Building MCP server..."
npx mcpb build || npx tsc

# Update Claude Desktop config
echo "📝 Updating Claude Desktop configuration..."
CLAUDE_CONFIG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

# Read existing config and update it
if [ -f "$CLAUDE_CONFIG" ]; then
    # Create backup
    cp "$CLAUDE_CONFIG" "$CLAUDE_CONFIG.bak"
    
    # Update config using Node.js
    node -e "
    const fs = require('fs');
    const config = JSON.parse(fs.readFileSync('$CLAUDE_CONFIG', 'utf8'));
    
    // Update or add scout MCP server
    config.mcpServers = config.mcpServers || {};
    config.mcpServers['scout-mcp'] = {
        command: 'node',
        args: ['$ROOT/mcp-servers/scout/dist/index.js']
    };
    
    fs.writeFileSync('$CLAUDE_CONFIG', JSON.stringify(config, null, 2));
    console.log('✅ Claude config updated');
    "
fi

echo "✅ Scout MCP Server setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. First run the template scaffolding:"
echo "   cd $ROOT"
echo "   bash scripts/db/scaffold-scout-templates.sh"
echo ""
echo "2. Apply the templates to your database:"
echo "   bash scripts/db/run-templates.sh --with-seed"
echo ""
echo "3. Restart Claude Desktop to load the new MCP server"
echo ""
echo "Available MCP tools:"
echo "  • execute_sql - Run any SQL query"
echo "  • list_scout_tables - List all scout schema tables"
echo "  • describe_table - Show table structure"
echo "  • run_migration - Execute migration files"
echo "  • verify_schema - Check if schema is properly installed"
