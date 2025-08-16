import fs from 'fs'; import path from 'path'; import os from 'os';

const ROOT = process.cwd();
const README = path.join(ROOT, 'README.md');
const TEMPLATE = path.join(ROOT, 'templates', 'README.tpl.md');
const COMPOSE = path.join(ROOT, 'infra', 'docker', 'compose.yml');

function listDirs(base, depth=2, prefix='') {
  if (depth < 0) return '';
  let s = '';
  const ents = fs.existsSync(base) ? fs.readdirSync(base, { withFileTypes: true }) : [];
  const dirs = ents.filter(e => e.isDirectory()).map(e => e.name).sort();
  for (const d of dirs) {
    if (d.startsWith('.git')) continue;
    s += `${prefix}├─ ${d}/\n`;
    s += listDirs(path.join(base, d), depth-1, prefix + '│  ');
  }
  return s;
}

function structure() {
  const top = ['apps','services','packages','db','dq','supabase','infra','monitoring','security','.github/workflows'];
  let out = '```\nproject-root/\n';
  for (const t of top) {
    if (!fs.existsSync(path.join(ROOT, t))) continue;
    out += `├─ ${t}/\n` + listDirs(path.join(ROOT, t), 1, '│  ');
  }
  out += '```\n';
  return out;
}

function parseCompose() {
  if (!fs.existsSync(COMPOSE)) return [];
  const txt = fs.readFileSync(COMPOSE, 'utf8');
  // crude parse: lines under "services:" starting at col 2; capture ports if present
  const lines = txt.split(/\r?\n/);
  const out = [];
  let cur = null;
  for (let i=0;i<lines.length;i++) {
    const L = lines[i];
    const mSvc = L.match(/^\s{2}([a-zA-Z0-9_-]+):\s*$/);
    if (mSvc) { cur = { name:mSvc[1], ports:[] }; out.push(cur); continue; }
    if (!cur) continue;
    const mPort = L.match(/^\s*-\s*"?(?<host>\d+):(?<cont>\d+)"?\s*$/);
    if (mPort) cur.ports.push(`${mPort.groups.host}->${mPort.groups.cont}`);
    if (/^\S/.test(L)) cur = null; // next top-level key
  }
  return out;
}

function services() {
  const svcs = parseCompose();
  if (!svcs.length) return '_No compose file found at infra/docker/compose.yml._\n';
  let md = `| Service | Exposed Ports |\n|---|---|\n`;
  for (const s of svcs) md += `| \`${s.name}\` | ${s.ports.join(', ') || '—'} |\n`;
  md += '\n';
  return md;
}

function listWorkflows() {
  const wfDir = path.join(ROOT, '.github', 'workflows');
  if (!fs.existsSync(wfDir)) return [];
  return fs.readdirSync(wfDir).filter(f => f.endsWith('.yml') || f.endsWith('.yaml')).sort();
}

function workflows() {
  const w = listWorkflows();
  if (!w.length) return '_No workflows defined._\n';
  return w.map(f => `- \`${f}\``).join('\n') + '\n';
}

function renderTemplate() {
  const tpl = fs.readFileSync(TEMPLATE, 'utf8');
  return tpl
    .replace('{{STRUCTURE}}', structure())
    .replace('{{SERVICES}}', services())
    .replace('{{WORKFLOWS}}', workflows());
}

function upsertBlocks(readme, gen) {
  const blocks = [
    { key:'STRUCTURE', title:'Project Structure (auto)' },
    { key:'SERVICES',  title:'Services & Ports (auto)' },
    { key:'WORKFLOWS', title:'Active Workflows (auto)' },
  ];
  let out = readme;
  for (const b of blocks) {
    const start = new RegExp(`<!-- AUTO-GEN:${b.key} START -->`);
    const end   = new RegExp(`<!-- AUTO-GEN:${b.key} END -->`);
    const segRe = new RegExp(`<!-- AUTO-GEN:${b.key} START -->[\\s\\S]*?<!-- AUTO-GEN:${b.key} END -->`, 'm');
    const genSeg = gen.match(segRe)?.[0];
    if (!genSeg) continue;
    if (readme.match(segRe)) {
      out = out.replace(segRe, genSeg);
    } else {
      // append if missing
      out = out.trimEnd() + `\n\n${genSeg}\n`;
    }
  }
  return out;
}

const genMd = renderTemplate();
const current = fs.existsSync(README) ? fs.readFileSync(README, 'utf8') : '# Project\n';
const next = upsertBlocks(current, genMd);

if (process.argv.includes('--check')) {
  if (next !== current) {
    console.error('README.md is out of date. Run: pnpm readme:build');
    process.exit(2);
  }
  console.log('README up-to-date.');
  process.exit(0);
} else {
  fs.writeFileSync(README, next);
  console.log('README updated.');
}