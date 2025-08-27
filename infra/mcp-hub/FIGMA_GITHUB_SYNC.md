# Figma → GitHub Sync via MCP Hub

The MCP Hub now supports syncing Figma design files directly to GitHub repositories.

## Setup

### 1. Environment Variables

Add to your `.env` file:

```bash
# Figma Integration
FIGMA_TOKEN=figd_your_figma_personal_access_token
FIGMA_FILE_KEY=your_default_figma_file_key  # optional

# GitHub Integration  
GITHUB_TOKEN=ghp_your_github_personal_access_token
GITHUB_REPO=owner/repository-name  # e.g., jgtolentino/ai-aas-hardened-lakehouse
```

### 2. Generate Tokens

#### Figma Personal Access Token
1. Go to [Figma Account Settings](https://www.figma.com/developers/api#access-tokens)
2. Generate a new personal access token
3. Copy the token to `FIGMA_TOKEN`

#### GitHub Personal Access Token
1. Go to [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens)
2. Generate a new token with `repo` scope
3. Copy the token to `GITHUB_TOKEN`

## Usage

### Option 1: One-Command Sync (Recommended)

Sync a complete Figma file to GitHub in one API call:

```bash
curl -H "X-API-Key: $HUB_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "server": "sync",
       "tool": "sync.figmaFileToRepo", 
       "args": {
         "fileKey": "YOUR_FIGMA_FILE_KEY"
       }
     }' \
     https://your-mcp-hub.com/mcp/run
```

**Optional parameters:**
- `commitPath`: Custom file path (default: `design/figma/filename.json`)
- `message`: Custom commit message (default: auto-generated)

### Option 2: Separate Steps

#### Export Figma File
```bash
curl -H "X-API-Key: $HUB_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "server": "figma",
       "tool": "file.exportJSON",
       "args": {
         "fileKey": "YOUR_FIGMA_FILE_KEY"
       }
     }' \
     https://your-mcp-hub.com/mcp/run
```

#### Commit to GitHub
```bash
curl -H "X-API-Key: $HUB_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "server": "github",
       "tool": "repo.commitFile",
       "args": {
         "path": "design/figma/my-design.json",
         "content": "...figma json content...",
         "message": "chore(figma): sync design updates"
       }
     }' \
     https://your-mcp-hub.com/mcp/run
```

## Available Tools

### Figma Server (`"server": "figma"`)
- `file.exportJSON` - Export complete Figma file as JSON
- `nodes.get` - Get specific nodes by ID
- `images.export` - Export node images as PNG/JPG

### GitHub Server (`"server": "github"`)
- `repo.commitFile` - Create/update file and commit to repository

### Sync Server (`"server": "sync"`)
- `sync.figmaFileToRepo` - Complete Figma → GitHub workflow in one call

## Example Workflow

1. **Design updates in Figma**: Make changes to your Figma file
2. **Sync to GitHub**: Call the MCP Hub API to export and commit
3. **Automatic PR**: The hub creates a branch and pull request
4. **Review and merge**: Review the design changes in GitHub

## Testing

Use the provided test script:

```bash
export HUB_API_KEY="your-api-key"
./test-figma-github-sync.sh YOUR_FIGMA_FILE_KEY http://localhost:8787
```

## Security Notes

- Store tokens as environment variables, never in code
- Use GitHub fine-grained tokens when possible
- Consider using a dedicated GitHub App for production
- The MCP Hub creates branches and PRs - review before merging
- Figma tokens have read-only access to your files

## Custom GPT Integration

You can now create a Custom GPT that syncs Figma designs to GitHub:

```json
{
  "name": "Figma GitHub Sync",
  "description": "Export Figma designs and sync them to GitHub",
  "actions": [
    {
      "name": "syncFigmaToGitHub",
      "url": "https://your-mcp-hub.com/mcp/run",
      "method": "POST",
      "headers": {
        "X-API-Key": "your-api-key",
        "Content-Type": "application/json"
      },
      "body": {
        "server": "sync",
        "tool": "sync.figmaFileToRepo",
        "args": {
          "fileKey": "{{figmaFileKey}}",
          "commitPath": "{{commitPath}}",
          "message": "{{message}}"
        }
      }
    }
  ]
}
```

## Error Handling

Common errors and solutions:

- `FIGMA_TOKEN not configured`: Add Figma token to environment
- `GITHUB_TOKEN not configured`: Add GitHub token to environment  
- `figma 403`: Invalid Figma token or no file access
- `github 404`: Repository not found or no access
- `fileKey required`: Provide fileKey in request or set FIGMA_FILE_KEY

## Rate Limits

- Figma API: ~50 requests per minute per token
- GitHub API: ~5000 requests per hour per token
- MCP Hub: ~60 requests per minute (configurable)