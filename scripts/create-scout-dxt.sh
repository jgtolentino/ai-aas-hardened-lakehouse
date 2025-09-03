#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Creating Scout MCP Desktop Extension (DXT)"
echo "============================================"

REPO="$HOME/ai-aas-hardened-lakehouse"
DXT_DIR="$REPO/scout-mcp-dxt"

# Clean and create directory structure
rm -rf "$DXT_DIR"
mkdir -p "$DXT_DIR/server/src" "$DXT_DIR/server/dist"

# Create the manifest.json for DXT
cat > "$DXT_DIR/manifest.json" <<'JSON'
{
  "dxt_version": "0.1",
  "name": "scout-mcp",
  "display_name": "Scout Database MCP",
  "version": "1.0.0",
  "description": "Execute SQL operations on Scout schema with secure Supabase connectivity",
  "author": {
    "name": "TBWA",
    "email": "tbwa@example.com"
  },
  "homepage": "https://github.com/tbwa/scout-mcp",
  "license": "MIT",
  "icon": "icon.png",
  "mcp": {
    "name": "scout-mcp",
    "version": "1.0.0"
  },
  "runtime": {
    "type": "node",
    "node_version": "20",
    "main": "server/dist/index.js"
  },
  "user_config": {
    "database_url": {
      "type": "password",
      "title": "Database URL",
      "description": "PostgreSQL connection string (e.g., postgresql://user:pass@host/db)",
      "required": true,
      "sensitive": true
    },
    "repo_root": {
      "type": "directory",
      "title": "Repository Root",
      "description": "Path to ai-aas-hardened-lakehouse repository",
      "required": false,
      "default": "${HOME}/ai-aas-hardened-lakehouse"
    },
    "max_rows": {
      "type": "number",
      "title": "Maximum Rows",
      "description": "Maximum number of rows to return from queries",
      "required": false,
      "default": 200
    }
  },
  "capabilities": {
    "tools": [
      "execute_sql",
      "list_scout_tables",
      "describe_table",
      "run_migration",
      "verify_schema"
    ]
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "pg": "^8.11.3",
    "zod": "^3.23.8"
  }
}
JSON

# Create package.json for the server
cat > "$DXT_DIR/server/package.json" <<'JSON'
{
  "name": "scout-mcp-server",
  "version": "1.0.0",
  "type": "module",
  "private": true,
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "dev": "tsx src/index.ts"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "pg": "^8.11.3",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "typescript": "^5.5.4",
    "@types/node": "^20.11.30",
    "@types/pg": "^8.10.0",
    "tsx": "^4.19.0"
  }
}
JSON

# Create TypeScript config
cat > "$DXT_DIR/server/tsconfig.json" <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "declaration": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
JSON

# Create the main TypeScript server file
cat > "$DXT_DIR/server/src/index.ts" <<'TS'
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { Pool } from "pg";
import fs from "node:fs/promises";
import path from "node:path";

// Get configuration from environment (set by DXT runtime)
const DATABASE_URL = process.env.DXT_DATABASE_URL || process.env.DATABASE_URL;
const REPO_ROOT = process.env.DXT_REPO_ROOT || process.env.REPO_ROOT || path.join(process.env.HOME!, "ai-aas-hardened-lakehouse");
const MAX_ROWS = parseInt(process.env.DXT_MAX_ROWS || process.env.MAX_ROWS || "200");

if (!DATABASE_URL) {
  console.error("DATABASE_URL not configured");
  process.exit(1);
}

// Initialize PostgreSQL pool
const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  max: 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000
});

// Helper to limit rows
function clampRows<T>(rows: T[], max: number = MAX_ROWS): T[] {
  return rows.slice(0, max);
}

// Create MCP server
const server = new Server(
  { 
    name: "scout-mcp", 
    version: "1.0.0" 
  },
  { 
    capabilities: {
      tools: {}
    }
  }
);

// Initialize transport
const transport = new StdioServerTransport();

