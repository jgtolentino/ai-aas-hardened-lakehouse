import { promises as fs } from 'fs';
import path from 'path';

const agentsDir = 'mcp/agents';
const docsDir = 'docs-site/docs/agents';
const outDir = 'coverage';
await fs.mkdir(outDir, { recursive: true });

const list = async (dir, exts) => (await fs.readdir(dir, { withFileTypes: true }))
  .filter(d => d.isFile() && exts.some(e => d.name.endsWith(e)))
  .map(d => path.join(dir, d.name));

const agentFiles = await list(agentsDir, ['.yaml', '.yml']).catch(() => []);
const docFiles = await list(docsDir, ['.mdx', '.md']).catch(() => []);

const agentSlugs = agentFiles.map(f => path.basename(f).replace(/\.(ya?ml)$/,''));
const docSlugs   = docFiles.map(f => path.basename(f).replace(/\.(mdx|md)$/,''));

const missingDocs = agentSlugs.filter(s => !docSlugs.includes(s));
const orphans     = docSlugs.filter(s => !agentSlugs.includes(s));

const report = {
  agents_total: agentSlugs.length,
  docs_total: docSlugs.length,
  missing_docs: missingDocs,
  orphans: orphans,
  coverage_pct: agentSlugs.length === 0 ? 100 : Math.round(100 * (agentSlugs.length - missingDocs.length) / agentSlugs.length)
};

await fs.writeFile(path.join(outDir, 'docs-coverage.json'), JSON.stringify(report, null, 2));
await fs.writeFile(path.join(outDir, 'docs-orphans.json'), JSON.stringify({ orphans }, null, 2));

if (missingDocs.length > 0) {
  console.error(`✗ Missing docs for agents: ${missingDocs.join(', ')}`);
  process.exitCode = 0; // warn only; flip to 1 if you want to fail CI
} else {
  console.log('✓ All agents have docs');
}