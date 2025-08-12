#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const DOCS = path.join(ROOT, 'docs-site', 'docs');
const STATIC = path.join(ROOT, 'docs-site', 'static');

let missing = [], scanned = 0;

function checkFile(mdPath) {
  const s = fs.readFileSync(mdPath, 'utf8');
  scanned++;
  // catch both image links ![](...) and generic links [](…)
  const re = /!\[[^\]]*\]\((\/[^)]+)\)|\[[^\]]*\]\((\/[^)]+)\)/g;
  for (const m of s.matchAll(re)) {
    const rel = (m[1] || m[2] || '').trim();
    if (!rel || rel.startsWith('http')) continue;
    // normalize leading slash to STATIC root
    const target = path.join(STATIC, rel.replace(/^\//, ''));
    if (!fs.existsSync(target)) {
      // Allow non-image links to docs (e.g., /docs/...) – only enforce files with an extension
      const hasExt = /\.[a-z0-9]+$/i.test(rel);
      if (hasExt) missing.push(`${path.relative(ROOT, mdPath)} -> ${rel}`);
    }
  }
}

function walk(d) {
  for (const f of fs.readdirSync(d)) {
    const p = path.join(d, f);
    const st = fs.statSync(p);
    if (st.isDirectory()) walk(p);
    else if (/\.(md|mdx)$/i.test(f)) checkFile(p);
  }
}

if (fs.existsSync(DOCS)) walk(DOCS);

if (missing.length) {
  console.error('❌ Missing assets referenced in docs:\n' + missing.map(x => ' - ' + x).join('\n'));
  process.exit(1);
}

console.log(JSON.stringify({ scanned, status: "ok" }));