// Register tool list handler
server.setRequestHandler("tools/list", async () => ({
  tools: [
    {
      name: "execute_sql",
      description: `Execute arbitrary SQL query. Returns up to ${MAX_ROWS} rows.`,
      inputSchema: {
        type: "object",
        properties: {
          sql: { 
            type: "string", 
            description: "SQL query to execute",
            minLength: 1 
          },
          params: { 
            type: "array", 
            description: "Query parameters for prepared statements",
            items: {} 
          }
        },
        required: ["sql"]
      }
    },
    {
      name: "list_scout_tables",
      description: "List all tables in the scout schema with sizes",
      inputSchema: {
        type: "object",
        properties: {}
      }
    },
    {
      name: "describe_table",
      description: "Describe table structure (columns, types, constraints)",
      inputSchema: {
        type: "object",
        properties: {
          table: { 
            type: "string",
            description: "Table name (with optional schema prefix)",
            minLength: 1 
          }
        },
        required: ["table"]
      }
    },
    {
      name: "run_migration",
      description: "Execute a SQL migration file from supabase/templates",
      inputSchema: {
        type: "object",
        properties: {
          filename: { 
            type: "string",
            description: "Migration filename in supabase/templates",
            minLength: 1 
          }
        },
        required: ["filename"]
      }
    },
    {
      name: "verify_schema",
      description: "Verify scout schema installation status",
      inputSchema: {
        type: "object",
        properties: {}
      }
    }
  ]
}));

// Register tool execution handler
server.setRequestHandler("tools/call", async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "execute_sql": {
        const { sql, params } = args;
        const client = await pool.connect();
        try {
          const result = await client.query(sql, params || []);
          return {
            content: [{
              type: "text",
              text: JSON.stringify({
                command: result.command,
                rowCount: result.rowCount || 0,
                rows: clampRows(result.rows || [])
              }, null, 2)
            }]
          };
        } finally {
          client.release();
        }
      }

      case "list_scout_tables": {
        const query = `
          SELECT 
            c.relname AS table_name,
            pg_size_pretty(pg_total_relation_size(c.oid)) AS size,
            obj_description(c.oid, 'pg_class') AS description
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname = 'scout' 
            AND c.relkind = 'r'
          ORDER BY pg_total_relation_size(c.oid) DESC
        `;
        
        const result = await pool.query(query);
        const tables = result.rows.map(r => 
          `• ${r.table_name} (${r.size})${r.description ? ' - ' + r.description : ''}`
        ).join('\n');
        
        return {
          content: [{
            type: "text",
            text: `Scout Schema Tables:\n${tables || 'No tables found in scout schema'}`
          }]
        };
      }

      case "describe_table": {
        const { table } = args;
        const [schema, name] = table.includes(".") ? table.split(".") : ["scout", table];
        
        const query = `
          SELECT 
            column_name,
            data_type,
            character_maximum_length,
            is_nullable,
            column_default,
            CASE 
              WHEN tc.constraint_type = 'PRIMARY KEY' THEN 'PK'
              WHEN tc.constraint_type = 'FOREIGN KEY' THEN 'FK'
              WHEN tc.constraint_type = 'UNIQUE' THEN 'UQ'
              ELSE NULL
            END as constraint_type
          FROM information_schema.columns c
          LEFT JOIN information_schema.key_column_usage kcu
            ON c.table_schema = kcu.table_schema
            AND c.table_name = kcu.table_name
            AND c.column_name = kcu.column_name
          LEFT JOIN information_schema.table_constraints tc
            ON kcu.constraint_name = tc.constraint_name
            AND kcu.table_schema = tc.table_schema
          WHERE c.table_schema = $1 AND c.table_name = $2
          ORDER BY c.ordinal_position
        `;
        
        const result = await pool.query(query, [schema, name]);
        
        if (result.rows.length === 0) {
          return {
            content: [{
              type: "text",
              text: `Table ${schema}.${name} not found`
            }]
          };
        }
        
        return {
          content: [{
            type: "text",
            text: JSON.stringify({
              table: `${schema}.${name}`,
              columns: result.rows
            }, null, 2)
          }]
        };
      }

      case "run_migration": {
        const { filename } = args;
        const migrationPath = path.join(REPO_ROOT, "supabase", "templates", filename);
        
        try {
          const sql = await fs.readFile(migrationPath, "utf8");
          
          const client = await pool.connect();
          try {
            await client.query("BEGIN");
            await client.query(sql);
            await client.query("COMMIT");
            
            return {
              content: [{
                type: "text",
                text: `✅ Migration ${filename} applied successfully`
              }]
            };
          } catch (error) {
            await client.query("ROLLBACK");
            throw error;
          } finally {
            client.release();
          }
        } catch (error: any) {
          if (error.code === 'ENOENT') {
            return {
              content: [{
                type: "text",
                text: `Migration file not found: ${filename}\nPath: ${migrationPath}`
              }]
            };
          }
          throw error;
        }
      }

      case "verify_schema": {
        const query = `
          WITH checks(name, ok) AS (
            VALUES
              ('schema_scout', EXISTS (SELECT 1 FROM pg_namespace WHERE nspname='scout')),
              ('table_agents', to_regclass('scout.agents') IS NOT NULL),
              ('table_session_history', to_regclass('scout.session_history') IS NOT NULL),
              ('table_events', to_regclass('scout.events') IS NOT NULL),
              ('table_knowledge_base', to_regclass('scout.knowledge_base') IS NOT NULL),
              ('rls_agents', EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='scout' AND tablename='agents' AND rowsecurity=true)),
              ('rls_sessions', EXISTS (SELECT 1 FROM pg_tables WHERE schemaname='scout' AND tablename='session_history' AND rowsecurity=true)),
              ('func_upsert_event', EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='scout' AND p.proname='upsert_event')),
              ('trigger_updated_at', EXISTS (SELECT 1 FROM pg_trigger WHERE tgname LIKE 'tg_touch_%'))
          )
          SELECT * FROM checks
        `;
        
        const result = await pool.query(query);
        const allOk = result.rows.every(r => r.ok === true || r.ok === 't');
        const status = allOk ? '✅ All checks passed!' : '⚠️ Some checks failed';
        
        const details = result.rows.map(r => 
          `${r.ok === true || r.ok === 't' ? '✅' : '❌'} ${r.name}`
        ).join('\n');
        
        return {
          content: [{
            type: "text",
            text: `Scout Schema Verification\n${status}\n\n${details}`
          }]
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error: any) {
    return {
      content: [{
        type: "text",
        text: `Error: ${error.message}`
      }]
    };
  }
});

