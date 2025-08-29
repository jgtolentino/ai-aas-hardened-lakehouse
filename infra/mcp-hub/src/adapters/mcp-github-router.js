/**
 * MCP GitHub Router - Delegates to Claude Desktop's GitHub MCP
 * No tokens needed - routes through Claude Desktop's MCP servers
 */

import { spawn } from 'child_process';

// GitHub MCP is likely installed via npm/npx
const GITHUB_MCP_COMMAND = 'npx';
const GITHUB_MCP_ARGS = ['-y', '@modelcontextprotocol/server-github'];

/**
 * Route tool calls to Claude Desktop's GitHub MCP
 */
export async function handleGitHubMCP(tool, args) {
  try {
    // Map our tool names to GitHub MCP equivalents
    const toolMappings = {
      'repo.commitFile': 'create_or_update_file',
      'repo.createBranch': 'create_branch',
      'repo.createPR': 'create_pull_request'
    };

    const mcpTool = toolMappings[tool] || tool;

    // Transform args to match GitHub MCP expectations
    const transformedArgs = transformArgsForGitHubMCP(tool, args);

    // Call Claude Desktop's GitHub MCP via stdio
    const result = await callMCPServer(mcpTool, transformedArgs);
    
    return {
      success: true,
      data: result,
      source: 'claude_desktop_github_mcp',
      branch: transformedArgs.branch || 'main'
    };

  } catch (error) {
    return {
      error: `MCP GitHub routing failed: ${error.message}`,
      details: error.stack
    };
  }
}

/**
 * Transform our args to match GitHub MCP's expected format
 */
function transformArgsForGitHubMCP(tool, args) {
  switch (tool) {
    case 'repo.commitFile':
      return {
        owner: process.env.GITHUB_REPO?.split('/')[0] || 'tbwa',
        repo: process.env.GITHUB_REPO?.split('/')[1] || 'ai-aas-hardened-lakehouse', 
        path: args.path,
        content: args.content,
        message: args.message,
        branch: args.branch || `chore/figma-sync-${Date.now()}`
      };
    default:
      return args;
  }
}

/**
 * Helper: Call GitHub MCP server via stdio protocol
 */
async function callMCPServer(tool, args) {
  return new Promise((resolve, reject) => {
    const mcp = spawn(GITHUB_MCP_COMMAND, GITHUB_MCP_ARGS);
    
    let stdout = '';
    let stderr = '';
    
    // Prepare MCP request
    const request = {
      jsonrpc: '2.0',
      id: 1,
      method: 'tools/call',
      params: {
        name: tool,
        arguments: args || {}
      }
    };

    // Send request
    mcp.stdin.write(JSON.stringify(request) + '\n');
    mcp.stdin.end();

    // Collect response
    mcp.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    mcp.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    mcp.on('close', (code) => {
      if (code === 0) {
        try {
          // Parse MCP response
          const lines = stdout.trim().split('\n');
          const lastLine = lines[lines.length - 1];
          const response = JSON.parse(lastLine);
          
          if (response.error) {
            reject(new Error(response.error.message || 'GitHub MCP tool call failed'));
          } else {
            resolve(response.result);
          }
        } catch (parseError) {
          reject(new Error(`GitHub MCP response parsing failed: ${parseError.message}`));
        }
      } else {
        reject(new Error(`GitHub MCP server exited with code ${code}: ${stderr}`));
      }
    });

    // Timeout after 30 seconds
    setTimeout(() => {
      mcp.kill();
      reject(new Error('GitHub MCP call timeout'));
    }, 30000);
  });
}