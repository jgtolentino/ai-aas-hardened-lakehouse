# 🖥️ Claude Desktop Extension Integration

## Current Setup Status

✅ **Claude Desktop Extension** is managing your MCP Hub server automatically
- No manual `npm start` needed
- Server lifecycle handled by Claude Desktop
- Automatic restarts and monitoring included

---

## How It Works

### 1. **Extension Management**
```
Claude Desktop Extension
├── Manages MCP server processes
├── Handles automatic restarts
├── Monitors server health
└── Integrates with Claude Desktop UI
```

### 2. **Your MCP Hub Configuration**
The extension reads from your MCP configuration and automatically:
- Starts the server when Claude Desktop launches
- Manages the server process lifecycle
- Handles port management and conflicts
- Provides server status in Claude Desktop settings

### 3. **Local Development vs Extension**
```
Manual Development (npm start):     ❌ Not needed anymore
Claude Desktop Extension:           ✅ Handles everything
Server Status:                      ✅ Visible in Claude → Settings → Developer
```

---

## Verification Steps

### 1. Check Claude Desktop Settings
1. Open Claude Desktop
2. Go to **Settings** → **Developer**
3. Look for your MCP servers listed with **running** status
4. You should see servers including your updated hub

### 2. Verify Server Endpoints
The extension makes your servers available at the configured ports:
```bash
# Health check (should work automatically)
curl http://localhost:8787/health

# OpenAPI schema (should show all 5 adapters)
curl http://localhost:8787/openapi.json | grep -o '"supabase\|mapbox\|figma\|github\|sync"'
```

### 3. Test Integration
With the extension handling the server, you can now use:

**Direct Claude Desktop Prompts**:
```
"Export my current Figma selection and commit it to GitHub via the MCP Hub"
```

**Local API Calls** (server runs automatically):
```bash
curl -H "X-API-Key: tbwa-mcp-hub-api-key-2025-secure-production-ready-32chars" \
     -H "Content-Type: application/json" \
     -d '{"server":"sync","tool":"sync.figmaFileToRepo","args":{"fileKey":"YOUR_FILE_KEY"}}' \
     http://localhost:8787/mcp/run
```

---

## Configuration Management

### 1. **Environment Variables**
The extension reads from your `.env` file:
```bash
PORT=8787
FIGMA_TOKEN=figd_your_token_here
GITHUB_TOKEN=ghp_your_token_here
GITHUB_REPO=tbwa/ai-aas-hardened-lakehouse
```

### 2. **MCP Desktop Config**
Your Claude Desktop config likely includes:
```json
{
  "mcpServers": {
    "mcp_hub": {
      "command": "node",
      "args": ["--env-file=.env", "src/server.js"],
      "cwd": "/Users/tbwa/ai-aas-hardened-lakehouse/infra/mcp-hub"
    }
  }
}
```

---

## Advantages of Extension Management

### ✅ **Benefits**
- **Zero Manual Server Management**: No `npm start/stop` needed
- **Automatic Restarts**: Server recovers from crashes
- **Integration**: Seamless with Claude Desktop workflows
- **Monitoring**: Server status visible in UI
- **Port Management**: Handles conflicts automatically

### 📋 **What This Changes**
- ~~Manual server starting~~  → Extension handles it
- ~~Process monitoring~~      → Extension handles it  
- ~~Port conflict resolution~~ → Extension handles it
- **Your Development**        → Focus on tokens & testing only

---

## Next Steps (Simplified)

Since the extension handles server management:

### 1. **Add Real Tokens Only**
```bash
# Edit .env file:
FIGMA_TOKEN=figd_your_actual_token
GITHUB_TOKEN=ghp_your_actual_token
```

### 2. **Restart Claude Desktop**
- Close Claude Desktop
- Reopen (extension will restart server with new tokens)
- Check Settings → Developer for "running" status

### 3. **Test Integration**
```bash
# Test the workflow
./test-figma-github-sync.sh YOUR_FILE_KEY http://localhost:8787
```

---

## Troubleshooting

### Server Not Starting?
1. Check Claude Desktop → Settings → Developer
2. Look for error messages in server logs
3. Verify `.env` file syntax
4. Restart Claude Desktop

### Port Conflicts?
- Extension should handle this automatically
- Check if `PORT=8787` in `.env` is available
- Extension may assign different port if needed

### Token Issues?
- Verify tokens in `.env` file
- Check token permissions (Figma: personal access, GitHub: repo scope)
- Restart Claude Desktop after token changes

---

The Claude Desktop Extension makes your MCP Hub integration seamless! 🚀