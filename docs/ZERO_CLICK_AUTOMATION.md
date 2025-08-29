# Zero-Click Design Automation System

## Overview

The Zero-Click Design Automation System enables Claude to **find**, **clone**, and **modify** designs programmatically without manual intervention. This system implements a complete "query → find → patch → export → commit" workflow for design automation.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Claude MCP    │───▶│   Design Index   │───▶│  Figma Bridge   │
│     Client      │    │    (SQLite)      │    │   (WebSocket)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         │              ┌──────────────────┐              │
         └─────────────▶│   MCP Hub API    │◀─────────────┘
                        │  (Express.js)    │
                        └──────────────────┘
                                 │
                        ┌──────────────────┐
                        │ Patch Processor  │
                        │   (JSON Spec)    │
                        └──────────────────┘
```

## Components

### 1. Design Index (SQLite)
**Location:** `infra/mcp-hub/src/adapters/design-index.{js,ts}`

Local SQLite database for design search without Figma tokens:
- **Storage:** File-based SQLite database at `.cache/design-index.sqlite`
- **Schema:** Design metadata with tags, dimensions, and classifications
- **Search:** Full-text search across titles, tags, and metadata
- **Performance:** Indexed queries for fast lookups

```typescript
interface DesignRow {
  id: string;                 // Unique identifier (fileKey:nodeId)
  file_key: string;          // Figma file key
  node_id: string;           // Figma node ID
  title: string;             // Human-readable name
  kind: "dashboard"|"component"|"diagram"|"screen"|"template";
  tags: string[];            // Searchable tags ["kpi","12col","finance"]
  preview: string | null;    // Optional preview image URL
  metadata: Record<string, any>; // Dimensions, colors, component count
  updated_at: string;        // ISO timestamp
  created_at: string;        // ISO timestamp
}
```

### 2. Patch Specification System
**Location:** `infra/mcp-hub/src/schemas/design-patch.ts`

Unified JSON specification for bulk design modifications:

```typescript
interface PatchSpec {
  target: {
    fileKey: string;
    nodeId: string;
    selectors: string[];     // CSS-like selectors for targeting
  };
  operations: PatchOperation[];
  options?: {
    preview?: boolean;       // Generate preview before applying
    rollback?: boolean;      // Enable rollback capability
    parallel?: boolean;      // Execute operations in parallel
    timeout?: number;        // Operation timeout in milliseconds
  };
}
```

**Supported Operations:**
- **Style Changes:** Colors, fonts, dimensions, effects
- **Text Replacements:** Find/replace with regex support
- **Component Swapping:** Replace components with variants
- **Layout Modifications:** Positioning, spacing, alignment
- **Brand Token Application:** Consistent brand styling

### 3. MCP Hub API
**Location:** `infra/mcp-hub/src/server.js`

Express.js server providing REST endpoints for design operations:

```javascript
// Design search endpoint
POST /mcp/design/search
{
  "text": "executive kpi",
  "kind": "dashboard", 
  "tags": ["finance", "analytics"],
  "limit": 10
}

// Design indexing endpoint
POST /mcp/design/index
{
  "items": [DesignRow, ...]
}

// MCP tool execution endpoint
POST /mcp/run
{
  "server": "figma",
  "tool": "figma_apply_patch",
  "args": { "patchSpec": PatchSpec }
}
```

### 4. Figma Bridge (WebSocket)
**Location:** `infra/mcp-hub/src/adapters/figma-bridge.ts`

WebSocket server for real-time Figma plugin communication:

```typescript
class FigmaBridge {
  // Apply design patches
  async applyPatch(patchSpec: PatchSpec): Promise<any>
  
  // Clone and modify designs
  async cloneAndModify(sourceFileKey: string, sourceNodeId: string, modifications: any): Promise<any>
  
  // Extract PRD content
  async extractPRDContent(boardUrl: string, extractionTargets: string[]): Promise<any>
}
```

## Usage Examples

### 1. Zero-Click Dashboard Retargeting

```bash
# Find executive dashboard and rebrand for TBWA
./scripts/retarget-dashboard.sh "executive kpi" "TBWA"

# Find financial dashboard and rebrand for Nike  
./scripts/retarget-dashboard.sh "financial dashboard" "Nike"

# Find analytics dashboard and rebrand for Apple
./scripts/retarget-dashboard.sh "analytics" "Apple"
```

### 2. Direct API Usage

```javascript
// Search for designs
const response = await fetch('http://localhost:8787/mcp/design/search', {
  method: 'POST',
  headers: {
    'X-API-Key': 'your-api-key',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    text: 'executive kpi',
    kind: 'dashboard',
    limit: 5
  })
});

