import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

type Result = { items: any[]; discovered: string[]; note: string };

async function fetchPage(url: string): Promise<string> {
  const r = await fetch(url, { redirect: "follow" });
  if (!r.ok) throw new Error(`fetch ${r.status}`);
  return await r.text();
}

function extractLinks(html: string, base: string): string[] {
  const re = /href="([^"#]+)"/gi;
  const out: string[] = [];
  let m: RegExpExecArray | null;
  while ((m = re.exec(html))) {
    const href = m[1];
    try {
      const abs = new URL(href, base).toString();
      if (abs.startsWith("http")) out.push(abs);
    } catch {}
  }
  return Array.from(new Set(out));
}

function extractItems(html: string): any[] {
  // TODO: plug your selector pack here; placeholder returns empty
  return [];
}

serve(async (req: Request) => {
  try {
    const { url } = await req.json();
    if (!url) return new Response(JSON.stringify({ error: "url required" }), { status: 400 });
    const html = await fetchPage(url);
    const items = extractItems(html);
    const discovered = extractLinks(html, url);
    const result: Result = { items, discovered, note: items.length ? "product" : "listing" };
    return new Response(JSON.stringify(result), { headers: { "content-type": "application/json" }});
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e?.message || e) }), { status: 500 });
  }
});
