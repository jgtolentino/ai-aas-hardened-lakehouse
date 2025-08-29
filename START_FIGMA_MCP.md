# Starting Figma Dev Mode MCP

To complete the MCP bridge, you need to start the Figma Dev Mode MCP server:

## Step 1: Enable Figma Dev Mode MCP

1. **Open Figma Desktop App**
2. Go to **Preferences** (⌘+, on Mac, Ctrl+, on Windows)
3. Navigate to the **Dev Mode** section
4. **Toggle ON** "Enable Dev Mode MCP Server"

## Step 2: Verify MCP Server is Running

The Figma MCP server should automatically start on:
- **Port:** 3845
- **URL:** `http://127.0.0.1:3845/sse` (preferred) or `http://127.0.0.1:3845/mcp`

## Step 3: Test the Connection

Once Figma MCP is running, test the bridge:

```bash
# Test with curl
curl -s -H "X-API-Key: tbwa-mcp-hub-api-key-2025-secure-production-ready-32chars" \
  -H "Content-Type: application/json" \
  -d '{
    "server":"figma-proxy",
    "tool":"file.exportJSON", 
    "args":{"fileKey":"YOUR_FIGMA_FILE_KEY"}
  }' \
  http://localhost:8787/mcp/run | jq .
```

## Troubleshooting

- **If connection fails**: Toggle the MCP server OFF/ON in Figma preferences
- **Try different endpoints**: Some clients work with `/sse`, others with `/mcp`
- **Check port**: Ensure Figma is running on port 3845

## MCP Hub Configuration

The MCP Hub is configured to:
- Route `figma-proxy` requests to `localhost:3845`
- Handle authentication through Claude Desktop
- Provide unified API for all MCP services

Once Figma Dev Mode MCP is running, your bridge will be fully operational!