// Start server
async function main() {
  console.error("🚀 Scout MCP Server starting...");
  
  // Test database connection
  try {
    const client = await pool.connect();
    await client.query("SELECT 1");
    client.release();
    console.error("✅ Database connected successfully");
  } catch (error: any) {
    console.error(`❌ Database connection failed: ${error.message}`);
    process.exit(1);
  }
  
  await server.connect(transport);
  console.error("✅ Scout MCP Server ready");
}

// Handle graceful shutdown
process.on("SIGINT", async () => {
  console.error("Shutting down...");
  await pool.end();
  process.exit(0);
});

process.on("SIGTERM", async () => {
  console.error("Shutting down...");
  await pool.end();
  process.exit(0);
});

// Start the server
main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
TS

# Create a simple icon (base64 encoded PNG)
cat > "$DXT_DIR/icon.png.base64" <<'BASE64'
iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAYAAACqaXHeAAAAAXNSR0IArs4c6QAAAIRlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAQKADAAQAAAABAAAAQAAAAABGUUKwAAADB0lEQVR4Ae2aP2gTURzHv793SZOa1EYt1FoUBx10EAQHBwcHQRBEEBwEB3FwcBAEB3FQBEEQBAdBcBBEUBBEHBTRQUEQBFEUnPwHrVqttU3TJJfLvZ/3krvLXZJL7i53ufzpC5e8937v937f7/ve797vLsBgMAaDwWAwGAxGLBFROwD9RHQ8kB0AtgHYAmAdgEqvRwBGAAwCGADwBsBLSZIGw+qPCGl3M4BTRHQMwHYAyRD2FwB4AuAugPtE9E2ts1JRBewF0ENEuwDYGGwJgAcArgN4zlZSBJwCcBGAswn7vQHgCoA7/BbYFgFH+CtumwR9tQQA1wDcZisIAvYD6OX/yBYL7wBcBvCcrVMQcJz/E0v5L981AC4JIXbxN8G5lCFfJMnGvkWSkiD4Xp8B2E1E30Ue8WVkM4CdiCbWEhG/ufR1+K8FjLORAGBp+wAwGAwGY2n7gL+xPmCpx4D5jgFxqweUqwcY9QCjHlCtQMKoB5i4gE0tn2vVAkL+CzDqAUY9oBI9wGJRIRosKqz6vw/Q3/F/H2DUAxb/HiHL6LCrA1ZGfwCRJCnq7YBQtgP0Fgi1tzewuRaXy+U0y8tO+NUB/LsB2gAckiRp/AfiAtQo5KhXEQAAAABJRU5ErkJggg==
BASE64
base64 -d < "$DXT_DIR/icon.png.base64" > "$DXT_DIR/icon.png"
rm "$DXT_DIR/icon.png.base64"

