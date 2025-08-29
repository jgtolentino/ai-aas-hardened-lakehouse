import express from "express";
import helmet from "helmet";
import cors from "cors";
import morgan from "morgan";
import rateLimit from "express-rate-limit";
import { z } from "zod";
import openapi from "./openapi.js";
import { handleSupabase } from "./adapters/supabase.js";
import { handleMapbox } from "./adapters/mapbox.js";
import { handleFigmaMCP } from "./adapters/mcp-figma-router.js";
import { handleGitHubMCP } from "./adapters/mcp-github-router.js";
import { handleSyncMCP } from "./adapters/mcp-sync-router.js";
import { upsertDesigns, searchDesigns } from "./adapters/design-index.js";

const app = express();
app.disable("x-powered-by");
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors());
app.use(express.json({ limit: "1mb" }));
// Secure logging - never log sensitive headers
morgan.token('secure-headers', (req) => {
  const sanitized = { ...req.headers };
  delete sanitized['x-api-key'];
  delete sanitized['authorization'];
  return JSON.stringify(sanitized);
});

app.use(morgan(':method :url :status :res[content-length] - :response-time ms'));

const limiter = rateLimit({ windowMs: 60_000, max: 60 });
app.use(limiter);

function requireApiKey(req, res, next) {
  const key = req.header("X-API-Key");
  if (!process.env.HUB_API_KEY) return res.status(500).json({ error: "hub not configured" });
  if (!key || key !== process.env.HUB_API_KEY) return res.status(401).json({ error: "unauthorized" });
  next();
}

app.get("/health", (_req, res) => res.json({ ok: true }));
app.get("/openapi.json", (_req, res) => res.json(openapi));

// Design Index endpoints for zero-click automation
app.post("/mcp/design/index", requireApiKey, async (req, res) => {
  try {
    const items = req.body.items || [];
    if (!Array.isArray(items)) {
      return res.status(400).json({ error: "items must be an array" });
    }
    upsertDesigns(items);
    res.json({ ok: true, indexed: items.length });
  } catch (error) {
    console.error("Design indexing error:", error);
    res.status(500).json({ error: "indexing failed" });
  }
});

app.post("/mcp/design/search", requireApiKey, async (req, res) => {
  try {
    const query = req.body || {};
    const results = searchDesigns(query);
    res.json({ results, count: results.length });
  } catch (error) {
    console.error("Design search error:", error);
    res.status(500).json({ error: "search failed" });
  }
});

const RunSchema = z.object({
  server: z.enum(["supabase","mapbox","figma","github","sync"]),
  tool: z.string().min(1),
  args: z.record(z.any()).default({})
});

app.post("/mcp/run", requireApiKey, async (req, res) => {
  try {
    const { server, tool, args } = RunSchema.parse(req.body);
    let out;
    if (server === "supabase") out = await handleSupabase(tool, args);
    else if (server === "mapbox") out = await handleMapbox(tool, args);
    else if (server === "figma") out = await handleFigmaMCP(tool, args);
    else if (server === "github") out = await handleGitHubMCP(tool, args);
    else if (server === "sync") out = await handleSyncMCP(tool, args);
    else out = { error: "unsupported server" };

    if (out?.error) return res.status(400).json(out);
    return res.json({ data: out });
  } catch (e) {
    return res.status(400).json({ error: e.message ?? "bad request" });
  }
});

const PORT = Number(process.env.PORT || 8787);
app.listen(PORT, () => console.log(`[mcp-hub] listening on :${PORT}`));
