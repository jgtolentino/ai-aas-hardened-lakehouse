#!/usr/bin/env node

/**
 * diagram-bridge-mcp: MCP Server for diagram generation
 * 
 * Supports:
 * - Kroki integration (Mermaid, PlantUML, Graphviz, D2, DBML, etc.)
 * - Direct draw.io CLI exports
 * - Viewer URLs for draw.io
 * - Design token extraction from diagrams
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { z } from "zod";
import * as fs from "node:fs/promises";
import * as path from "node:path";
import * as os from "node:os";
import { createHash } from "node:crypto";
// @ts-ignore - pako types not available
import { deflate, deflateRaw } from "pako";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileP = promisify(execFile);

// Configuration
const KROKI_URL = (process.env.KROKI_URL || "https://kroki.io").replace(/\/+$/, "");

// Supported diagram engines via Kroki
const KNOWN_ENGINES = [
  "mermaid", "plantuml", "graphviz", "dot", "d2", "dbml", "vega", "vegalite",
  "wavedrom", "bytefield", "erd", "svgbob", "nomnoml", "pikchr", "tikz",
  "structurizr", "umlet", "bpmn", "excalidraw", "wireviz", "diagramsnet"
];

const OUTPUTS = ["svg", "png", "pdf"] as const;

// Utility functions
function qsFromOptions(opts?: Record<string, string | number | boolean | undefined>) {
  if (!opts) return "";
  const params = Object.entries(opts)
    .filter(([, v]) => v !== undefined)
    .map(([k, v]) => [k, String(v)]);
  return params.length ? "?" + new URLSearchParams(params).toString() : "";
}

function b64(buf: Uint8Array) {
  if (typeof Buffer !== "undefined") return Buffer.from(buf).toString("base64");
  let binary = "";
  buf.forEach((b) => binary += String.fromCharCode(b));
  return btoa(binary);
}

function dataUri(mime: string, data: Uint8Array | string) {
  const payload = typeof data === "string" 
    ? Buffer.from(data, "utf8").toString("base64") 
    : b64(data);
  return `data:${mime};base64,${payload}`;
}

// Kroki API client
async function renderViaKroki(
  engine: string, 
  source: string, 
  output: typeof OUTPUTS[number], 
  options?: Record<string, any>
) {
  const endpoint = `${KROKI_URL}/${engine}/${output}${qsFromOptions(options)}`;
  
  const res = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "text/plain" },
    body: source
  });

  if (!res.ok) {
    const text = await res.text().catch(() => String(res.status));
    throw new Error(`Kroki ${engine}/${output} failed: HTTP ${res.status}: ${text}`);
  }

  const mime = output === "svg" ? "image/svg+xml" : 
               (output === "png" ? "image/png" : "application/pdf");
  const buf = new Uint8Array(await res.arrayBuffer());
  
  return { mime, buf };
}

function encodeKrokiGet(
  engine: string, 
  output: string, 
  source: string, 
  options?: Record<string, any>
) {
  const compressed = deflate(source, { level: 9 });
  const encoded = b64(compressed).replace(/\//g, "_").replace(/\+/g, "-");
  const qs = qsFromOptions(options);
  return `${KROKI_URL}/${engine}/${output}/${encoded}${qs}`;
}

function makeDrawioViewerUrl(xml: string) {
  const raw = deflateRaw(xml, { level: 9 });
  const encoded = b64(raw);
  return `https://viewer.diagrams.net/?highlight=0000ff&edit=_blank&layers=1&nav=1#R${encoded}`;
}

async function writeArtifact(ext: string, data: Uint8Array) {
  const tmp = path.join(os.tmpdir(), "diagram-bridge-mcp");
  await fs.mkdir(tmp, { recursive: true });
  const h = createHash("sha1").update(data).digest("hex").slice(0, 10);
  const file = path.join(tmp, `diagram_${Date.now()}_${h}.${ext}`);
  await fs.writeFile(file, data);
  return file;
}

// MCP Server setup
const server = new Server(
  {
    name: "diagram-bridge-mcp",
    version: "0.1.0",
  },
  {
    capabilities: {
      tools: {},
      prompts: {},
      resources: {}
    },
  }
);

// Error handler
server.onerror = (error) => console.error("[MCP Error]", error);

// List tools handler
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "diagram_list_engines",
        description: "List supported diagram engines",
      },
      {
        name: "diagram_render",
        description: "Render diagram via Kroki API",
        inputSchema: {
          type: "object",
          properties: {
            engine: { type: "string", description: "Diagram engine (mermaid, plantuml, etc.)" },
            code: { type: "string", description: "Diagram source code" },
            output: { type: "string", enum: ["svg", "png", "pdf"], default: "svg" },
            options: { type: "object", description: "Additional rendering options" },
            saveFile: { type: "boolean", default: true, description: "Save to local file" },
            returnDataUri: { type: "boolean", default: true, description: "Return data URI" }
          },
          required: ["engine", "code"]
        }
      },
      {
        name: "diagram_kroki_url",
        description: "Generate shareable Kroki GET URL",
        inputSchema: {
          type: "object",
          properties: {
            engine: { type: "string" },
            code: { type: "string" },
            output: { type: "string", enum: ["svg", "png", "pdf"], default: "svg" },
            options: { type: "object" }
          },
          required: ["engine", "code"]
        }
      },
      {
        name: "diagram_drawio_cli_export",
        description: "Export diagram using draw.io Desktop CLI",
        inputSchema: {
          type: "object",
          properties: {
            xml: { type: "string", description: "Draw.io XML content" },
            inputPath: { type: "string", description: "Path to existing .drawio file" },
            format: { type: "string", enum: ["svg", "png", "pdf"], default: "svg" },
            outputPath: { type: "string", description: "Output file path" },
            binary: { type: "string", description: "Path to draw.io binary" },
            returnDataUri: { type: "boolean", default: false },
            crop: { type: "boolean", default: false },
            pageIndex: { type: "number", description: "Page index for multi-page files" }
          }
        }
      },
      {
        name: "diagram_drawio_viewer_url",
        description: "Generate draw.io viewer URL",
        inputSchema: {
          type: "object",
          properties: {
            xml: { type: "string", description: "Draw.io XML content" }
          },
          required: ["xml"]
        }
      },
      {
        name: "diagram_drawio_embed_url",
        description: "Generate draw.io embed URL",
        inputSchema: {
          type: "object",
          properties: {
            params: { type: "object", description: "URL parameters" }
          }
        }
      },
      {
        name: "diagram_plan_and_generate",
        description: "AI prompt to plan diagram and generate code",
        inputSchema: {
          type: "object",
          properties: {
            intent: { type: "string", description: "Natural language diagram intent" },
            preferredEngine: { type: "string", description: "Preferred diagram engine" }
          },
          required: ["intent"]
        }
      }
    ]
  };
});

// Call tool handler
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "diagram_list_engines":
        return {
          content: [{
            type: "text",
            text: JSON.stringify({ engines: KNOWN_ENGINES }, null, 2)
          }]
        };

      case "diagram_render": {
        const { engine, code, output = "svg", options, saveFile = true, returnDataUri = true } = args as any;
        
        const { mime, buf } = await renderViaKroki(engine, code, output, options);
        const content: any[] = [];

        if (returnDataUri) {
          content.push({ type: "text", text: dataUri(mime, buf) });
        }

        if (saveFile) {
          const ext = output.toLowerCase();
          const file = await writeArtifact(ext, buf);
          content.push({
            type: "resource",
            resource: {
              uri: `file://${file}`,
              name: path.basename(file),
              mimeType: mime,
              description: "Rendered diagram file"
            }
          });
        }

        return { content };
      }

      case "diagram_kroki_url": {
        const { engine, code, output = "svg", options } = args as any;
        const url = encodeKrokiGet(engine, output, code, options);
        return {
          content: [{ type: "text", text: url }]
        };
      }

      case "diagram_drawio_cli_export": {
        const { 
          xml, 
          inputPath, 
          format = "svg", 
          outputPath, 
          binary, 
          returnDataUri = false, 
          crop = false, 
          pageIndex 
        } = args as any;

        if (!xml && !inputPath) {
          throw new Error("Provide either xml or inputPath");
        }

        // Resolve binary path
        const BIN = binary
          ?? process.env.DRAWIO_BIN
          ?? (process.platform === "darwin"
                ? "/Applications/draw.io.app/Contents/MacOS/draw.io"
                : "drawio");

        // Prepare input file
        const inFile = inputPath || await (async () => {
          const f = path.join(os.tmpdir(), `mcp_${Date.now()}.drawio`);
          await fs.writeFile(f, xml!, "utf8");
          return f;
        })();

        // Prepare output
        const outFile = outputPath || path.join(os.tmpdir(), `diagram_${Date.now()}.${format}`);

        // Build CLI args
        const cliArgs = [
          "--export",
          "--format", format,
          "--output", outFile,
          "--no-sandbox",
          inFile
        ];

        if (crop) cliArgs.splice(1, 0, "--crop");
        if (pageIndex !== undefined) cliArgs.splice(1, 0, "--page-index", String(pageIndex));

        // Execute draw.io CLI
        try {
          await execFileP(BIN, cliArgs, { env: process.env });
        } catch (e: any) {
          throw new Error(`draw.io CLI failed: ${e.stderr || e.message}`);
        }

        const buf = await fs.readFile(outFile);
        const mime = format === "svg" ? "image/svg+xml" : 
                    (format === "png" ? "image/png" : "application/pdf");

        const content: any[] = [{
          type: "resource",
          resource: {
            uri: `file://${outFile}`,
            name: path.basename(outFile),
            mimeType: mime,
            description: "Rendered via draw.io Desktop CLI"
          }
        }];

        if (returnDataUri) {
          const base64 = Buffer.from(buf).toString("base64");
          content.push({ type: "text", text: `data:${mime};base64,${base64}` });
        }

        return { content };
      }

      case "diagram_drawio_viewer_url": {
        const { xml } = args as any;
        const url = makeDrawioViewerUrl(xml);
        return {
          content: [{ type: "text", text: url }]
        };
      }

      case "diagram_drawio_embed_url": {
        const { params = {} } = args as any;
        const base = "https://embed.diagrams.net/";
        const p = new URLSearchParams({ 
          embed: "1", 
          ui: "min", 
          nav: "1", 
          ...Object.fromEntries(Object.entries(params).map(([k, v]) => [k, String(v)]))
        });
        return {
          content: [{ type: "text", text: `${base}?${p.toString()}` }]
        };
      }

      case "diagram_plan_and_generate": {
        const { intent, preferredEngine } = args as any;
        const planningPrompt = `You are a diagram planner. Choose the best textual diagram grammar from: ${KNOWN_ENGINES.join(", ")}.

If user mentions "draw.io" or "diagrams.net", use "diagramsnet" and produce valid draw.io XML (mxfile format).
For flowcharts/processes: prefer "mermaid"
For UML: prefer "plantuml" 
For network/architecture: prefer "d2" or "graphviz"
For database schemas: prefer "dbml"

Return compact JSON:
{
  "engine": "<engine_name>",
  "output": "svg", 
  "code": "<diagram_code>"
}

User intent: ${intent}
Preferred engine: ${preferredEngine || "(auto-select)"}`;

        return {
          content: [{
            type: "text",
            text: planningPrompt
          }]
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [{
        type: "text",
        text: `Error: ${error instanceof Error ? error.message : String(error)}`
      }],
      isError: true
    };
  }
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Diagram Bridge MCP server running on stdio");
}

main().catch(console.error);