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