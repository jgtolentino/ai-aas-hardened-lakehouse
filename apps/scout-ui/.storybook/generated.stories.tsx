// Auto-import and expose MCP-generated components from the Next app.
import React from "react";

const req = (import.meta as any).glob(
  "../../scout-dashboard/src/components/generated/**/index.tsx",
  { eager: true }
);

export default {
  title: "Generated",
};

export const Index = () => {
  const entries = Object.entries(req);
  return (
    <div style={{ display: "grid", gap: 16 }}>
      {entries.length === 0 && <div>No generated components found.</div>}
      {entries.map(([path, mod]: any) => {
        const Cmp = mod.default || (() => <div>Missing default export</div>);
        return (
          <div key={path} style={{ border: "1px solid #eee", padding: 16 }}>
            <div style={{ fontFamily: "monospace", fontSize: 12, marginBottom: 8 }}>{path}</div>
            <Cmp />
          </div>
        );
      })}
    </div>
  );
};
