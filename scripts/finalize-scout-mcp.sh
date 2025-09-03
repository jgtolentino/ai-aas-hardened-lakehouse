#!/usr/bin/env bash
set -euo pipefail

REPO="$HOME/ai-aas-hardened-lakehouse"
BIN="$HOME/.local/bin"
SRV="$REPO/mcp-servers/scout"

mkdir -p "$BIN" "$SRV/src" "$REPO/logs"

###############################################################################
# 1) Keychain utilities — add DATABASE_URL support
###############################################################################
# If you already installed kc-* scripts earlier, this just updates them idempotently.

cat > "$BIN/kc-set-supabase.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
svc="${KC_SERVICE:-ai-aas-hardened-lakehouse.supabase}"
set_if(){ local v="$1" val="${!1:-}"; [ -z "$val" ] || security add-generic-password -U -s "$svc" -a "$v" -w "$val" >/dev/null && echo "🔐 $v stored"; }
set_if SUPABASE_PROJECT_REF
set_if SUPABASE_URL
set_if SUPABASE_ANON_KEY
set_if SUPABASE_SERVICE_ROLE_KEY
set_if SUPABASE_JWT_SECRET
set_if SUPABASE_ACCESS_TOKEN
set_if DATABASE_URL
SH
chmod +x "$BIN/kc-set-supabase.sh"

cat > "$BIN/supabase-mcp-secure.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
svc="${KC_SERVICE:-ai-aas-hardened-lakehouse.supabase}"
readkc(){ security find-generic-password -s "$svc" -a "$1" -w 2>/dev/null || true; }

# Minimum for DB connectivity
export DATABASE_URL="${DATABASE_URL:-$(readkc DATABASE_URL)}"

# Optional (some tools may use them)
export SUPABASE_URL="${SUPABASE_URL:-$(readkc SUPABASE_URL)}"
export SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-$(readkc SUPABASE_ANON_KEY)}"
export SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-$(readkc SUPABASE_SERVICE_ROLE_KEY)}"

: "${DATABASE_URL:?Missing DATABASE_URL (store in Keychain under account DATABASE_URL)}"

# Hand off to compiled server
exec node "$HOME/ai-aas-hardened-lakehouse/mcp-servers/scout/dist/index.js" 2>&1 | tee -a "$HOME/ai-aas-hardened-lakehouse/logs/scout-mcp.log"
SH
chmod +x "$BIN/supabase-mcp-secure.sh"

###############################################################################
# 2) Scout MCP server (TypeScript, official SDK; builds with mcpb if available)
###############################################################################
cat > "$SRV/package.json" <<'JSON'
{
  "name": "scout-mcp",
  "version": "0.1.0",
  "type": "module",
  "private": true,
  "scripts": {
    "dev": "tsx src/index.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "zod": "^3.23.8",
    "pg": "^8.11.3"
  },
  "devDependencies": {
    "typescript": "^5.5.4",
    "@types/node": "^20.11.30",
    "@types/pg": "^8.10.0",
    "tsx": "^4.19.0"
  }
}
JSON

cat > "$SRV/tsconfig.json" <<'JSON'
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
    "allowSyntheticDefaultImports": true
  },
  "include": ["src"]
}
JSON

cat > "$SRV/src/index.ts" <<'TS'
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { Pool } from "pg";
import fs from "node:fs/promises";
import path from "node:path";

const DATABASE_URL = process.env.DATABASE_URL;
if (!DATABASE_URL) {
  console.error("DATABASE_URL missing");
  process.exit(1);
}

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

function clamp<T>(arr: T[], n = 200) { return arr.slice(0, n); }

const server = new Server(
  { name: "scout-mcp", version: "0.1.0" },
  { 
    capabilities: {
      tools: {}
    }
  }
);

// Setup transport
const transport = new StdioServerTransport();

// Tool handlers
server.setRequestHandler("tools/list", async () => ({
  tools: [
    {
      name: "execute_sql",
      description: "Execute arbitrary SQL; returns rowCount and up to 200 rows",
      inputSchema: {
        type: "object",
        properties: {
          sql: { type: "string", minLength: 1 },
          params: { type: "array", items: { type: "any" } }
        },
        required: ["sql"]
      }
    },
    {
      name: "list_scout_tables",
      description: "List tables in schema 'scout' with row estimates",
      inputSchema: {
        type: "object",
        properties: {}
      }
    },
    {
      name: "describe_table",
      description: "Describe a table (columns, types, nullability, defaults)",
      inputSchema: {
        type: "object",
        properties: {
          table: { type: "string", minLength: 1 }
        },
        required: ["table"]
      }
    },
    {
      name: "run_migration",
      description: "Execute a SQL file from supabase/templates",
      inputSchema: {
        type: "object",
        properties: {
          filename: { type: "string", minLength: 1 }
        },
        required: ["filename"]
      }
    },
    {
      name: "verify_schema",
      description: "Run verification SQL (scripts/db/verify_scout.sql)",
      inputSchema: {
        type: "object",
        properties: {}
      }
    }
  ]
}));

