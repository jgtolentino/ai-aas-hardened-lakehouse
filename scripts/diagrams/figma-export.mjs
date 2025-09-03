import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import https from "node:https";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..", "..");

const token = process.env.FIGMA_TOKEN;
if (!token) {
  console.error("FIGMA_TOKEN missing"); process.exit(1);
}
const manifestPath = path.join(root, "docs/architecture/diagram-manifest.json");
const manifest = JSON.parse(await fs.readFile(manifestPath, "utf8"));
const fileKey = process.env.FIGMA_FILE_KEY || manifest.fileKey;
if (!fileKey || fileKey.startsWith("__figma_")) {
  console.error("Figma fileKey missing. Set FIGMA_FILE_KEY or update manifest.");
  process.exit(1);
}
const outDir = path.join(root, manifest.outDir);
await fs.mkdir(outDir, { recursive: true });

function get(url, headers) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers }, res => {
      let data = "";
      res.on("data", c => data += c);
      res.on("end", () => resolve({ status: res.statusCode, data }));
    }).on("error", reject);
  });
}

const formats = manifest.formats || ["png"];
const frames = manifest.frames;

for (const fmt of formats) {
  const url = `https://api.figma.com/v1/images/${fileKey}?format=${fmt}&ids=${encodeURIComponent(frames.join(','))}&scale=1`;
  const { status, data } = await get(url, { "X-Figma-Token": token });
  if (status !== 200) { console.error("Figma API error", status, data); process.exit(2); }
  const { images } = JSON.parse(data);
  for (const [frame, imgUrl] of Object.entries(images)) {
    if (!imgUrl) { console.warn("No URL for", frame); continue; }
    const fname = `${frame}.${fmt}`;
    const filePath = path.join(outDir, fname);
    const file = await new Promise((resolve, reject) => {
      https.get(imgUrl, res => {
        const chunks = [];
        res.on("data", c => chunks.push(c));
        res.on("end", () => resolve(Buffer.concat(chunks)));
      }).on("error", reject);
    });
    await fs.writeFile(filePath, file);
    console.log("Wrote", filePath);
  }
}