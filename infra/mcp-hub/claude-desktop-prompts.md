# Claude Desktop Prompt Templates

## Figma Selection → GitHub PR

Use this prompt when you have frames selected in Figma Dev Mode:

```
# Figma Selection → GitHub Sync

OBJECTIVE: Export my current Figma selection and commit to GitHub

STEPS:
1. Use local Figma MCP to export current selection as JSON:
   - Include: id, name, type, width, height, componentId, constraints
   - Include: styles, variables, layout properties if available
   - Format as compact JSON

2. Send to MCP Hub for GitHub commit:
   - Hub URL: https://your-mcp-hub-domain.com/mcp/run
   - Headers: X-API-Key (use environment variable)
   - Body: {
       "server": "github",
       "tool": "repo.commitFile", 
       "args": {
         "path": "design/figma/selection.json",
         "content": "<exported_json_from_step_1>",
         "message": "chore(figma): sync selection from Dev Mode",
         "branch": "chore/figma-sync"
       }
     }

3. Report results:
   - Branch created/updated
   - File path in repository
   - PR link if created
   - Any warnings or errors

REQUIREMENTS:
- Never log tokens or sensitive data
- Minify JSON content before sending
- Handle errors gracefully
- If no selection exists, stop with message
```

## Whole Figma File → GitHub

Use this prompt to sync entire Figma files:

```
# Whole Figma File → GitHub Sync

OBJECTIVE: Export entire Figma file and commit to GitHub

CONFIG:
- Figma File Key: [PROVIDE_FILE_KEY_OR_ASK]
- Hub URL: https://your-mcp-hub-domain.com/mcp/run

STEPS:
1. Call MCP Hub sync endpoint:
   POST /mcp/run
   {
     "server": "sync",
     "tool": "sync.figmaFileToRepo",
     "args": {
       "fileKey": "[FILE_KEY]",
       "commitPath": "design/figma/[filename].json",
       "message": "chore(figma): sync complete file export"
     }
   }

2. Report results:
   - File name and last modified date
   - Commit path and branch
   - PR status
   - Node count and file size

REQUIREMENTS:
- Ask for file key if not provided
- Handle API errors with helpful messages  
- Show progress for large files
```

## Figma Images Export → GitHub

Use this for exporting specific frames as images:

```
# Figma Images → GitHub

OBJECTIVE: Export Figma frames as images and commit to GitHub

STEPS:
1. Get frame/node IDs from user or current selection
2. Call Figma images export:
   {
     "server": "figma",
     "tool": "images.export",
     "args": {
       "fileKey": "[FILE_KEY]",
       "ids": ["frame_id_1", "frame_id_2"],
       "format": "png",
       "scale": "2"
     }
   }

3. Download images from returned URLs
4. For each image, commit to GitHub:
   - Path: design/figma/images/[frame_name].png
   - Base64 encode image content
   - Separate commit per image or batch commit

5. Report all committed images and paths

REQUIREMENTS:
- Handle image download failures
- Validate image formats
- Use descriptive commit messages
```

## Error Handling Template

Add this to any Figma-related prompt:

```
ERROR HANDLING:
- "FIGMA_TOKEN not configured" → Check MCP Hub environment
- "GITHUB_TOKEN not configured" → Check MCP Hub environment  
- "figma 403" → Token invalid or no file access
- "github 404" → Repository not found or no access
- "fileKey required" → Ask user for Figma file key
- Rate limits → Retry with exponential backoff
- Large payloads → Chunk into multiple files

NEVER:
- Log request/response bodies containing tokens
- Expose API keys in output
- Continue on authentication errors
```

## Usage Instructions

1. **Copy the desired prompt template**
2. **Replace placeholders:**
   - `[FILE_KEY]` with actual Figma file key
   - `your-mcp-hub-domain.com` with your deployed hub URL
3. **Paste into Claude Desktop**
4. **Make sure you have:**
   - Figma file/frames selected (for selection prompts)
   - MCP Hub running and accessible
   - Required environment variables configured

## Quick Commands

### Test Hub Connection
```
Test my MCP Hub connection at https://your-domain.com by calling the health endpoint
```

### Get Figma File Info
```
Using local Figma MCP, get basic info about the current Figma file (name, last modified, page count)
```

### List Current Selection
```
Using local Figma MCP, show me details about my current selection (node IDs, names, types)
```