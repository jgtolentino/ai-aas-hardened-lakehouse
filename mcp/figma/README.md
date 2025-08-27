# Figma Dev Mode MCP Server — Integration

## Prereqs
1) Figma desktop app with a Dev or Full seat.
2) In Figma: **Preferences → Enable Dev Mode MCP Server** (toggle ON).
   - The server usually exposes **http://127.0.0.1:3845/sse** (preferred) or **http://127.0.0.1:3845/mcp** depending on client. See notes below.

## Known endpoints & client expectations
- Builder.io & many client guides reference **/sse**.  
- Some forum/help references show **/mcp** (older docs/clients).  
If your client shows a red status dot, toggle the server OFF/ON in Figma and try the other path.

## What you get
- Generate code from selected frames.
- Extract design context (variables, components, layout) for accurate, design-informed code.

## Sources
- Figma Dev Mode (overview): https://www.figma.com/dev-mode/
- Official help: https://help.figma.com/hc/en-us/articles/32132100833559-Guide-to-the-Dev-Mode-MCP-Server
- Launch blog (beta): https://www.figma.com/blog/introducing-figmas-dev-mode-mcp-server/
- Endpoint path examples: https://www.builder.io/blog/figma-mcp-server ("/sse") and forum note ("/mcp").
