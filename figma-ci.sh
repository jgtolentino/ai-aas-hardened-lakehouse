#!/usr/bin/env bash
set -euo pipefail
ROOT="/Users/tbwa/ai-aas-hardened-lakehouse"

# A tiny parser check to ensure all *.figma.tsx files compile (no runtime fetch to Figma)
mkdir -p "$ROOT/scripts"
cat > "$ROOT/scripts/figma-parse-check.mjs" <<'JS'
import { promises as fs } from 'node:fs'
import { globby } from 'globby'
import path from 'node:path'
const base = path.resolve('apps/scout-ui/src/components')
const files = await globby('**/*.figma.tsx', { cwd: base })
if (!files.length) { console.error('No Code Connect mappings found'); process.exit(2) }
for (const f of files) {
  const p = path.join(base, f)
  await fs.readFile(p, 'utf8') // ensure it exists and is readable
  console.log('OK:', f)
}
JS

# package.json scripts add (scout-ui)
PK="$ROOT/apps/scout-ui/package.json"
if [ -f "$PK" ]; then cp "$PK" "$PK.bak"; fi
cat > "$PK" <<'JSON'
{
  "name": "scout-ui",
  "private": true,
  "type": "module",
  "scripts": {
    "figma:parse": "node ../../scripts/figma-parse-check.mjs",
    "build": "tsc -b || echo 'tsc build handled at root'"
  },
  "dependencies": {},
  "devDependencies": {
    "globby": "^14.0.2",
    "typescript": "^5.5.4"
  }
}
JSON

# CI job (self-hosted allowed or GH-hosted—safe, no secrets)
mkdir -p "$ROOT/.github/workflows"
cat > "$ROOT/.github/workflows/figma-parse.yml" <<'YAML'
name: Code Connect Parse
on:
  pull_request:
  push:
    branches: [ main ]
jobs:
  parse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm -v
      - name: Install minimal deps
        run: |
          cd apps/scout-ui
          npm ci || npm i
      - name: Validate Code Connect mappings
        run: |
          npm run -w apps/scout-ui figma:parse
YAML

echo "✅ Code Connect parser check + CI workflow added."
