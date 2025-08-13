#!/bin/bash

# Integrate Scout documentation with DocsWriter system

echo "🔗 Integrating Scout Analytics documentation..."

# Add to git
cd /Users/tbwa/ai-aas-hardened-lakehouse
git add docs/neural-docs
git add scripts/scout-docs-writer.js

# Update package.json scripts
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('scripts/package.json', 'utf8'));
pkg.scripts = pkg.scripts || {};
pkg.scripts['docs:scout'] = 'node scout-docs-writer.js';
pkg.scripts['docs:scout:dev'] = 'cd ../docs/neural-docs/scout-data-warehouse-docs && npm run dev';
pkg.scripts['docs:scout:build'] = 'cd ../docs/neural-docs/scout-data-warehouse-docs && npm run build';
fs.writeFileSync('scripts/package.json', JSON.stringify(pkg, null, 2));
"

# Create DocsWriter agent config for Scout
cat > mcp/agents/scout-docs-writer.yaml << 'EOF'
name: scout-docs-writer
role: Scout Analytics Documentation Specialist
capabilities:
  - Generate comprehensive Scout Analytics documentation
  - Transform rough scaffolds into production docs
  - Integrate with draw.io for architecture diagrams
  - Connect live data from Gold views
  - Maintain API reference documentation
config:
  model: claude-3-5-sonnet
  temperature: 0.3
  max_tokens: 8000
  tools:
    - read_files
    - write_files
    - execute_commands
  prompts:
    system: |
      You are the Scout Analytics documentation specialist. You maintain comprehensive
      documentation for the Scout Analytics platform including:
      - Data model and ERD diagrams
      - Implementation guides
      - Query library
      - API reference
      - Edge function documentation
      Always use draw.io instead of Mermaid for diagrams.
      Connect to live Gold views when documenting data structures.
EOF

echo "✅ Integration complete!"
echo ""
echo "Available commands:"
echo "  npm run docs:scout       - Update Scout documentation"
echo "  npm run docs:scout:dev   - Run documentation dev server"
echo "  npm run docs:scout:build - Build documentation site"