# sc:figma-connect

**Goal**: Attach the local Figma Dev Mode MCP server to your MCP-capable client (Claude Code, Cursor).

**Steps**
1. Open Figma desktop → Preferences → Enable Dev Mode MCP Server.
2. In your MCP client, add server:
   - Name: Figma Dev Mode MCP
   - URL: http://127.0.0.1:3845/sse  (if fails, try http://127.0.0.1:3845/mcp)
3. Select a frame in Figma; verify the client shows a green status or active tools.

**Output**: Client shows "Figma Dev Mode MCP • tools: 3–4 enabled".
