# Scout Analytics MCP Server

This Desktop Extension provides Scout Analytics database access tools for Claude Desktop using the Model Context Protocol (MCP).

## Features

- **Execute SQL queries** on your Scout Analytics database
- **List all tables** to explore your data structure  
- **Describe table schemas** to understand column types and structure
- **Secure configuration** with credentials stored in OS keychain

## Installation

### Option 1: Desktop Extension (Recommended)

1. Download the `scout-mcp.mcpb` file
2. Double-click to install in Claude Desktop
3. Enter your database credentials when prompted
4. Start using Scout tools in Claude!

### Option 2: Manual Configuration

If you prefer manual setup, add this to your Claude Desktop config:

```json
{
  "mcpServers": {
    "scout-analytics": {
      "command": "node",
      "args": ["/path/to/scout-mcpb-bundle/index.js"],
      "env": {
        "SUPABASE_URL": "https://cxzllzyxwpyptfretryc.supabase.co",
        "SUPABASE_ANON_KEY": "your-anon-key-here"
      }
    }
  }
}
```

## Available Tools

### `execute_sql`
Execute SQL queries on your Scout database. Recommended for SELECT operations.

**Example:**
```
Can you show me the top 10 products by sales from the scout_metrics table?
```

### `list_tables`
List all available tables in your Scout database.

**Example:**
```
What tables are available in my Scout database?
```

### `describe_table`
Get detailed information about a table's structure.

**Example:**
```
What columns does the scout_campaigns table have?
```

## Security

- All database credentials are stored securely in your OS keychain
- SQL queries are validated to prevent destructive operations
- Read-only operations are recommended for safety

## Support

For issues or questions, please contact the TBWA Scout Analytics team.