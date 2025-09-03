# 🎯 Scout Analytics MCP Installation Guide

This guide provides **two installation options** for the Scout Analytics MCP server in Claude Desktop:

1. **Desktop Extension (MCPB)** - One-click installation ✨ **(Recommended)**
2. **Manual MCP Server** - Traditional configuration approach 🔧

---

## 📦 Option 1: Desktop Extension (MCPB) - **RECOMMENDED**

The **MCPB (Model Context Protocol Bundle)** format provides the easiest installation experience.

### ✨ **Why Choose MCPB?**

| Feature | Desktop Extension | Manual Setup |
|---------|------------------|--------------|
| **Installation** | One-click | Multi-step terminal |
| **Credential Security** | OS Keychain | Manual config files |
| **Updates** | Automatic | Manual |
| **User Experience** | GUI configuration | JSON editing |
| **Distribution** | Single file | Multiple files |
| **Error Handling** | Built-in validation | Manual debugging |

### 🚀 **MCPB Installation Steps**

#### Step 1: Build the Extension
```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse
./scripts/build-scout-mcpb.sh
```

This creates: `dist/scout-analytics-mcp.mcpb`

#### Step 2: Install in Claude Desktop
1. **Open Claude Desktop**
2. **Go to Settings** → Extensions
3. **Click "Install from file"**
4. **Select** `dist/scout-analytics-mcp.mcpb`
5. **Enter credentials** when prompted:
   - **Database URL**: `https://cxzllzyxwpyptfretryc.supabase.co`
   - **Database Key**: Your Supabase anonymous key

#### Step 3: Start Using Scout Tools!
```
Hey Claude, what tables are available in my Scout database?
```

### 🔒 **Security Features**
- Credentials stored in **macOS Keychain** (secure)
- **Input validation** prevents dangerous SQL operations
- **Network-only permissions** (no filesystem or shell access)
- **Read-preferred operations** for data safety

---

## 🔧 Option 2: Manual MCP Server Configuration

For developers who prefer full control over the configuration.

### **Prerequisites**
- Node.js 18+ installed
- Access to Supabase credentials
- Text editor for JSON configuration

### **Installation Steps**

#### Step 1: Prepare the Server
```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse/extensions/mcp-scout
npm install
```

#### Step 2: Configure Claude Desktop
Add to your Claude Desktop configuration file:

**Location**: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "scout-analytics": {
      "command": "node",
      "args": ["/Users/tbwa/ai-aas-hardened-lakehouse/scout-mcpb-bundle/index.js"],
      "env": {
        "SUPABASE_URL": "https://cxzllzyxwpyptfretryc.supabase.co",
        "SUPABASE_ANON_KEY": "your-anon-key-here"
      }
    }
  }
}
```

#### Step 3: Restart Claude Desktop
Close and reopen Claude Desktop to load the new MCP server.

### **Manual Configuration Benefits**
- **Full control** over server configuration
- **Easy debugging** with direct file access
- **Custom modifications** possible
- **No dependency** on MCPB format support

---

## 🛠 Available Tools (Both Options)

Once installed, you'll have access to these Scout Analytics tools:

### **`execute_sql`**
Execute SQL queries on your Scout database.

**Example Usage:**
```
Can you show me the top 10 campaigns by revenue from the scout_metrics table?
```

**Safe Query Types:**
- `SELECT` statements (recommended)
- `WITH` clauses for complex analytics
- Aggregate functions (`SUM`, `COUNT`, `AVG`)

### **`list_tables`**
Discover all available tables in your database.

**Example Usage:**
```
What data tables do I have available in Scout?
```

### **`describe_table`**
Get detailed schema information for specific tables.

**Example Usage:**
```
What columns are in the scout_campaigns table and what are their types?
```

---

## 🚨 Troubleshooting

### **MCPB Installation Issues**

**Problem**: "Extension failed to install"
- **Solution**: Check that the `.mcpb` file isn't corrupted
- **Verify**: Run `unzip -t dist/scout-analytics-mcp.mcpb`

**Problem**: "Cannot connect to database"
- **Solution**: Verify your Supabase URL and key are correct
- **Check**: Test connection at https://supabase.com/dashboard

**Problem**: "Tools not appearing in Claude"
- **Solution**: Restart Claude Desktop after installation
- **Check**: Extensions list in Claude Desktop settings

### **Manual Configuration Issues**

**Problem**: "MCP server not starting"
- **Solution**: Check Node.js version with `node --version`
- **Requires**: Node.js 18.0.0 or higher

**Problem**: "Module not found errors"
- **Solution**: Run `npm install` in the bundle directory
- **Check**: `node_modules` directory exists

**Problem**: "Permission denied"
- **Solution**: Make the index.js file executable
- **Command**: `chmod +x scout-mcpb-bundle/index.js`

### **Common Issues (Both Options)**

**Problem**: "No results from queries"
- **Check**: Database URL is correct
- **Verify**: Anonymous key has proper permissions
- **Test**: Try `list_tables` first to test connectivity

**Problem**: "SQL execution errors"
- **Note**: Some advanced SQL features may not be available
- **Try**: Simpler SELECT queries first
- **Alternative**: Use Supabase dashboard for complex operations

---

## 📊 Performance Comparison

| Aspect | Desktop Extension | Manual Setup |
|--------|------------------|---------------|
| **Setup Time** | 2 minutes | 5-10 minutes |
| **Maintenance** | Automatic | Manual updates |
| **Security** | OS-managed | User-managed |
| **Portability** | High (single file) | Medium (requires setup) |
| **Debugging** | Limited | Full access |
| **Team Sharing** | Easy (share .mcpb) | Complex (share config) |

---

## 🎯 **Recommended Workflow**

### **For Most Users**: Use Desktop Extension
1. Build with `./scripts/build-scout-mcpb.sh`
2. Install the `.mcpb` file in Claude Desktop
3. Configure credentials through GUI
4. Start querying your Scout data!

### **For Developers**: Consider Manual Setup
1. When you need custom modifications
2. For debugging server issues
3. When integrating with development workflows
4. For advanced configuration options

---

## 🆘 **Getting Help**

- **MCPB Build Issues**: Check the build script output for specific errors
- **Database Connection**: Verify credentials in Supabase dashboard
- **Claude Desktop**: Restart the application after configuration changes
- **SQL Queries**: Start with simple SELECT statements to test connectivity

---

## 🎉 **You're Ready!**

With either installation method, you now have powerful Scout Analytics database access directly in Claude Desktop. Start exploring your data with natural language queries!

**Example first query:**
```
Show me an overview of my Scout database - what tables do I have and what kind of data is in each?
```