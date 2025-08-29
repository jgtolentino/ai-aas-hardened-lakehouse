import net from "net";

/**
 * Proxy adapter for routing requests to local Figma Dev Mode MCP
 */
export async function handleFigmaProxy(tool, args) {
  return new Promise((resolve, reject) => {
    const client = net.connect({ port: process.env.FIGMA_MCP_PORT || 8974 }, () => {
      client.write(
        JSON.stringify({
          jsonrpc: "2.0",
          id: Date.now(),
          method: "runTool",
          params: { tool, args }
        }) + "\n"
      );
    });

    let buffer = "";
    client.on("data", (chunk) => {
      buffer += chunk.toString();
      try {
        const parsed = JSON.parse(buffer);
        resolve(parsed.result || parsed);
        client.end();
      } catch {
        // wait until full JSON arrives
      }
    });

    client.on("error", (err) => reject({ error: `Figma MCP connection failed: ${err.message}` }));
  });
}
