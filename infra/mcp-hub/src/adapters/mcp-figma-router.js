/**
 * MCP Figma Router - Delegates to Claude Desktop's Figma MCP
 * No tokens needed - routes through Claude Desktop's MCP servers
 */

import { spawn } from 'child_process';

const FIGMA_MCP_PATH = '/Users/tbwa/Library/Application Support/Claude/Claude Extensions/ant.dir.ant.figma.figma/server/index.js';

/**
 * Route tool calls to Claude Desktop's Figma MCP
 */
export async function handleFigmaMCP(tool, args) {
  try {
    // Map our tool names to Claude Desktop MCP equivalents
    const toolMappings = {
      'file.exportJSON': 'get_file_data',
      'nodes.get': 'get_selection', 
      'images.export': 'export_images'
    };

    const mcpTool = toolMappings[tool] || tool;

    // Call Claude Desktop's Figma MCP via stdio
    const result = await callMCPServer(FIGMA_MCP_PATH, mcpTool, args);
    
    return {
      success: true,
      data: result,
      source: 'claude_desktop_figma_mcp'
    };

  } catch (error) {
    return {
      error: `MCP Figma routing failed: ${error.message}`,
      details: error.stack
    };
  }
}

/**
 * Helper: Call MCP server via stdio protocol
 */
async function callMCPServer(serverPath, tool, args) {
  return new Promise((resolve, reject) => {
    const mcp = spawn('node', [serverPath]);
    
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
            reject(new Error(response.error.message || 'MCP tool call failed'));
          } else {
            resolve(response.result);
          }
        } catch (parseError) {
          reject(new Error(`MCP response parsing failed: ${parseError.message}`));
        }
      } else {
        reject(new Error(`MCP server exited with code ${code}: ${stderr}`));
      }
    });

    // Timeout after 30 seconds
    setTimeout(() => {
      mcp.kill();
      reject(new Error('MCP call timeout'));
    }, 30000);
  });
}