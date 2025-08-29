# 🚀 Figma → GitHub Sync Implementation Guide (MCP Architecture)

Complete guide for implementing Figma to GitHub sync via MCP Hub with Claude Desktop MCPs handling authentication.

## Architecture Overview

The MCP Hub now operates as a **routing layer** that forwards requests to Claude Desktop MCPs:
- **Figma MCP**: Runs in Figma Desktop (Dev Mode), uses your Figma session auth
- **GitHub MCP**: Runs in Claude Desktop, uses your configured GitHub auth
- **MCP Hub**: Routes requests between services, no tokens needed for Figma/GitHub

## Prerequisites

- Node.js 18+ installed
- Figma Desktop with Dev Mode MCP Server enabled
- Claude Desktop with GitHub MCP configured
- Access to target GitHub repository
- MCP Hub with Supabase configured (if using analytics)

---

## Step 1: Set Up Claude Desktop MCPs

### 1.1 Configure Figma Dev Mode MCP

1. **Open Figma Desktop**
2. **Enable Dev Mode MCP Server**
   - Go to Figma → Preferences → Advanced
   - Enable "Dev Mode MCP Server"
   - Restart Figma if prompted

3. **Verify in Claude Desktop**
   - Open Claude Desktop
   - Check that Figma MCP appears in connected servers
   - You should see tools like `get_code`, `get_image`, etc.

### 1.2 Configure GitHub MCP in Claude Desktop

1. **Edit Claude Desktop Config**
   ```bash
   # Location varies by OS:
   # macOS: ~/Library/Application Support/Claude/claude_desktop_config.json
   # Windows: %APPDATA%\Claude\claude_desktop_config.json
   # Linux: ~/.config/Claude/claude_desktop_config.json
   ```

2. **Add GitHub MCP Configuration**
   ```json
   {
     "mcpServers": {
       "github": {
         "command": "npx",
         "args": ["-y", "@modelcontextprotocol/server-github"],
         "env": {
           "GITHUB_PERSONAL_ACCESS_TOKEN": "your-github-pat-here"
         }
       }
     }
   }
   ```

3. **Generate GitHub PAT** (if not already done)
   - Visit: https://github.com/settings/tokens
   - Create token with `repo` scope
   - Add to Claude Desktop config above

4. **Restart Claude Desktop**
   - Verify GitHub MCP appears in connected servers

---

## Step 2: Configure MCP Hub Environment

### 2.1 Update Environment File

```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse/infra/mcp-hub
cp .env.example .env
```

### 2.2 Edit .env File

```bash
# MCP Hub Configuration
PORT=8787
HUB_API_KEY=your-secure-32-char-api-key  # Generate a secure key

# Supabase (for analytics/data operations)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PROJECT_REF=your-project-ref
SUPABASE_SERVICE_ROLE=your-service-role-key  # Use read-only if possible

# Mapbox (if using geographic features)
MAPBOX_TOKEN=your-mapbox-token-if-needed

# GitHub Repository Target
GITHUB_REPO=jgtolentino/ai-aas-hardened-lakehouse

# NO TOKENS NEEDED for Figma or GitHub - handled by Claude Desktop MCPs!
```

---

## Step 3: Install and Build MCP Hub

### 3.1 Install Dependencies

```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse/infra/mcp-hub
npm install
```

### 3.2 Start MCP Hub

```bash
npm start
```

Expected output:
```
[mcp-hub] listening on :8787
```

### 3.3 Verify Setup

```bash
# Health check
curl http://localhost:8787/health
# Expected: {"ok":true}

# Check available servers
curl http://localhost:8787/openapi.json | jq '.paths."/mcp/run".post.requestBody.content."application/json".schema.properties.server.enum'
# Expected: ["supabase","mapbox","figma","github","sync"]
```

---

## Step 4: Test the Integration

### 4.1 Test via Claude Desktop

In Claude Desktop, you can now use commands like:

```
Use the Figma MCP to get the current selection's data, then commit it to GitHub via the MCP Hub.
```

Claude will:
1. Use local Figma MCP to get selection data
2. Route through MCP Hub to commit to GitHub
3. No tokens needed in the Hub!

### 4.2 Test Direct Hub Calls

```bash
# Set your API key
export HUB_API_KEY="your-hub-api-key"

# Test routing to Figma MCP (requires Figma Desktop running)
curl -H "X-API-Key: $HUB_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "server": "figma",
       "tool": "get_code",
       "args": {}
     }' \
     http://localhost:8787/mcp/run

# Test routing to GitHub MCP (requires Claude Desktop with GitHub MCP)
curl -H "X-API-Key: $HUB_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "server": "github",
       "tool": "search_repositories",
       "args": {"query": "mcp"}
     }' \
     http://localhost:8787/mcp/run
```

