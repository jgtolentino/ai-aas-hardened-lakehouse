import fetch from "node-fetch";

function req(path, qs={}) {
  const token = process.env.FIGMA_TOKEN;
  if (!token) throw new Error("Figma adapter not configured: FIGMA_TOKEN");
  const url = new URL(`https://api.figma.com${path}`);
  for (const [k,v] of Object.entries(qs)) url.searchParams.set(k, v);
  return fetch(url.toString(), { headers: { "X-Figma-Token": token } });
}

export async function handleFigma(tool, args) {
  if (tool === "file.exportJSON") {
    const fileKey = args?.fileKey || process.env.FIGMA_FILE_KEY;
    if (!fileKey) return { error: "fileKey required" };
    const r = await req(`/v1/files/${fileKey}`);
    if (!r.ok) return { error: `figma ${r.status}`, details: await r.text() };
    return await r.json();
  }

  if (tool === "nodes.get") {
    const fileKey = args?.fileKey || process.env.FIGMA_FILE_KEY;
    const ids = Array.isArray(args?.ids) ? args.ids.join(",") : args?.ids;
    if (!fileKey || !ids) return { error: "fileKey and ids required" };
    const r = await req(`/v1/files/${fileKey}/nodes`, { ids });
    if (!r.ok) return { error: `figma ${r.status}`, details: await r.text() };
    return await r.json();
  }

  if (tool === "images.export") {
    const fileKey = args?.fileKey || process.env.FIGMA_FILE_KEY;
    const ids = Array.isArray(args?.ids) ? args.ids.join(",") : args?.ids;
    const format = args?.format || "png";
    const scale = args?.scale || "2";
    if (!fileKey || !ids) return { error: "fileKey and ids required" };
    const r = await req(`/v1/images/${fileKey}`, { ids, format, scale });
    if (!r.ok) return { error: `figma ${r.status}`, details: await r.text() };
    return await r.json(); // contains urls map per node id
  }

  return { error: `unsupported tool: ${tool}` };
}