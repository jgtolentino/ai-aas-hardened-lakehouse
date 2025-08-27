import fetch from "node-fetch";

export async function handleMapbox(tool, args) {
  if (!process.env.MAPBOX_TOKEN) throw new Error("Mapbox adapter not configured: MAPBOX_TOKEN");

  if (tool === "geocode.forward") {
    const { q, limit = 5 } = args ?? {};
    if (!q) return { error: "q is required" };
    const url = new URL(`https://api.mapbox.com/search/geocode/v6/forward`);
    url.searchParams.set("q", q);
    url.searchParams.set("limit", String(limit));
    url.searchParams.set("access_token", process.env.MAPBOX_TOKEN);
    const res = await fetch(url.toString());
    if (!res.ok) return { error: `mapbox ${res.status}`, details: await res.text() };
    return await res.json();
  }

  return { error: `unsupported tool: ${tool}` };
}
