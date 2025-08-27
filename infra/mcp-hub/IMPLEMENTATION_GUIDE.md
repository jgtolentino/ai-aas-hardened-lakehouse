# 🚀 Figma → GitHub Sync Implementation Guide

Complete step-by-step guide to implement the Figma to GitHub sync system via MCP Hub.

## Prerequisites

- Node.js 18+ installed
- Access to Figma files you want to sync
- GitHub repository where you want to commit design files
- MCP Hub running (existing Supabase + Mapbox setup)

---

## Step 1: Generate Required Tokens

### 1.1 Generate Figma Personal Access Token

1. **Go to Figma Account Settings**
   - Visit: https://www.figma.com/developers/api#access-tokens
   - Or: Figma → Profile → Settings → Account → Personal access tokens

2. **Create New Token**
   - Click "Create a new personal access token"
   - Name: `MCP Hub Integration`
   - Description: `Token for automated design sync to GitHub`
   - Click "Create token"

3. **Copy Token**
   - ⚠️ **Important**: Copy the token immediately - it won't be shown again
   - Format: `figd_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
   - Save securely (we'll add to .env file)

### 1.2 Generate GitHub Personal Access Token

1. **Go to GitHub Settings**
   - Visit: https://github.com/settings/tokens
   - Or: GitHub → Profile → Settings → Developer settings → Personal access tokens → Tokens (classic)

2. **Generate New Token**
   - Click "Generate new token" → "Generate new token (classic)"
   - Note: `MCP Hub Figma Sync`
   - Expiration: `90 days` (or custom)
   - **Required Scopes**:
     - ✅ `repo` (Full control of private repositories)
     - ✅ `workflow` (Update GitHub Action workflows) - optional but recommended

3. **Copy Token**
   - Format: `ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
   - Save securely

---

## Step 2: Configure Environment Variables

### 2.1 Update MCP Hub Environment File

```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse/infra/mcp-hub
cp .env.example .env
```

### 2.2 Edit .env File

```bash
# Existing configuration
PORT=8787
HUB_API_KEY=your-secure-32-char-api-key

# Existing adapters
SUPABASE_URL=your-supabase-url
SUPABASE_SERVICE_ROLE=your-supabase-service-role-key
MAPBOX_TOKEN=your-mapbox-token

# NEW: Figma Integration
FIGMA_TOKEN=figd_your_figma_personal_access_token
FIGMA_FILE_KEY=your_default_figma_file_key_optional

# NEW: GitHub Integration  
GITHUB_TOKEN=ghp_your_github_personal_access_token
GITHUB_REPO=your-username/your-repo-name
```

### 2.3 Find Your Figma File Key (Optional Default)

1. Open your Figma file in browser
2. Copy the file key from URL:
   ```
   https://www.figma.com/file/ABC123DEF456/Your-File-Name
                              ^^^^^^^^^^^^
                              This is your file key
   ```
3. Add to `FIGMA_FILE_KEY=ABC123DEF456` (optional - you can pass per-request)

---

## Step 3: Install Dependencies and Build

### 3.1 Install Node Dependencies

```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse/infra/mcp-hub
npm install
```

### 3.2 Verify New Adapters Are Included

```bash
# Check if new adapter files exist
ls -la src/adapters/
# Should show: figma.js, github.js, figma-github-sync.js
```

---

## Step 4: Test the Implementation

### 4.1 Start MCP Hub Locally

```bash
cd /Users/tbwa/ai-aas-hardened-lakehouse/infra/mcp-hub
npm start
```

Expected output:
```
[mcp-hub] listening on :8787
```

### 4.2 Test Health Check

```bash
curl http://localhost:8787/health
# Expected: {"ok":true}
```

### 4.3 Test OpenAPI Schema

```bash
curl http://localhost:8787/openapi.json | jq '.paths."/mcp/run".post.requestBody.content."application/json".schema.properties.server.enum'
# Expected: ["supabase","mapbox","figma","github","sync"]
```

### 4.4 Run End-to-End Test

```bash
# Set your tokens
export HUB_API_KEY="your-hub-api-key"

# Test with your Figma file
./test-figma-github-sync.sh YOUR_FIGMA_FILE_KEY http://localhost:8787
```

Expected successful output:
```
🚀 Testing Figma → GitHub sync workflow
📋 Step 1: Exporting Figma file JSON...
✅ Successfully exported: Your File Name (modified: 2024-01-15T10:30:00.000Z)
💾 Step 2: Committing to GitHub...
✅ Successfully committed to branch: chore/figma-sync
📁 File path: design/figma/your_file_name.json
🎉 End-to-end test completed!
```

---

## Step 5: Deploy to Production

### 5.1 Choose Deployment Method

**Option A: Vercel (Recommended)**
```bash
# Install Vercel CLI
npm i -g vercel

# Deploy from mcp-hub directory
cd /Users/tbwa/ai-aas-hardened-lakehouse/infra/mcp-hub
vercel --prod

# Set environment variables in Vercel dashboard
```

**Option B: Railway**
```bash
# Install Railway CLI
npm i -g @railway/cli

# Deploy
railway login
railway link
railway up
```

**Option C: Render/Heroku**
- Push code to Git repository
- Connect to hosting platform
- Set environment variables in dashboard

### 5.2 Update Environment Variables in Production

Set these in your hosting platform dashboard:
- `HUB_API_KEY`
- `FIGMA_TOKEN`
- `GITHUB_TOKEN`
- `GITHUB_REPO`
- `FIGMA_FILE_KEY` (optional)

---

## Step 6: Create Usage Templates

### 6.1 Claude Desktop Selection Sync Template