const { results } = await response.json();
```

### 3. Claude MCP Integration

```typescript
// Claude can directly execute via MCP tools
await mcp.run({
  server: "figma",
  tool: "figma_apply_patch", 
  args: {
    patchSpec: {
      target: {
        fileKey: "abc123",
        nodeId: "456:789",
        selectors: ["*"]
      },
      operations: [
        {
          type: "text",
          find: "Company Name",
          replace: "TBWA"
        },
        {
          type: "style", 
          changes: {
            fills: [{"type": "SOLID", "color": {"r": 0.11, "g": 0.25, "b": 0.69}}]
          }
        }
      ]
    }
  }
});
```

## Brand Customization Presets

### TBWA Brand
```json
{
  "colors": {
    "primary": {"r": 0.11, "g": 0.25, "b": 0.69},
    "secondary": {"r": 0.98, "g": 0.98, "b": 0.98}
  },
  "typography": {
    "fontFamily": "Inter",
    "fontWeight": 600
  },
  "text_replacements": [
    {"find": "Company Name", "replace": "TBWA"},
    {"find": "Brand", "replace": "TBWA"}
  ]
}
```

### Nike Brand
```json
{
  "colors": {
    "primary": {"r": 0, "g": 0, "b": 0},
    "secondary": {"r": 1, "g": 1, "b": 1}
  },
  "typography": {
    "fontFamily": "Nike Futura", 
    "fontWeight": 700
  },
  "text_replacements": [
    {"find": "Company Name", "replace": "Nike"}
  ]
}
```

### Apple Brand
```json
{
  "colors": {
    "primary": {"r": 0.92, "g": 0.92, "b": 0.92},
    "secondary": {"r": 0, "g": 0, "b": 0}
  },
  "typography": {
    "fontFamily": "SF Pro Display",
    "fontWeight": 400
  },
  "text_replacements": [
    {"find": "Company Name", "replace": "Apple"}
  ]
}
```

## Setup Instructions

### 1. Install Dependencies

```bash
cd infra/mcp-hub
npm install express helmet cors morgan better-sqlite3 ws
```

### 2. Start MCP Hub

```bash
cd infra/mcp-hub
npm run start
# Server starts on http://localhost:8787
```

### 3. Populate Design Index

```bash
# Add sample designs for testing
./scripts/index-sample-designs.sh

# Or index from actual Figma files
curl -X POST http://localhost:8787/mcp/design/index \
  -H "X-API-Key: dev-key-12345" \
  -H "Content-Type: application/json" \
  -d '{"items": [...]}'
```

### 4. Configure Environment

```bash
# Set API key for authentication
export HUB_API_KEY="your-secure-api-key"

# Set MCP Hub URL if different
export HUB_URL="http://localhost:8787" 

# Set output directory for exported designs
export OUTPUT_DIR="./output"

# Set Figma team ID for new file creation
export FIGMA_TEAM_ID="your-team-id"
```

### 5. Test Automation

```bash
# Run comprehensive UAT validation
./scripts/validate-automation.sh

# Test specific functionality
./scripts/retarget-dashboard.sh "executive kpi" "TBWA"
```

## Workflow

### Complete Zero-Click Process

1. **Search Phase**: Query design index for matching templates
   ```bash
   curl -X POST $HUB_URL/mcp/design/search \
     -d '{"text": "executive kpi", "kind": "dashboard"}'
   ```

2. **Selection Phase**: Pick best matching design from results
   ```javascript
   const design = searchResults.results[0];
   const { file_key, node_id, title } = design;
   ```

3. **Patch Phase**: Apply brand customizations via patch specification
   ```bash
   curl -X POST $HUB_URL/mcp/run \
     -d '{"server": "figma", "tool": "figma_apply_patch", "args": {...}}'
   ```

4. **Export Phase**: Generate final design assets
   ```bash
   curl -X POST $HUB_URL/mcp/run \
     -d '{"server": "figma", "tool": "figma_export", "args": {...}}'
   ```

5. **Commit Phase**: Automatically commit changes to git
   ```bash
   git add output/
   git commit -m "feat: retarget dashboard for $BRAND"
   ```

## Testing & Validation

### UAT Checklist

- [x] **Design Index**: SQLite database operations
- [x] **Search Functionality**: Text and tag-based queries
- [x] **Patch System**: JSON specification validation
- [x] **MCP Integration**: API endpoints and authentication
- [x] **Figma Bridge**: WebSocket communication
- [x] **Brand Presets**: TBWA, Nike, Apple customizations
- [x] **Error Handling**: Graceful failure and recovery
- [x] **Security**: API key authentication and input validation
- [x] **Performance**: Fast search and modification operations
- [x] **Documentation**: Complete usage examples and guides

### Run Validation

```bash
# Comprehensive system validation
./scripts/validate-automation.sh

