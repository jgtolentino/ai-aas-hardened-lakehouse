#!/usr/bin/env node
// Minimal MCP-stdio mock for figma; respond with canned selection/file JSON.
process.stdin.resume();
let buf = "";
process.stdin.on("data", d => buf += d);
process.stdin.on("end", () => {
  // Return a plausible selection payload
  const resp = { ok: true, data: { selection: [{ id: "12:34", name: "Tile/KPI", type: "FRAME"}] } };
  process.stdout.write(JSON.stringify(resp));
});
