import { handleFigma } from "./figma.js";
import { handleGitHub } from "./github.js";

/**
 * Combined Figma → GitHub sync tool
 * Exports a Figma file and commits it to GitHub in one operation
 */
export async function handleFigmaGitHubSync(tool, args) {
  if (tool === "sync.figmaFileToRepo") {
    const { fileKey, commitPath, message } = args || {};
    
    if (!fileKey) return { error: "fileKey required" };
    
    // Step 1: Export Figma file
    console.log(`[figma-sync] Exporting Figma file: ${fileKey}`);
    const figmaResult = await handleFigma("file.exportJSON", { fileKey });
    
    if (figmaResult.error) {
      return { error: `Figma export failed: ${figmaResult.error}`, details: figmaResult.details };
    }
    
    // Step 2: Prepare commit data
    const fileName = figmaResult.name || "Figma File";
    const lastModified = figmaResult.lastModified || new Date().toISOString();
    const autoCommitPath = commitPath || `design/figma/${fileName.replace(/\s+/g, '_').toLowerCase()}.json`;
    const autoMessage = message || `chore(figma): sync ${fileName} - ${lastModified}`;
    
    console.log(`[figma-sync] Committing to GitHub: ${autoCommitPath}`);
    
    // Step 3: Commit to GitHub
    const githubResult = await handleGitHub("repo.commitFile", {
      path: autoCommitPath,
      content: JSON.stringify(figmaResult, null, 2),
      message: autoMessage
    });
    
    if (githubResult.error) {
      return { 
        error: `GitHub commit failed: ${githubResult.error}`, 
        details: githubResult.details,
        figmaData: figmaResult // Include the exported data for debugging
      };
    }
    
    return {
      success: true,
      figma: {
        fileName,
        lastModified,
        nodeCount: figmaResult.document?.children?.length || 0
      },
      github: {
        branch: githubResult.branch,
        path: autoCommitPath,
        message: autoMessage
      }
    };
  }
  
  return { error: `unsupported tool: ${tool}` };
}