# feat: Add DocsWriter - AI-powered documentation generation system

## Summary
This PR implements DocsWriter, a comprehensive documentation generation system that automatically creates and maintains documentation for the ai-aas-hardened-lakehouse project. It includes MDX generation from YAML specs, SVG icon optimization, architecture diagram generation, and GitHub Wiki mirroring.

## What's Changed

### Core Implementation
- 🤖 **DocsWriter Agent** (`mcp/agents/docs-writer.yaml`) - MCP agent specification for documentation generation
- 📝 **Documentation Generator** (`scripts/generate-agent-docs.mjs`) - Scans agent YAML files and generates MDX documentation
- 🎨 **Icon Pipeline** (`scripts/icons-build.mjs`) - Optimizes SVG icons and creates React components
- 📊 **Architecture Diagrams** (`scripts/archspec-to-mermaid.mjs`) - Converts YAML specs to Mermaid diagrams
- 📐 **Diagram Builder** (`scripts/diagrams-build.mjs`) - Processes draw.io diagrams
- 🔄 **Wiki Sync** (`scripts/wiki-sync.sh`) - Mirrors documentation to GitHub Wiki

### CI/CD Integration
- 🚀 **GitHub Actions Workflow** (`.github/workflows/docs.yml`) - Automated documentation build and deployment
- 📦 **Package Scripts** - Added npm scripts for all documentation tasks

### Assets and Examples
- 📁 Created asset directory structure for icons, diagrams, and architecture specs
- 🖼️ Added sample SVG icons (database, pipeline, agent)
- 🏗️ Created sample architecture specification (`assets/archspec/archspec.yaml`)
- 📊 Added draw.io diagram template

### Generated Documentation
- ✅ Successfully generates MDX documentation for agents
- ✅ Creates optimized SVG icons and React components
- ✅ Generates system architecture diagrams from YAML specs
- ✅ Prepares content for GitHub Wiki mirroring

## Testing

### Commands to test locally:
```bash
# Generate all documentation
npm run docs:gen

# Build Docusaurus site
npm run docs:build

# Preview locally
npm run docs:serve
```

### Verified functionality:
- [x] Agent documentation generation from YAML
- [x] Icon optimization and component generation
- [x] Architecture diagram generation
- [x] Docusaurus build (with warnings for existing content)
- [x] Local preview server

## Implementation Details

### DocsWriter Features:
1. **Deterministic Output** - Same input always produces same documentation
2. **MDX Generation** - Creates Docusaurus-compatible MDX with proper frontmatter
3. **Wiki Mirroring** - Generates simplified markdown for GitHub Wiki
4. **Asset Pipeline** - Optimizes SVGs, converts diagrams, generates components
5. **CI/CD Ready** - Fully automated via GitHub Actions

### File Structure:
```
scripts/
├── generate-agent-docs.mjs    # Core documentation generator
├── icons-build.mjs           # SVG optimization pipeline
├── archspec-to-mermaid.mjs   # Architecture diagram generator
├── diagrams-build.mjs        # Draw.io processor
└── wiki-sync.sh             # Wiki synchronization

assets/
├── archspec/                 # Architecture specifications
├── icons/src/               # Source SVG icons
└── diagrams/src/            # Source draw.io diagrams

docs-site/
├── docs/agents/             # Generated agent documentation
├── static/icons/            # Optimized icons
└── wiki/                    # Wiki-formatted documentation
```

## Notes
- The Docusaurus site has some existing content with broken links that need to be addressed separately
- Wiki sync requires the GitHub Wiki to be enabled on the repository
- The CI/CD workflow will automatically generate and deploy documentation on merge

## Related Issues
- Implements documentation automation as requested in the PRD
- Addresses the need for automated agent documentation
- Provides foundation for comprehensive project documentation

## Checklist
- [x] Code follows project conventions
- [x] Scripts are executable and tested
- [x] Documentation generation works correctly
- [x] CI/CD workflow is configured
- [x] Sample assets are provided
- [x] Implementation summary is documented