# Quick Setup Guide

## 1. Install Dependencies

```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse/tools/mcp/diagram-bridge-mcp
npm install
npm run build
```

## 2. Install draw.io Desktop (Optional but Recommended)

Download from: https://github.com/jgraph/drawio-desktop/releases

**macOS**: The app installs to `/Applications/draw.io.app`
**Linux**: Usually available as `drawio` command
**Windows**: Installs to `C:\Program Files\draw.io\`

## 3. Configure Claude Desktop

Edit: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "diagram-bridge": {
      "command": "/usr/local/bin/node",
      "args": ["/Users/tbwa/ai-aas-hardened-lakehouse/tools/mcp/diagram-bridge-mcp/dist/index.js"],
      "env": {
        "KROKI_URL": "https://kroki.io",
        "DRAWIO_BIN": "/Applications/draw.io.app/Contents/MacOS/draw.io"
      }
    }
  }
}
```

## 4. Restart Claude Desktop

Close and reopen Claude Desktop to load the new MCP server.

## 5. Test Installation

In Claude Desktop, try:
```
"Use the diagram tools to create a simple flowchart showing: Start -> Process -> End"
```

You should see tools like `diagram_render`, `diagram_plan_and_generate`, etc. available.

## 6. Self-Host Kroki (Optional, for Privacy)

If you don't want to send diagrams to public kroki.io:

```bash
# Create docker-compose.yml
version: '3.8'
services:
  kroki:
    image: yuzutech/kroki
    ports:
      - "8000:8000"
  kroki-diagramsnet:
    image: yuzutech/kroki-diagramsnet
    environment:
      - KROKI_CONTAINER_HOST=kroki
    depends_on:
      - kroki

# Start services
docker-compose up -d
```

Then update Claude config:
```json
{
  "env": {
    "KROKI_URL": "http://localhost:8000",
    "DRAWIO_BIN": "/Applications/draw.io.app/Contents/MacOS/draw.io"
  }
}
```

## Troubleshooting

### "drawio command not found"
- Make sure draw.io Desktop is installed
- Set correct `DRAWIO_BIN` path in environment

### "Kroki connection failed"
- Check internet connection for public kroki.io
- For self-hosted: ensure Docker containers are running
- Test with: `curl https://kroki.io/mermaid/svg -d "graph TD; A-->B;"`

### MCP server not starting
- Check Claude Desktop logs: `~/Library/Logs/Claude/mcp.log`
- Verify Node.js version is 18+
- Ensure TypeScript compiled successfully: `npm run build`