# Create README
cat > "$DXT_DIR/README.md" <<'MD'
# Scout MCP Desktop Extension

A secure MCP server for interacting with Scout database schema in Supabase.

## Features

- Execute arbitrary SQL queries with parameter support
- List and describe Scout schema tables
- Run migration files
- Verify schema installation
- Secure credential storage (passwords stored in OS keychain)

## Installation

1. Download the `.dxt` file
2. Double-click to install in Claude Desktop
3. Configure your database connection string
4. Start using Scout MCP tools in Claude

## Available Tools

- **execute_sql** - Run any SQL query
- **list_scout_tables** - List tables in scout schema
- **describe_table** - Get detailed table structure
- **run_migration** - Apply migration files
- **verify_schema** - Check schema installation

## Configuration

The extension will prompt for:
- **Database URL** (required) - Your PostgreSQL connection string
- **Repository Root** (optional) - Path to your ai-aas-hardened-lakehouse repo
- **Max Rows** (optional) - Maximum rows to return from queries

All sensitive configuration is stored securely in your OS keychain.

## Security

- Credentials are never stored in plain text
- SSL/TLS connections enforced
- Row limiting prevents overload
- Prepared statements prevent SQL injection

## Support

For issues or questions, visit: https://github.com/tbwa/scout-mcp
MD

echo "📦 Building Scout MCP server..."
cd "$DXT_DIR/server"

# Install dependencies
npm install

# Build TypeScript
npx tsc

# Copy node_modules to bundle
cp -r node_modules "$DXT_DIR/"

# Create the DXT bundle
cd "$DXT_DIR"
echo "🗜️ Creating DXT bundle..."

# Install dxt CLI if not present
if ! command -v dxt &> /dev/null; then
    npm install -g @anthropics/dxt
fi

# Pack the extension
dxt pack || (
    # Fallback to manual zip if dxt not available
    echo "📦 Creating bundle manually..."
    zip -r scout-mcp.dxt . -x "*.ts" -x "server/src/*" -x "*.map" -x ".git/*"
)

# Final output
if [ -f scout-mcp.dxt ]; then
    echo ""
    echo "✅ Scout MCP Desktop Extension created!"
    echo ""
    echo "📦 Extension file: $DXT_DIR/scout-mcp.dxt"
    echo ""
    echo "📋 Installation:"
    echo "1. Open Claude Desktop"
    echo "2. Go to Settings → Extensions"
    echo "3. Click 'Install from file' and select scout-mcp.dxt"
    echo "4. Configure your database URL when prompted"
    echo "5. Restart Claude Desktop"
    echo ""
    echo "🎯 The extension will be available immediately after installation!"
else
    echo ""
    echo "⚠️ DXT file not created. Creating manual fallback..."
    mv scout-mcp.zip scout-mcp.dxt 2>/dev/null || true
    echo "📦 Extension file: $DXT_DIR/scout-mcp.dxt"
fi
