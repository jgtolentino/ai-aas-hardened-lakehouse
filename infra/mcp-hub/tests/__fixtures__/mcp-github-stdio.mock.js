#!/usr/bin/env node
// Minimal MCP-stdio mock for github; echo commit request as success.
process.stdin.resume();
let buf = "";
process.stdin.on("data", d => buf += d);
process.stdin.on("end", () => {
  const resp = { ok: true, data: { committed: true, branch: "chore/figma-sync", path: "design/figma/selection.json" } };
  process.stdout.write(JSON.stringify(resp));
});
