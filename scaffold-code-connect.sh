#!/usr/bin/env bash
set -euo pipefail
ROOT="/Users/tbwa/ai-aas-hardened-lakehouse"

# 1) Tailwind tokens: CSS variables + Tailwind config extension
mkdir -p "$ROOT/apps/scout-ui/src/styles" "$ROOT/apps/scout-ui/src/theme"
cat > "$ROOT/apps/scout-ui/src/styles/tokens.css" <<'CSS'
:root {
  /* neutrals */
  --bg: #0b0d12;
  --panel: #121622;
  --text: #e6e9f2;
  --muted: #9aa3b2;
  /* brand */
  --accent: #0057ff; /* TBWA primary blue */
  --accent-2: #2ecc71;
  --danger: #ff4d4f;
  --warn: #ffb020;
  --info: #3aa3ff;
  /* sizing */
  --radius: 10px;
  --pad: 16px;
}
/* faces (pbi/tableau/superset) via CSS variables only */
:root[data-face="pbi"] {
  --accent: #f2c811;
  --bg: #0b0b0b; --panel:#161616; --text:#ededed; --muted:#a7a7a7;
}
:root[data-face="tableau"] {
  --accent: #1f77b4;
  --bg: #0a0e14; --panel:#0f1420; --text:#e2e8f0; --muted:#94a3b8;
}
:root[data-face="superset"] {
  --accent: #20a29a;
  --bg: #0b0e13; --panel:#121723; --text:#e8edf7; --muted:#9fb0c5;
}
CSS

# Tailwind config augmentation (non-breaking)
TWC="$ROOT/apps/scout-dashboard/tailwind.config.ts"
if [ -f "$TWC" ]; then
  cp "$TWC" "$TWC.bak"
fi
cat > "$ROOT/apps/scout-dashboard/tailwind.config.ts" <<'TS'
import type { Config } from 'tailwindcss'

export default {
  content: [
    './src/**/*.{ts,tsx}',
    '../../apps/scout-ui/src/**/*.{ts,tsx}',
    './app/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {
      borderRadius: {
        sk: 'var(--radius)',
      },
      colors: {
        bg: 'var(--bg)',
        panel: 'var(--panel)',
        text: 'var(--text)',
        muted: 'var(--muted)',
        accent: 'var(--accent)',
        danger: 'var(--danger)',
        warn: 'var(--warn)',
        info: 'var(--info)',
      },
    },
  },
  plugins: [],
} satisfies Config
TS

# 2) Figma Code Connect config + example mappings in scout-ui
mkdir -p "$ROOT/apps/scout-ui/figma" "$ROOT/apps/scout-ui/src/components/Kpi" \
         "$ROOT/apps/scout-ui/src/components/Layout" "$ROOT/apps/scout-ui/src/components/Chart" \
         "$ROOT/apps/scout-ui/src/components/Button"

cat > "$ROOT/apps/scout-ui/figma/figma.config.json" <<'JSON'
{
  "projectName": "Scout UI",
  "framework": "react",
  "language": "typescript",
  "componentsDir": "src/components",
  "mappingsGlob": "src/components/**/*.figma.tsx",
  "tokens": {
    "source": "css-vars",
    "files": ["src/styles/tokens.css"]
  }
}
JSON

# KpiTile (prod component)
cat > "$ROOT/apps/scout-ui/src/components/Kpi/KpiTile.tsx" <<'TSX'
import React from 'react'
export type KpiTileProps = { label: string; value: string | number; icon?: React.ReactNode; hint?: string }
export function KpiTile({ label, value, icon, hint }: KpiTileProps) {
  return (
    <div className="rounded-sk bg-panel p-4 border border-white/10 flex items-center gap-3">
      {icon ? <div className="text-accent">{icon}</div> : null}
      <div className="min-w-0">
        <div className="text-xs text-muted truncate">{label}</div>
        <div className="text-2xl font-semibold text-text leading-tight">{value}</div>
        {hint ? <div className="text-[11px] text-muted mt-1">{hint}</div> : null}
      </div>
    </div>
  )
}
TSX

# KpiTile Code Connect mapping
cat > "$ROOT/apps/scout-ui/src/components/Kpi/KpiTile.figma.tsx" <<'TSX'
import { KpiTile, type KpiTileProps } from './KpiTile'
export default {
  component: KpiTile,
  props: {
    label: 'Revenue',
    value: '₱ 12.4M',
    hint: 'Last 28 days',
  } satisfies KpiTileProps,
}
TSX

# Layout Grid primitive
cat > "$ROOT/apps/scout-ui/src/components/Layout/Grid.tsx" <<'TSX'
import React from 'react'
export function Grid({ children, cols = 12, className = '' }: { children: React.ReactNode; cols?: 12|8|4; className?: string }) {
  const map = {12: 'grid-cols-12', 8: 'grid-cols-8', 4: 'grid-cols-4'} as const
  return <div className={`grid ${map[cols]} gap-4 ${className}`}>{children}</div>
}
TSX

cat > "$ROOT/apps/scout-ui/src/components/Layout/Grid.figma.tsx" <<'TSX'
import { Grid } from './Grid'
export default {
  component: Grid,
  props: { cols: 12 },
}
TSX

# Chart wrapper (Recharts)
cat > "$ROOT/apps/scout-ui/src/components/Chart/Timeseries.tsx" <<'TSX'
'use client'
import React from 'react'
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts'
export type SeriesPoint = { x: string; y: number }
export function Timeseries({ data }: { data: SeriesPoint[] }) {
  return (
    <div className="h-72 bg-panel rounded-sk p-4 border border-white/10">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="x" />
          <YAxis />
          <Tooltip />
          <Line type="monotone" dataKey="y" stroke="currentColor" dot={false} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  )
}
TSX

cat > "$ROOT/apps/scout-ui/src/components/Chart/Timeseries.figma.tsx" <<'TSX'
import { Timeseries } from './Timeseries'
export default {
  component: Timeseries,
  props: {
    data: [
      {"x":"W1","y":10},{"x":"W2","y":14},{"x":"W3","y":12},{"x":"W4","y":18}
    ]
  }
}
TSX

# Button primitive + mapping
cat > "$ROOT/apps/scout-ui/src/components/Button/Button.tsx" <<'TSX'
import React from 'react'
type Props = React.ButtonHTMLAttributes<HTMLButtonElement> & { tone?: 'primary' | 'neutral' }
export function Button({ tone = 'primary', className = '', ...rest }: Props) {
  const base = 'rounded-sk px-3 py-2 text-sm border'
  const styles = tone === 'primary'
    ? 'bg-accent/10 text-text border-accent/40 hover:bg-accent/20'
    : 'bg-panel text-text border-white/10 hover:bg-white/5'
  return <button className={`${base} ${styles} ${className}`} {...rest} />
}
TSX
cat > "$ROOT/apps/scout-ui/src/components/Button/Button.figma.tsx" <<'TSX'
import { Button } from './Button'
export default { component: Button, props: { children: 'Apply', tone: 'primary' } }
TSX

# 3) Wire tokens into app
mkdir -p "$ROOT/apps/scout-dashboard/src/styles"
cat > "$ROOT/apps/scout-dashboard/src/styles/app.css" <<'CSS'
@tailwind base;
@tailwind components;
@tailwind utilities;

@import "../../../apps/scout-ui/src/styles/tokens.css";
html, body { background: var(--bg); color: var(--text); }
CSS

echo "✅ Code Connect scaffolds + tokens dropped."
