/**
 * MCP Sync Router - Orchestrates Figma → GitHub via Claude Desktop MCPs
 * No direct API calls - pure MCP-to-MCP routing
 */

import { handleFigmaMCP } from './mcp-figma-router.js';
import { handleGitHubMCP } from './mcp-github-router.js';

/**
 * Combined workflow: Figma export → GitHub commit via MCP routing
 */
export async function handleSyncMCP(tool, args) {
  try {
    switch (tool) {
      case 'sync.figmaFileToRepo':
        return await figmaFileToRepo(args);
      
      case 'sync.figmaSelectionToRepo':
        return await figmaSelectionToRepo(args);
      
      default:
        return { error: `Unknown sync tool: ${tool}` };
    }
  } catch (error) {
    return {
      error: `MCP sync routing failed: ${error.message}`,
      details: error.stack
    };
  }
}

/**
 * Export full Figma file and commit to GitHub
 */
async function figmaFileToRepo(args) {
  const { fileKey, commitPath = 'design/figma/export.json', message } = args;

  if (!fileKey) {
    return { error: 'fileKey required for Figma file export' };
  }

  // Step 1: Export Figma file via MCP
  console.log(`[sync] Exporting Figma file: ${fileKey}`);
  const figmaResult = await handleFigmaMCP('file.exportJSON', { fileKey });
  
  if (figmaResult.error) {
    return { error: `Figma export failed: ${figmaResult.error}`, details: figmaResult.details };
  }

  // Step 2: Commit to GitHub via MCP
  const commitMessage = message || `chore(figma): sync file export ${new Date().toISOString()}`;
  const content = JSON.stringify(figmaResult.data, null, 2);
  
  console.log(`[sync] Committing to GitHub: ${commitPath}`);
  const githubResult = await handleGitHubMCP('repo.commitFile', {
    path: commitPath,
    content,
    message: commitMessage
  });

  if (githubResult.error) {
    return { error: `GitHub commit failed: ${githubResult.error}`, details: githubResult.details };
  }

  return {
    success: true,
    figma: {
      fileKey,
      exportedAt: new Date().toISOString(),
      nodeCount: figmaResult.data?.document?.children?.length || 0
    },
    github: {
      path: commitPath,
      branch: githubResult.branch,
      message: commitMessage,
      committed: true
    },
    workflow: 'figma_file_to_repo_via_mcp'
  };
}

/**
 * Export Figma selection and commit to GitHub
 */
async function figmaSelectionToRepo(args) {
  const { commitPath = 'design/figma/selection.json', message } = args;

  // Step 1: Export current Figma selection via MCP
  console.log('[sync] Exporting Figma selection');
  const figmaResult = await handleFigmaMCP('nodes.get', {});
  
  if (figmaResult.error) {
    return { error: `Figma selection export failed: ${figmaResult.error}`, details: figmaResult.details };
  }

  if (!figmaResult.data || Object.keys(figmaResult.data).length === 0) {
    return { error: 'No Figma selection found. Select frames in Figma Dev Mode first.' };
  }

  // Step 2: Commit selection to GitHub via MCP
  const commitMessage = message || `chore(figma): sync selection ${new Date().toISOString()}`;
  const content = JSON.stringify(figmaResult.data, null, 2);
  
  console.log(`[sync] Committing selection to GitHub: ${commitPath}`);
  const githubResult = await handleGitHubMCP('repo.commitFile', {
    path: commitPath,
    content,
    message: commitMessage
  });

  if (githubResult.error) {
    return { error: `GitHub commit failed: ${githubResult.error}`, details: githubResult.details };
  }

  return {
    success: true,
    figma: {
      selection: Object.keys(figmaResult.data).length,
      exportedAt: new Date().toISOString()
    },
    github: {
      path: commitPath,
      branch: githubResult.branch,
      message: commitMessage,
      committed: true
    },
    workflow: 'figma_selection_to_repo_via_mcp'
  };
}