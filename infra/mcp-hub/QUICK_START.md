# 🚀 Quick Start: Figma → GitHub Sync

## 1-Minute Setup

```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse/infra/mcp-hub
./setup-figma-github-sync.sh
```

This interactive script will:
- ✅ Check prerequisites (Node.js 18+)
- ✅ Guide you through token generation
- ✅ Configure environment variables
- ✅ Install dependencies
- ✅ Test the integration

## Manual Setup (if needed)

### 1. Get Tokens
- **Figma**: https://www.figma.com/developers/api#access-tokens
- **GitHub**: https://github.com/settings/tokens (need `repo` scope)

### 2. Configure Environment
```bash
# Copy example and edit
cp .env.example .env
nano .env

# Add your tokens:
FIGMA_TOKEN=figd_your_token
GITHUB_TOKEN=ghp_your_token  
GITHUB_REPO=username/repo-name
HUB_API_KEY=your_32_char_key
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
│   ├── figma.js              # Figma API integration
│   ├── github.js             # GitHub API integration  
│   └── figma-github-sync.js  # Combined workflow
├── setup-figma-github-sync.sh # Interactive setup
├── test-figma-github-sync.sh  # End-to-end test
├── IMPLEMENTATION_GUIDE.md    # Detailed guide
└── claude-desktop-prompts.md  # Ready-to-use prompts
```

## Available Tools

| Server | Tool | Description |
|--------|------|-------------|
| `figma` | `file.exportJSON` | Export complete Figma file |
| `figma` | `nodes.get` | Get specific nodes by ID |
| `figma` | `images.export` | Export frames as images |
| `github` | `repo.commitFile` | Commit file to repository |
| `sync` | `sync.figmaFileToRepo` | One-command Figma → GitHub |

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
| `FIGMA_TOKEN not configured` | Add token to .env file |
| `figma 403` | Check token validity and file access |
| `github 404` | Verify repo name and token permissions |
| `fileKey required` | Pass fileKey in request or set FIGMA_FILE_KEY |

## Security Checklist

- ✅ Tokens stored as environment variables
- ✅ .env file in .gitignore  
- ✅ Hub API key is 32+ characters
- ✅ GitHub token has minimal required scopes
- ✅ Production uses platform environment variables

## Support

- 📚 Full guide: `IMPLEMENTATION_GUIDE.md`
- 🤖 Claude prompts: `claude-desktop-prompts.md`
- 🔧 Custom GPT config: `custom-gpt-config.json`
- 🧪 Test script: `test-figma-github-sync.sh`