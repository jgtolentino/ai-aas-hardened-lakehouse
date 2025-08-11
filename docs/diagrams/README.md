# Architecture Diagrams

This directory contains draw.io diagram files for the Scout Analytics Platform.

## 📁 Files

- `medallion-architecture.drawio` - Data pipeline medallion architecture
- `system-overview.drawio` - Complete system architecture overview

## 🔄 Export Workflow

Diagrams are automatically exported to multiple formats using the export workflow:

```bash
# Manual export (requires draw.io desktop)
node scripts/export-diagrams.js

# Automated via GitHub Actions
# Triggers on push to any .drawio file
```

## 📊 Generated Files

Exported diagrams are saved to `docs/assets/diagrams/` in these formats:
- PNG (for documentation embedding)
- SVG (scalable vector graphics)
- PDF (print-friendly)

## 📚 Documentation

Generated documentation is available at:
- [Architecture Diagrams](../ARCHITECTURE_DIAGRAMS.md)

## ✏️ Editing Diagrams

### Option 1: draw.io Desktop (Recommended)
1. Download from [GitHub](https://github.com/jgraph/drawio-desktop)
2. Open `.drawio` files directly
3. Edit and save
4. Run export script or commit to trigger auto-export

### Option 2: draw.io Web
1. Go to [app.diagrams.net](https://app.diagrams.net/)
2. Open existing `.drawio` file
3. Edit diagram
4. Save back to this directory
5. Manually export or use automated workflow

## 🔧 Adding New Diagrams

1. Create new `.drawio` file in this directory
2. Use consistent naming: `feature-name.drawio`
3. Include meaningful titles and legends
4. Follow color scheme:
   - 🟡 Yellow: Input/Edge devices
   - 🔵 Blue: Storage systems
   - 🟨 Bronze: Raw data layer
   - 🟣 Purple: Silver layer
   - 🔴 Red: Gold layer
   - 🟢 Green: Platinum layer
   - 📊 Orange: Applications
   - ⚙️ Gray: Services/APIs

## 🎨 Style Guide

- Use rounded rectangles for components
- Use consistent colors per layer/type
- Include arrows for data flow
- Add legends for complex diagrams
- Keep text readable at various zoom levels
- Use consistent font sizes (14-18pt for titles, 12pt for labels)

## 📋 Checklist for New Diagrams

- [ ] Clear, descriptive title
- [ ] Consistent color scheme
- [ ] Legend if needed
- [ ] Proper data flow arrows
- [ ] Readable text at 100% zoom
- [ ] Saved in correct directory
- [ ] Exported to all formats
- [ ] Documentation updated

## 🚀 Integration

Diagrams integrate with:
- GitHub Actions for automated export
- Docusaurus documentation site
- README files throughout the project
- Production deployment checklists