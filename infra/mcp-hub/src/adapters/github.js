import fetch from "node-fetch";

export async function handleGitHub(tool, args) {
  const token = process.env.GITHUB_TOKEN;
  const repo = process.env.GITHUB_REPO;
  if (!token || !repo) throw new Error("GitHub adapter not configured: GITHUB_TOKEN and GITHUB_REPO");

  if (tool === "repo.commitFile") {
    const { path, content, message, branch = "chore/figma-sync" } = args || {};
    if (!path || typeof content !== "string" || !message) return { error: "path, content, message required" };

    // Get current file (to fetch sha if exists)
    const baseUrl = `https://api.github.com/repos/${repo}/contents/${encodeURIComponent(path)}`;
    const headers = { Authorization: `Bearer ${token}`, "Accept": "application/vnd.github+json" };

    let sha = undefined;
    const probe = await fetch(`${baseUrl}?ref=${encodeURIComponent(branch)}`, { headers });
    if (probe.status === 200) {
      const j = await probe.json();
      sha = j.sha;
    }

    // Ensure branch exists (create from default if missing)
    const repoResp = await fetch(`https://api.github.com/repos/${repo}`, { headers });
    const repoInfo = await repoResp.json();
    const defaultBranch = repoInfo.default_branch || "main";

    // Create branch if missing
    const refResp = await fetch(`https://api.github.com/repos/${repo}/git/ref/heads/${branch}`, { headers });
    if (refResp.status === 404) {
      const baseRef = await fetch(`https://api.github.com/repos/${repo}/git/ref/heads/${defaultBranch}`, { headers });
      if (!baseRef.ok) return { error: "cannot read default branch ref", details: await baseRef.text() };
      const base = await baseRef.json();
      const createRef = await fetch(`https://api.github.com/repos/${repo}/git/refs`, {
        method: "POST",
        headers,
        body: JSON.stringify({ ref: `refs/heads/${branch}`, sha: base.object.sha })
      });
      if (!createRef.ok) return { error: "cannot create branch", details: await createRef.text() };
    }

    // Commit the file
    const put = await fetch(baseUrl, {
      method: "PUT",
      headers,
      body: JSON.stringify({
        message,
        content: Buffer.from(content, "utf8").toString("base64"),
        branch,
        sha
      })
    });
    if (!put.ok) return { error: `github ${put.status}`, details: await put.text() };
    const res = await put.json();

    // Create PR (idempotent best-effort)
    const prs = await fetch(`https://api.github.com/repos/${repo}/pulls`, {
      method: "POST",
      headers,
      body: JSON.stringify({
        title: message,
        head: branch,
        base: defaultBranch,
        body: "Automated Figma → Repo sync via MCP Hub"
      })
    });
    // Ignore PR creation failure (e.g., already exists)
    return { ok: true, content: res.content?.path, branch };
  }

  return { error: `unsupported tool: ${tool}` };
}