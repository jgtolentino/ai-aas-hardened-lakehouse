# 🚀 Quick Start: Figma → GitHub Sync (MCP Routing)

## Prerequisites
- Claude Desktop with Figma MCP and GitHub MCP configured
- MCP Hub running locally
- No API tokens needed (managed by Claude Desktop)

## 1-Minute Setup

```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse/infra/mcp-hub
cp .env.example .env
# Only set: HUB_API_KEY and GITHUB_REPO (no tokens needed)
npm install
npm start
```

## Key Advantages of MCP Routing

- **No duplicate token management**: Uses Claude Desktop's existing MCPs
- **Selection-aware**: Works with current Figma selection in Dev Mode
- **Secure**: Routes via stdio protocol (no exposed tokens)
- **Simplified**: Only need to identify target repository

## Environment Configuration

```bash
# .env file - minimal configuration
HUB_API_KEY=your_32_char_key
GITHUB_REPO=username/repo-name

# That's it! No FIGMA_TOKEN or GITHUB_TOKEN needed
```

### 3. Install & Start
```bash
npm install
npm start
```

## Usage Examples

### One-Command Sync
```bash
curl -H "X-API-Key: $HUB_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"server":"sync","tool":"sync.figmaFileToRepo","args":{"fileKey":"YOUR_FILE_KEY"}}' \
     https://your-domain.com/mcp/run
```

### Claude Desktop Selection
```
Use local Figma MCP to export my selection, then send to MCP Hub to commit as design/figma/selection.json
```

### Custom GPT
Import `custom-gpt-config.json` into ChatGPT

## File Structure
```
infra/mcp-hub/
├── src/adapters/
│   ├── mcp-figma-router.js      # Routes to Claude Desktop Figma MCP
│   ├── mcp-github-router.js     # Routes to Claude Desktop GitHub MCP  
│   ├── mcp-sync-router.js       # Orchestrates Figma → GitHub workflows
│   ├── supabase.js              # Direct Supabase adapter
│   └── mapbox.js                # Direct Mapbox adapter
├── IMPLEMENTATION_GUIDE.md      # Detailed guide
└── claude-desktop-prompts.md    # Ready-to-use prompts
```

## Available Tools (MCP Routing)

| Server | Tool | Description | Routes To |
|--------|------|-------------|-----------|
| `figma` | `file.exportJSON` | Export complete Figma file | Claude Desktop Figma MCP |
| `figma` | `nodes.get` | Get current selection | Claude Desktop Figma MCP |
| `figma` | `images.export` | Export frames as images | Claude Desktop Figma MCP |
| `github` | `repo.commitFile` | Commit file to repository | Claude Desktop GitHub MCP |
| `sync` | `sync.figmaFileToRepo` | One-command Figma → GitHub | Both MCPs |
| `sync` | `sync.figmaSelectionToRepo` | Export selection and commit | Both MCPs |

## Deployment Options

### Vercel (Recommended)
```bash
npm i -g vercel
vercel --prod
# Set env vars in dashboard
```

### Railway
```bash
npm i -g @railway/cli
railway up
```

### Render/Heroku
- Push to Git
- Connect to platform
- Set environment variables

## Testing

```bash
# Health check
curl http://localhost:8787/health

# Full test (replace with your file key)
./test-figma-github-sync.sh ABC123DEF456 http://localhost:8787
```

## Troubleshooting

| Error | Solution |
|-------|----------|
| `MCP Figma routing failed` | Ensure Claude Desktop Figma MCP is running |
| `GitHub MCP server exited` | Verify Claude Desktop GitHub MCP is configured |
| `Figma selection export failed` | Select frames in Figma Dev Mode first |
| `MCP call timeout` | Check if Claude Desktop MCPs are responding |

## Security Checklist

- ✅ No duplicate tokens stored (uses Claude Desktop MCPs)
- ✅ .env file only contains HUB_API_KEY and GITHUB_REPO  
- ✅ Hub API key is 32+ characters
- ✅ MCP routing uses secure stdio protocol
- ✅ Production uses platform environment variables

## Support

- 📚 Full guide: `IMPLEMENTATION_GUIDE.md`
- 🤖 Claude prompts: `claude-desktop-prompts.md`
- 🔧 Custom GPT config: `custom-gpt-config.json`
- 🧪 Test script: `test-figma-github-sync.sh`