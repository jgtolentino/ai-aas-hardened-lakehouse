#!/usr/bin/env bash
set -euo pipefail
APP="/Users/tbwa/ai-aas-hardened-lakehouse/apps/scout-dashboard"

# Minimal layout + Overview route using new primitives
mkdir -p "$APP/app/(main)" "$APP/app/overview" "$APP/src/components"
cat > "$APP/app/(main)/layout.tsx" <<'TSX'
import '../src/styles/app.css'
export default function Layout({ children }: { children: React.ReactNode }) {
  return <html data-face="tableau"><body>{children}</body></html>
}
TSX

cat > "$APP/app/overview/page.tsx" <<'TSX'
'use client'
import { Grid } from 'apps/scout-ui/src/components/Layout/Grid'
import { KpiTile } from 'apps/scout-ui/src/components/Kpi/KpiTile'
import { Timeseries } from 'apps/scout-ui/src/components/Chart/Timeseries'

export default function OverviewPage() {
  return (
    <div className="p-6">
      <Grid cols={12} className="mb-4">
        <div className="col-span-3"><KpiTile label="Revenue" value="₱ 12.4M" /></div>
        <div className="col-span-3"><KpiTile label="Transactions" value="482k" /></div>
        <div className="col-span-3"><KpiTile label="Basket" value="₱ 257" /></div>
        <div className="col-span-3"><KpiTile label="Shoppers" value="72k" /></div>
      </Grid>
      <Grid cols={12}>
        <div className="col-span-8"><Timeseries data={[{x:'W1',y:10},{x:'W2',y:14},{x:'W3',y:12},{x:'W4',y:18}]} /></div>
        <div className="col-span-4"><div className="rounded-sk bg-panel p-4 h-72 border border-white/10">Hour × Weekday (stub)</div></div>
      </Grid>
    </div>
  )
}
TSX

# Next config to ensure TS/paths are happy (non-destructive if exists)
if [ ! -f "$APP/next.config.mjs" ]; then
cat > "$APP/next.config.mjs" <<'JS'
/** @type {import('next').NextConfig} */
const nextConfig = { experimental: { typedRoutes: true } }
export default nextConfig
JS
fi

echo "✅ Overview route using new primitives is ready."