---

## Step 5: Production Deployment

### 5.1 Deploy to Vercel/Render/Railway

```bash
# Example with Vercel
npm i -g vercel
cd /Users/tbwa/ai-aas-hardened-lakehouse/infra/mcp-hub
vercel --prod
```

### 5.2 Set Production Environment Variables

In your hosting platform, set only these variables:
- `HUB_API_KEY` (secure 32+ character key)
- `SUPABASE_URL` (if using)
- `SUPABASE_PROJECT_REF` (if using)
- `SUPABASE_SERVICE_ROLE` (if using)
- `MAPBOX_TOKEN` (if using geographic features)
- `GITHUB_REPO` (your target repository)

**DO NOT** set `FIGMA_TOKEN` or `GITHUB_TOKEN` - these are handled by Claude Desktop MCPs!

---

## Step 6: Usage Patterns

### 6.1 Figma Selection → GitHub Commit

```javascript
// This happens automatically via MCP routing
// 1. Claude Desktop Figma MCP gets selection
// 2. MCP Hub routes commit request to GitHub MCP
// 3. GitHub MCP (with its own auth) commits the file
```

### 6.2 Custom GPT Integration

Configure your Custom GPT to call the MCP Hub:

```json
{
  "name": "Design Sync Assistant",
  "actions": [{
    "openapi": {
      "servers": [{
        "url": "https://your-mcp-hub.vercel.app"
      }],
      "paths": {
        "/mcp/run": {
          "post": {
            "security": [{
              "ApiKeyAuth": []
            }],
            "requestBody": {
              "content": {
                "application/json": {
                  "schema": {
                    "properties": {
                      "server": {"enum": ["sync"]},
                      "tool": {"type": "string"},
                      "args": {"type": "object"}
                    }
                  }
                }
              }
            }
          }
        }
      },
      "components": {
        "securitySchemes": {
          "ApiKeyAuth": {
            "type": "apiKey",
            "in": "header",
            "name": "X-API-Key"
          }
        }
      }
    }
  }],
  "auth": {
    "type": "api_key",
    "api_key": "your-hub-api-key"
  }
}
```

---

## Step 7: Troubleshooting

### Common Issues

**"Figma MCP not connected"**
- Ensure Figma Desktop is running with Dev Mode MCP enabled
- Check Claude Desktop shows Figma in connected servers
- Restart both applications if needed

**"GitHub MCP not responding"**
- Verify GitHub MCP is configured in Claude Desktop
- Check that GitHub PAT is valid and has `repo` scope
- Restart Claude Desktop

**"MCP Hub routing failed"**
- Check MCP Hub is running (`npm start`)
- Verify `HUB_API_KEY` is set correctly
- Check logs for specific routing errors

**"Authentication error" (should not happen)**
- This architecture eliminates token errors for Figma/GitHub
- If you see auth errors, check you're using the updated MCP Hub
- Ensure you're NOT passing FIGMA_TOKEN or GITHUB_TOKEN to the Hub

---

## Step 8: Security Best Practices

### 8.1 Token Security
- **GitHub PAT**: Only stored in Claude Desktop config (local)
- **Figma Auth**: Uses your Figma Desktop session (no token needed)
- **Hub API Key**: Use strong 32+ character key, rotate regularly
- **Supabase**: Use read-only service role when possible

### 8.2 Network Security
- MCP Hub should use HTTPS in production
- Set CORS policies appropriately
- Implement rate limiting for API endpoints
- Monitor for unusual activity patterns

### 8.3 Repository Security
- Use branch protection rules for main/master
- Require PR reviews for design sync branches
- Set up CODEOWNERS for design directories
- Regular audit of committed design files

---

## ✅ Implementation Complete!

Your Figma → GitHub sync system is now configured with:

- ✅ **Zero Token Management** in MCP Hub (handled by Claude Desktop)
- ✅ **Secure MCP Routing** (stdio protocol, no exposed credentials)
- ✅ **Local Authentication** (Figma session + GitHub PAT in Claude)
- ✅ **Production Ready** (scalable and maintainable)
- ✅ **Enhanced Security** (tokens never leave local environment)

The new architecture is more secure, easier to maintain, and eliminates token-related errors! 🎉