# Expected output:
# ========== Zero-Click Automation UAT Validation ==========
# [PASS] Design Index SQLite implementation
# [PASS] Patch Specification system  
# [PASS] MCP Hub endpoints
# [PASS] Figma Bridge functionality
# [PASS] Automation scripts
# [PASS] Integration readiness
# [PASS] Security implementation
# [PASS] Error handling
# 
# Tests Run: 25, Tests Passed: 25, Tests Failed: 0
# All tests passed!
```

## Advanced Usage

### Custom Patch Operations

```typescript
// Multi-step brand transformation
const complexPatch: PatchSpec = {
  target: {
    fileKey: "abc123",
    nodeId: "456:789", 
    selectors: [".kpi-card", ".chart-container", ".header"]
  },
  operations: [
    // Step 1: Update brand colors
    {
      type: "style",
      selector: ".kpi-card",
      changes: {
        fills: [{"type": "SOLID", "color": {"r": 0.11, "g": 0.25, "b": 0.69}}],
        cornerRadius: 12,
        effects: [{"type": "DROP_SHADOW", "offset": {"x": 0, "y": 4}, "blur": 8}]
      }
    },
    // Step 2: Replace all text content
    {
      type: "text",
      find: /Company.*Name/gi,
      replace: "TBWA"
    },
    // Step 3: Swap components
    {
      type: "component",
      find: "old-logo-component",
      replace: "tbwa-logo-component"
    }
  ],
  options: {
    preview: true,
    parallel: false,
    timeout: 60000
  }
};
```

### Batch Processing

```bash
# Process multiple brands in parallel
brands=("TBWA" "Nike" "Apple" "Microsoft")
query="executive kpi dashboard"

for brand in "${brands[@]}"; do
  ./scripts/retarget-dashboard.sh "$query" "$brand" &
done

wait # Wait for all background processes
echo "Batch processing complete!"
```

### Integration with CI/CD

```yaml
# .github/workflows/design-automation.yml
name: Design Automation
on:
  schedule:
    - cron: '0 2 * * *' # Daily at 2 AM
  workflow_dispatch:
    inputs:
      brand:
        description: 'Brand name'
        required: true
        default: 'TBWA'

jobs:
  automate-designs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
      - name: Install dependencies
        run: cd infra/mcp-hub && npm install
      - name: Start MCP Hub
        run: cd infra/mcp-hub && npm start &
      - name: Run automation
        run: ./scripts/retarget-dashboard.sh "executive kpi" "${{ github.event.inputs.brand || 'TBWA' }}"
        env:
          HUB_API_KEY: ${{ secrets.HUB_API_KEY }}
      - name: Commit results
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add output/
          git commit -m "feat: automated design retargeting for ${{ github.event.inputs.brand || 'TBWA' }}" || exit 0
          git push
```

## API Reference

### Design Search API

```http
POST /mcp/design/search
Content-Type: application/json
X-API-Key: your-api-key

{
  "text": "executive kpi",        // Search text (optional)
  "tags": ["finance", "cards"], // Filter by tags (optional)  
  "kind": "dashboard",          // Filter by type (optional)
  "limit": 10,                  // Result limit (optional, default: 20)
  "metadata": {                 // Metadata filters (optional)
    "width": 1440,
    "componentCount": {"$gte": 5}
  }
}
```

**Response:**
```json
{
  "results": [
    {
      "id": "abc123:456789",
      "file_key": "abc123", 
      "node_id": "456789",
      "title": "Executive KPI Dashboard",
      "kind": "dashboard",
      "tags": ["executive", "kpi", "cards"],
      "metadata": {
        "width": 1440,
        "height": 1024,
        "componentCount": 8
      },
      "updated_at": "2024-01-20T10:00:00Z"
    }
  ],
  "count": 1
}
```

### Design Indexing API

```http
POST /mcp/design/index  
Content-Type: application/json
X-API-Key: your-api-key

{
  "items": [
    {
      "id": "unique-id",
      "file_key": "figma-file-key",
      "node_id": "figma-node-id", 
      "title": "Design Name",
      "kind": "dashboard",
      "tags": ["tag1", "tag2"],
      "metadata": {"width": 1440, "height": 1024},
      "updated_at": "2024-01-20T10:00:00Z"
    }
  ]
}
```

**Response:**
```json
{
  "ok": true,
  "indexed": 1
}
```

### MCP Tool Execution API

```http
POST /mcp/run
Content-Type: application/json  
X-API-Key: your-api-key

{
  "server": "figma",
  "tool": "figma_apply_patch",
  "args": {
    "patchSpec": {
      "target": {
        "fileKey": "abc123",
        "nodeId": "456789",
        "selectors": ["*"]
      },
      "operations": [
        {
          "type": "text",
          "find": "Company Name", 
          "replace": "TBWA"
        }
      ]
    }
  }
}
```

**Response:**
```json
{
  "data": {
    "success": true,
    "appliedOperations": 1,
    "previewUrl": "https://figma.com/...",
    "modifiedNodes": ["456789"]
  }
}
```

## Troubleshooting

### Common Issues

**1. MCP Hub Not Starting**
```bash
# Check if port 8787 is in use
lsof -i :8787

