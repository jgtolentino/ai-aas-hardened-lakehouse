# diagram-bridge-mcp

A Model Context Protocol (MCP) server that transforms natural language into diagrams using multiple rendering engines:

- **Kroki Integration**: Mermaid, PlantUML, Graphviz, D2, DBML, Vega, and 15+ other formats
- **Direct draw.io CLI**: Native draw.io Desktop exports (SVG/PNG/PDF)
- **Viewer URLs**: Instant browser-viewable links for draw.io diagrams
- **Embed Support**: Interactive editing URLs for draw.io

## 🚀 Quick Start

### Prerequisites

1. **Node.js 18+**
2. **draw.io Desktop** (for CLI exports): [Download](https://github.com/jgraph/drawio-desktop/releases)

### Installation

```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse/tools/mcp/diagram-bridge-mcp
npm install
npm run build
```

### Claude Desktop Configuration

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

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

## 🔧 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KROKI_URL` | `https://kroki.io` | Kroki server endpoint |
| `DRAWIO_BIN` | Auto-detected | Path to draw.io CLI binary |

## 🛠 Available Tools

### Core Rendering

#### `diagram_render`
Render diagrams via Kroki API
```json
{
  "engine": "mermaid",
  "code": "graph TD; A-->B; B-->C;",
  "output": "svg",
  "saveFile": true,
  "returnDataUri": true
}
```

#### `diagram_drawio_cli_export`
Native draw.io Desktop CLI export
```json
{
  "xml": "<mxfile>...</mxfile>",
  "format": "svg",
  "crop": true
}
```

### URL Generators

#### `diagram_kroki_url`
Shareable Kroki GET URL (deflate+base64 encoded)
```json
{
  "engine": "mermaid",
  "code": "graph TD; A-->B;",
  "output": "svg"
}
```

#### `diagram_drawio_viewer_url`
Browser-viewable draw.io URL
```json
{
  "xml": "<mxfile>...</mxfile>"
}
```

#### `diagram_drawio_embed_url`
Interactive editing URL
```json
{
  "params": {
    "ui": "kennedy",
    "spin": "1"
  }
}
```

### Planning

#### `diagram_plan_and_generate`
AI-powered diagram engine selection and code generation
```json
{
  "intent": "Create a database schema for an e-commerce system",
  "preferredEngine": "dbml"
}
```

#### `diagram_list_engines`
List all supported engines
```json
{}
```

## 📊 Supported Diagram Types

### Via Kroki
- **Mermaid**: Flowcharts, sequence diagrams, Gantt charts
- **PlantUML**: UML diagrams, architecture diagrams
- **Graphviz/DOT**: Network graphs, dependency graphs
- **D2**: Modern architecture diagrams
- **DBML**: Database schema diagrams
- **Vega/Vega-Lite**: Data visualizations
- **And 15+ more**: WaveDrom, ByteField, ERD, Nomnoml, etc.

### Via draw.io CLI
- **Flowcharts**: Business process diagrams
- **Network Diagrams**: Infrastructure layouts
- **UML**: Class, sequence, activity diagrams
- **Mockups**: UI/UX wireframes
- **Custom**: Any draw.io-compatible diagram

## 🎯 Usage Examples

### 1. Generate Mermaid Flowchart

```
User: "Create a flowchart showing user authentication flow"

Assistant uses:
1. diagram_plan_and_generate → selects "mermaid" 
2. diagram_render → creates SVG + file://
```

### 2. Export draw.io to PDF

```
User: "Convert this draw.io XML to PDF"

Assistant uses:
diagram_drawio_cli_export with format="pdf"
```

### 3. Share Database Schema

```
User: "Create shareable link for this DBML schema"

Assistant uses:
diagram_kroki_url with engine="dbml"
```

## 🔒 Security & Privacy

### Public Kroki (Default)
- Convenient but sends diagram content to kroki.io
- ⚠️ **Don't use for sensitive diagrams**

### Self-Hosted Kroki (Recommended for Production)
```bash
# Docker Compose
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
```

Set `KROKI_URL=http://localhost:8000`

### draw.io CLI (Always Local)
- Processes diagrams entirely on local machine
- No network requests for rendering
- Recommended for sensitive content

## 🎨 Advanced Features

### Multi-Page draw.io Export
```json
{
  "inputPath": "/path/to/multipage.drawio",
  "format": "png",
  "pageIndex": 0
}
```

### Custom Kroki Options
```json
{
  "engine": "plantuml",
  "code": "@startuml\nAlice -> Bob\n@enduml",
  "options": {
    "theme": "vibrant",
    "scale": "2"
  }
}
```

### Cropped Exports
```json
{
  "xml": "<mxfile>...</mxfile>",
  "format": "svg",
  "crop": true
}
```

## 🐛 Troubleshooting

### draw.io CLI Not Found
```bash
# macOS
export DRAWIO_BIN="/Applications/draw.io.app/Contents/MacOS/draw.io"

# Linux (if installed via package manager)
export DRAWIO_BIN="drawio"

# Windows
set DRAWIO_BIN="C:\Program Files\draw.io\draw.io.exe"
```

### Kroki Connection Issues
```bash
# Test connectivity
curl -X POST -H "Content-Type: text/plain" \
  -d "graph TD; A-->B;" \
  https://kroki.io/mermaid/svg
```

### MCP Server Not Starting
```bash
# Test directly
node dist/index.js

# Check logs in Claude Desktop
~/Library/Logs/Claude/mcp.log
```

## 🔄 Development

### Build & Test
```bash
npm run dev        # Development with hot reload
npm run build      # Production build
npm run test       # Run tests
npm run clean      # Clean dist directory
```

### Adding New Engines
1. Add engine name to `KNOWN_ENGINES` array
2. Update Kroki URL mappings if needed
3. Add engine-specific examples to documentation

## 📝 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 🔗 References

- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Kroki Documentation](https://docs.kroki.io/)
- [draw.io Desktop CLI](https://github.com/jgraph/drawio-desktop)
- [Mermaid Syntax](https://mermaid.js.org/syntax/)
- [PlantUML Guide](https://plantuml.com/)