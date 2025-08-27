export default {
  openapi: "3.1.0",
  info: { title: "MCP Hub", version: "1.0.0" },
  servers: [{ url: "https://mcp.yourdomain.com" }],
  paths: {
    "/mcp/run": {
      post: {
        operationId: "runMcpTool",
        description: "Invoke an adapter tool via the hub.",
        security: [{ hubApiKey: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["server", "tool", "args"],
                properties: {
                  server: { type: "string", enum: ["supabase","mapbox"] },
                  tool:   { type: "string",  description: "Adapter tool name" },
                  args:   { type: "object", additionalProperties: true }
                }
              }
            }
          }
        },
        responses: {
          "200": {
            description: "OK",
            content: { "application/json": { schema: { type: "object" } } }
          },
          "400": { description: "Bad Request" },
          "401": { description: "Unauthorized" },
          "429": { description: "Rate limited" },
          "500": { description: "Server error" }
        }
      }
    },
    "/health": { get: { operationId: "health", responses: { "200": { description: "OK"} } } }
  },
  components: {
    securitySchemes: {
      hubApiKey: { type: "apiKey", in: "header", name: "X-API-Key" }
    }
  }
}

// allow printing to stdout
if (import.meta.url === `file://${process.argv[1]}`) {
  console.log(JSON.stringify((await import('./openapi.js')).default ?? {}, null, 2));
}