# Kill existing process
kill $(lsof -t -i :8787)

# Restart MCP Hub
cd infra/mcp-hub && npm start
```

**2. SQLite Database Locked**
```bash
# Remove lock file
rm .cache/design-index.sqlite-shm
rm .cache/design-index.sqlite-wal

# Recreate database
cd infra/mcp-hub
node -e "const { ensureDatabase } = require('./src/adapters/design-index.js'); ensureDatabase();"
```

**3. Figma Bridge Connection Failed**
- Ensure Figma plugin is installed and active
- Check WebSocket connection on port 8787
- Verify Figma file permissions

**4. Authentication Errors**
```bash
# Set correct API key
export HUB_API_KEY="your-secure-api-key"

# Test authentication
curl -H "X-API-Key: $HUB_API_KEY" http://localhost:8787/health
```

### Debug Mode

```bash
# Enable debug logging
export DEBUG=1
export LOG_LEVEL=debug

# Run with verbose output  
./scripts/retarget-dashboard.sh "executive kpi" "TBWA"
```

### Logs and Monitoring

```bash
# MCP Hub logs
tail -f infra/mcp-hub/logs/server.log

# Figma Bridge logs  
tail -f infra/mcp-hub/logs/figma-bridge.log

# Automation script logs
tail -f logs/automation.log
```

## Security Considerations

### API Security
- **Authentication**: All endpoints require `X-API-Key` header
- **Rate Limiting**: 60 requests per minute per IP
- **Input Validation**: JSON schema validation on all inputs
- **CORS**: Configured for specific origins only

### Data Protection
- **Local Storage**: SQLite database stored locally, not transmitted
- **Access Control**: File system permissions restrict database access
- **No Persistence**: Figma tokens not stored permanently
- **Audit Trail**: All operations logged with timestamps

### Production Deployment
```bash
# Use secure API key
export HUB_API_KEY=$(openssl rand -hex 32)

# Enable HTTPS
export USE_HTTPS=true
export SSL_CERT_PATH=/path/to/cert.pem
export SSL_KEY_PATH=/path/to/key.pem

# Restrict CORS origins
export ALLOWED_ORIGINS="https://yourdomain.com,https://app.figma.com"
```

## Contributing

### Development Setup

```bash
# Clone repository
git clone <repository-url>
cd ai-aas-hardened-lakehouse

# Install dependencies
cd infra/mcp-hub && npm install

# Run tests
npm test

# Start development server  
npm run dev
```

### Code Style

```bash
# Format code
npm run format

# Lint code
npm run lint

# Type check
npm run type-check
```

### Adding New Features

1. **New Patch Operations**: Extend `PatchOperation` interface in `design-patch.ts`
2. **New Search Filters**: Add fields to `SearchQuery` interface in `design-index.ts`  
3. **New Brand Presets**: Add configuration to `retarget-dashboard.sh`
4. **New MCP Tools**: Implement in `figma-bridge.ts` and expose via server

### Testing

```bash
# Unit tests
npm run test:unit

# Integration tests  
npm run test:integration

# End-to-end tests
./scripts/validate-automation.sh

# Performance tests
npm run test:performance
```

## Roadmap

### Phase 1: Core Functionality ✅
- [x] Design Index with SQLite backend
- [x] Patch Specification system  
- [x] MCP Hub API endpoints
- [x] Figma Bridge integration
- [x] Basic automation scripts

### Phase 2: Enhanced Features 🚧
- [ ] Visual similarity search using AI
- [ ] Advanced brand token system
- [ ] Batch processing capabilities
- [ ] Web-based management interface
- [ ] Performance monitoring dashboard

### Phase 3: Enterprise Features 🔄
- [ ] Multi-tenant architecture
- [ ] Role-based access control
- [ ] Workflow orchestration
- [ ] Integration with design systems
- [ ] Advanced analytics and reporting

## Support

### Documentation
- **Setup Guide**: This document
- **API Reference**: [API documentation](./api-reference.md)
- **Architecture Guide**: [System architecture](./architecture.md)
- **Contributing Guide**: [Development setup](./contributing.md)

### Getting Help
- **Issues**: Report bugs and feature requests via GitHub issues
- **Discussions**: Ask questions and share ideas in GitHub discussions
- **Documentation**: Check the docs folder for detailed guides
- **Examples**: See scripts/ folder for usage examples

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

**🎉 Zero-Click Design Automation System is now fully operational!**

The system provides complete automation for finding, cloning, and modifying designs programmatically. All components are tested and ready for production use.