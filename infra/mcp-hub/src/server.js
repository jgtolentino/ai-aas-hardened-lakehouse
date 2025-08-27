import express from "express";
import helmet from "helmet";
import cors from "cors";
import morgan from "morgan";
import rateLimit from "express-rate-limit";
import { z } from "zod";
import openapi from "./openapi.js";
import { handleSupabase } from "./adapters/supabase.js";
import { handleMapbox } from "./adapters/mapbox.js";
import { handleFigma } from "./adapters/figma.js";
import { handleGitHub } from "./adapters/github.js";
import { handleFigmaGitHubSync } from "./adapters/figma-github-sync.js";

const app = express();
app.disable("x-powered-by");
app.use(helmet({ contentSecurityPolicy: false }));
app.use(cors());
app.use(express.json({ limit: "1mb" }));
app.use(morgan("tiny"));

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
    else if (server === "figma") out = await handleFigma(tool, args);
    else if (server === "github") out = await handleGitHub(tool, args);
    else if (server === "sync") out = await handleFigmaGitHubSync(tool, args);
    else out = { error: "unsupported server" };

    if (out?.error) return res.status(400).json(out);
    return res.json({ data: out });
  } catch (e) {
    return res.status(400).json({ error: e.message ?? "bad request" });
  }
});

const PORT = Number(process.env.PORT || 8787);
app.listen(PORT, () => console.log(`[mcp-hub] listening on :${PORT}`));