server.setRequestHandler("tools/call", async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case "execute_sql": {
      const { sql, params } = args;
      const client = await pool.connect();
      try {
        const res = await client.query(sql, params ?? []);
        return {
          content: [{
            type: "text",
            text: JSON.stringify({ 
              ok: true, 
              rowCount: res.rowCount ?? 0, 
              rows: clamp(res.rows ?? []) 
            }, null, 2)
          }]
        };
      } catch (error: any) {
        return {
          content: [{
            type: "text",
            text: `Error: ${error.message}`
          }]
        };
      } finally { 
        client.release(); 
      }
    }

    case "list_scout_tables": {
      const q = `
        select c.relname as table, 
               pg_size_pretty(pg_total_relation_size(c.oid)) as size,
               pg_total_relation_size(c.oid) as bytes
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'scout' and c.relkind='r'
        order by 3 desc`;
      const r = await pool.query(q);
      return {
        content: [{
          type: "text",
          text: `Scout tables:\n${r.rows.map(row => `- ${row.table} (${row.size})`).join('\n')}`
        }]
      };
    }

    case "describe_table": {
      const { table } = args;
      const [schema, name] = table.includes(".") ? table.split(".") : ["public", table];
      const q = `
        select column_name, data_type, is_nullable, column_default
        from information_schema.columns
        where table_schema=$1 and table_name=$2
        order by ordinal_position`;
      const r = await pool.query(q, [schema, name]);
      return {
        content: [{
          type: "text",
          text: JSON.stringify({ 
            table: `${schema}.${name}`, 
            columns: r.rows 
          }, null, 2)
        }]
      };
    }

    case "run_migration": {
      const { filename } = args;
      const root = path.resolve(process.env.REPO_ROOT ?? path.join(process.env.HOME!, "ai-aas-hardened-lakehouse"));
      const file = path.join(root, "supabase", "templates", filename);
      const sql = await fs.readFile(file, "utf8");
      await pool.query(sql);
      return {
        content: [{
          type: "text",
          text: `✅ Migration ${filename} applied successfully`
        }]
      };
    }

    case "verify_schema": {
      const root = path.resolve(process.env.REPO_ROOT ?? path.join(process.env.HOME!, "ai-aas-hardened-lakehouse"));
      const file = path.join(root, "scripts", "db", "verify_scout.sql");
      const sql = await fs.readFile(file, "utf8");
      const r = await pool.query(sql);
      const allOk = r.rows.every((row: any) => row.ok === true || row.ok === 't');
      return {
        content: [{
          type: "text",
          text: `${allOk ? '✅ All checks passed' : '⚠️ Some checks failed'}\n\n${r.rows.map((row: any) => 
            `${row.ok === true || row.ok === 't' ? '✅' : '❌'} ${row.name}`
          ).join('\n')}`
        }]
      };
    }

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
});

// Start server
server.connect(transport).then(() => {
  console.error("Scout MCP server running");
}).catch((e) => {
  console.error("Fatal:", e);
  process.exit(1);
});

// Graceful shutdown
process.on("SIGINT", async () => {
  await pool.end();
  process.exit(0);
});
TS

# Install & build (prefer mcpb if installed; otherwise tsc)
cd "$SRV"
corepack enable >/dev/null 2>&1 || true
if command -v pnpm >/dev/null 2>&1; then
  pnpm install
  if command -v mcpb >/dev/null 2>&1; then mcpb build || pnpm run build; else pnpm run build; fi
else
  npm install
  if command -v mcpb >/dev/null 2>&1; then mcpb build || npm run build; else npm run build; fi
fi

echo "✅ Scout MCP built at $SRV/dist/index.js"
echo "   Launcher: $BIN/supabase-mcp-secure.sh (point Claude here)"
echo ""
echo "📝 Next steps:"
echo "1. Store DATABASE_URL in Keychain:"
echo "   KC_SERVICE=ai-aas-hardened-lakehouse.supabase \\"
echo "   DATABASE_URL='postgresql://...:6543/postgres?sslmode=require' \\"
echo "   $BIN/kc-set-supabase.sh"
echo ""
echo "2. Update Claude Desktop config to use:"
echo "   Command: $BIN/supabase-mcp-secure.sh"
echo ""
echo "3. Test the connection:"
echo "   DATABASE_URL=\"\$(security find-generic-password -s ai-aas-hardened-lakehouse.supabase -a DATABASE_URL -w)\" \\"
echo "   node $SRV/dist/index.js"
