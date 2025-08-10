import fetch from "node-fetch";

export class BrowserUseClient {
  constructor(private base = process.env.MCP_BROWSER_USE_URL || "http://127.0.0.1:5173") {}
  call(method: string, params: any) {
    return fetch(`${this.base}/tool/${method}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(params)
    }).then(r => r.json());
  }
  navigate(url: string) { return this.call("navigate", { url }); }
  click(q: any) { return this.call("click", q); }
  type(q: any) { return this.call("type", q); }
  waitFor(q: any) { return this.call("waitFor", q); }
  extract(q: any) { return this.call("extract", q); }
  assert(q: any) { return this.call("assert", q); }
  screenshot(path: string) { return this.call("screenshot", { path }); }
}
EOF < /dev/null