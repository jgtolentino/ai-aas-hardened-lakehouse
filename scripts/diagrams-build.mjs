#!/usr/bin/env node
import fs from 'fs'; 
import path from 'path'; 
import { execSync } from 'child_process';

const ROOT = process.cwd();
const SRC = path.join(ROOT,'assets/diagrams/src');
const OUT = path.join(ROOT,'docs-site/static/diagrams');
const DRAWIO_OUT = path.join(ROOT,'assets/diagrams/out'); // filled by CI
fs.mkdirSync(OUT, {recursive:true});

// 1) Mermaid .mmd → .svg
if (fs.existsSync(SRC)) {
  for (const f of fs.readdirSync(SRC).filter(x=>x.endsWith('.mmd'))) {
    const inF = path.join(SRC,f);
    const outF = path.join(OUT, f.replace(/\.mmd$/, '.svg'));
    execSync(`npx --yes @mermaid-js/mermaid-cli -i "${inF}" -o "${outF}"`, {stdio:'inherit'});
  }
}

// 2) Copy exported draw.io SVGs
if (fs.existsSync(DRAWIO_OUT)) {
  for (const f of fs.readdirSync(DRAWIO_OUT).filter(x=>x.endsWith('.svg'))) {
    fs.copyFileSync(path.join(DRAWIO_OUT,f), path.join(OUT,f));
  }
}
console.log('[diagrams] built.');