Save this prompt for easy access:

```
# Figma Selection → GitHub PR via MCP Hub

GOAL: Export current Figma selection and commit to GitHub via MCP Hub

STEPS:
1. Use local Figma MCP to export my current selection as JSON
2. POST to MCP Hub: server="github", tool="repo.commitFile"
   - path: "design/figma/selection.json"  
   - content: <exported JSON>
   - message: "chore(figma): sync selection from Figma Dev Mode"
   - branch: "chore/figma-sync"
3. Return commit status and PR link

CONFIG:
- Hub URL: https://your-mcp-hub-domain.com
- Never log tokens or request bodies
- If selection > 1.5MB, split into multiple files
```

### 6.2 Custom GPT Action Configuration

```json
{
  "name": "Sync Figma to GitHub",
  "description": "Export Figma designs and sync to GitHub repository",
  "openapi": {
    "openapi": "3.0.0",
    "info": {
      "title": "Figma GitHub Sync",
      "version": "1.0.0"
    },
    "servers": [
      {
        "url": "https://your-mcp-hub-domain.com"
      }
    ],
    "paths": {
      "/mcp/run": {
        "post": {
          "operationId": "syncFigmaToGitHub",
          "summary": "Sync Figma file to GitHub",
          "security": [
            {
              "ApiKeyAuth": []
            }
          ],
          "requestBody": {
            "required": true,
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "server": {
                      "type": "string",
                      "enum": ["sync"]
                    },
                    "tool": {
                      "type": "string",
                      "enum": ["sync.figmaFileToRepo"]
                    },
                    "args": {
                      "type": "object",
                      "properties": {
                        "fileKey": {
                          "type": "string",
                          "description": "Figma file key from URL"
                        },
                        "commitPath": {
                          "type": "string",
                          "description": "Path in repo (optional)"
                        },
                        "message": {
                          "type": "string",
                          "description": "Commit message (optional)"
                        }
                      },
                      "required": ["fileKey"]
                    }
                  },
                  "required": ["server", "tool", "args"]
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Success",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object"
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
  },
  "auth": {
    "type": "api_key",
    "api_key": "your-hub-api-key"
  }
}
```

---

## Step 7: Usage Examples

### 7.1 One-Command Sync (cURL)

```bash
curl -H "X-API-Key: $HUB_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "server": "sync",
       "tool": "sync.figmaFileToRepo",
       "args": {
         "fileKey": "ABC123DEF456"
       }
     }' \
     https://your-mcp-hub-domain.com/mcp/run
```

### 7.2 Custom Path and Message

```bash
curl -H "X-API-Key: $HUB_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "server": "sync", 
       "tool": "sync.figmaFileToRepo",
       "args": {
         "fileKey": "ABC123DEF456",
         "commitPath": "docs/designs/homepage-v2.json",
         "message": "feat(design): update homepage layout v2"
       }
     }' \
     https://your-mcp-hub-domain.com/mcp/run
```

### 7.3 Separate Steps (Export → Commit)

```bash
# Step 1: Export Figma file
curl -H "X-API-Key: $HUB_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "server": "figma",
       "tool": "file.exportJSON", 
       "args": {"fileKey": "ABC123DEF456"}
     }' \
     https://your-mcp-hub-domain.com/mcp/run > figma-export.json

# Step 2: Commit to GitHub  
curl -H "X-API-Key: $HUB_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "server": "github",
       "tool": "repo.commitFile",
       "args": {
         "path": "design/figma/export.json",
         "content": "'$(jq -c .data figma-export.json)'", 
         "message": "chore(figma): sync design updates"
       }
     }' \
     https://your-mcp-hub-domain.com/mcp/run
```

---

## Step 8: Troubleshooting

### Common Issues and Solutions

**Error: `FIGMA_TOKEN not configured`**
- Check `.env` file has correct token
- Verify token format: `figd_XXXXXXXXX...`
- Ensure no extra spaces/quotes

**Error: `GITHUB_TOKEN not configured`**  
- Check `.env` file has correct token
- Verify token format: `ghp_XXXXXXXXX...`
- Ensure token has `repo` scope

**Error: `figma 403`**
- Token may be invalid or expired
- File may be private and token lacks access
- Regenerate Figma token if needed

**Error: `github 404`**
- Repository name incorrect in `GITHUB_REPO`
- Token lacks access to repository
- Repository may be private and token lacks permissions

**Error: `fileKey required`**
- Pass `fileKey` in request args
- Or set `FIGMA_FILE_KEY` in environment

---

## Step 9: Monitoring and Maintenance

### 9.1 Set Up Logging

Monitor your MCP Hub logs for:
- API rate limits (Figma: ~50/min, GitHub: ~5000/hour)
- Authentication failures
- Large payload warnings
- Successful syncs

### 9.2 Token Rotation

- **GitHub tokens**: Set 90-day expiration, rotate regularly
- **Figma tokens**: No expiration by default, but rotate if compromised
- Update environment variables in production when rotating

### 9.3 Repository Maintenance

- Review PRs created by automated sync
- Clean up old `chore/figma-sync` branches periodically
- Monitor repository size if syncing large files frequently

---

## ✅ Implementation Complete!

You now have a fully functional Figma → GitHub sync system with:

- ✅ **Local selection sync** (Claude Desktop + Figma MCP)
- ✅ **Automated file sync** (MCP Hub + API)
- ✅ **Custom GPT integration** (One-click sync)
- ✅ **Production deployment** (Scalable and secure)
- ✅ **Comprehensive monitoring** (Error handling and logging)

Your design-to-code workflow is now fully automated! 🎉