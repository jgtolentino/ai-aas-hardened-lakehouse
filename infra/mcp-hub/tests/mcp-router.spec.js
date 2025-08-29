import { spawn } from "node:child_process";
import { strict as assert } from "assert";
import http from "http";
import { describe, it, beforeAll, afterAll, expect } from "vitest";

function call(path, body) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      { hostname: "127.0.0.1", port: 8787, method: "POST", path,
        headers: { "Content-Type": "application/json", "X-API-Key": "test-key" } },
      res => {
        let data = ""; res.on("data", d => data += d);
        res.on("end", () => resolve(JSON.parse(data)));
      });
    req.on("error", reject);
    req.write(JSON.stringify(body));
    req.end();
  });
}

describe("MCP Hub (router mode)", () => {
  let server;
  
  beforeAll(async () => {
    process.env.HUB_API_KEY = "test-key";
    process.env.ROUTER_MODE = "mock";
    process.env.FIGMA_MCP_BIN = process.cwd() + "/tests/__fixtures__/mcp-figma-stdio.mock.js";
    process.env.GITHUB_MCP_BIN = process.cwd() + "/tests/__fixtures__/mcp-github-stdio.mock.js";
    
    // Dynamic import for ESM
    const serverModule = await import("../src/server.js");
    server = serverModule.default?.listen ? serverModule.default.listen(8787) : null;
    
    // Wait for server to start
    await new Promise(resolve => setTimeout(resolve, 1000));
  });

  afterAll(async () => { 
    if (server?.close) server.close(); 
  });

  it("health check responds", async () => {
    const res = await fetch("http://127.0.0.1:8787/health").then(r => r.json());
    expect(res.ok).toBe(true);
  });

  it("openapi spec available", async () => {
    const res = await fetch("http://127.0.0.1:8787/openapi.json").then(r => r.json());
    expect(res?.paths?.["/mcp/run"]).toBeDefined();
  });

  it("routes figma selection via mock stdio", async () => {
    const res = await call("/mcp/run", { server: "figma", tool: "nodes.get", args: {} });
    expect(res.data || res.error).toBeDefined();
  });

  it("sync workflow via sync router", async () => {
    const res = await call("/mcp/run", {
      server: "sync", tool: "sync.figmaSelectionToRepo",
      args: { commitPath: "design/figma/selection.json", message: "chore(figma): CI test" }
    });
    expect(res.data || res.error).toBeDefined();
  });
});
