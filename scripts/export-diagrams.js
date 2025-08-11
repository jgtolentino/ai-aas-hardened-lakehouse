#!/usr/bin/env node

/**
 * Draw.io Diagram Export Workflow
 * Automates the export of .drawio files to PNG/SVG/PDF formats
 * for documentation integration
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configuration
const DIAGRAMS_DIR = './docs/diagrams';
const OUTPUT_DIR = './docs/assets/diagrams';
const FORMATS = ['png', 'svg', 'pdf'];

// Ensure output directory exists
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

/**
 * Check if draw.io desktop application is available
 */
function checkDrawIoAvailable() {
  try {
    // Common paths for draw.io desktop app
    const drawIoPaths = [
      '/Applications/draw.io.app/Contents/MacOS/draw.io',
      '/usr/bin/drawio',
      'drawio'
    ];
    
    for (const drawioPath of drawIoPaths) {
      try {
        execSync(`"${drawioPath}" --version`, { stdio: 'ignore' });
        return drawioPath;
      } catch (e) {
        continue;
      }
    }
    
    throw new Error('draw.io not found');
  } catch (error) {
    console.log('❌ draw.io desktop app not found. Install from: https://github.com/jgraph/drawio-desktop');
    console.log('💡 Alternative: Use draw.io web version and export manually');
    return null;
  }
}

/**
 * Export a single diagram file to multiple formats
 */
function exportDiagram(drawioPath, inputFile, outputBaseName) {
  const results = {};
  
  for (const format of FORMATS) {
    const outputFile = path.join(OUTPUT_DIR, `${outputBaseName}.${format}`);
    
    try {
      console.log(`📄 Exporting ${inputFile} to ${format}...`);
      
      const command = `"${drawioPath}" --export --format ${format} --output "${outputFile}" "${inputFile}"`;
      execSync(command, { stdio: 'pipe' });
      
      if (fs.existsSync(outputFile)) {
        results[format] = outputFile;
        console.log(`✅ ${format.toUpperCase()}: ${outputFile}`);
      } else {
        console.log(`❌ Failed to create ${format.toUpperCase()}: ${outputFile}`);
      }
    } catch (error) {
      console.log(`❌ Export failed for ${format}: ${error.message}`);
    }
  }
  
  return results;
}

/**
 * Find all .drawio files in the diagrams directory
 */
function findDrawioFiles() {
  if (!fs.existsSync(DIAGRAMS_DIR)) {
    console.log(`📁 Creating diagrams directory: ${DIAGRAMS_DIR}`);
    fs.mkdirSync(DIAGRAMS_DIR, { recursive: true });
    
    // Create a sample diagram file
    const sampleDiagram = `<?xml version="1.0" encoding="UTF-8"?>
<mxfile host="app.diagrams.net" modified="2024-01-01T00:00:00.000Z" agent="5.0" version="22.1.11" etag="sample">
  <diagram name="Page-1" id="sample-diagram">
    <mxGraphModel dx="1422" dy="794" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="827" pageHeight="1169" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="2" value="Scout Analytics Architecture" style="rounded=1;whiteSpace=wrap;html=1;fontSize=16;fontStyle=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="314" y="80" width="200" height="60" as="geometry" />
        </mxCell>
        <mxCell id="3" value="Bronze Layer&lt;br&gt;(Raw Data)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="100" y="200" width="120" height="60" as="geometry" />
        </mxCell>
        <mxCell id="4" value="Silver Layer&lt;br&gt;(Cleaned)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;" vertex="1" parent="1">
          <mxGeometry x="280" y="200" width="120" height="60" as="geometry" />
        </mxCell>
        <mxCell id="5" value="Gold Layer&lt;br&gt;(Aggregated)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;" vertex="1" parent="1">
          <mxGeometry x="460" y="200" width="120" height="60" as="geometry" />
        </mxCell>
        <mxCell id="6" value="Platinum Layer&lt;br&gt;(ML Features)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="640" y="200" width="120" height="60" as="geometry" />
        </mxCell>
        <mxCell id="7" value="" style="endArrow=classic;html=1;rounded=0;exitX=1;exitY=0.5;exitDx=0;exitDy=0;entryX=0;entryY=0.5;entryDx=0;entryDy=0;" edge="1" parent="1" source="3" target="4">
          <mxGeometry width="50" height="50" relative="1" as="geometry">
            <mxPoint x="240" y="250" as="sourcePoint" />
            <mxPoint x="290" y="200" as="targetPoint" />
          </mxGeometry>
        </mxCell>
        <mxCell id="8" value="" style="endArrow=classic;html=1;rounded=0;exitX=1;exitY=0.5;exitDx=0;exitDy=0;entryX=0;entryY=0.5;entryDx=0;entryDy=0;" edge="1" parent="1" source="4" target="5">
          <mxGeometry width="50" height="50" relative="1" as="geometry">
            <mxPoint x="420" y="250" as="sourcePoint" />
            <mxPoint x="470" y="200" as="targetPoint" />
          </mxGeometry>
        </mxCell>
        <mxCell id="9" value="" style="endArrow=classic;html=1;rounded=0;exitX=1;exitY=0.5;exitDx=0;exitDy=0;entryX=0;entryY=0.5;entryDx=0;entryDy=0;" edge="1" parent="1" source="5" target="6">
          <mxGeometry width="50" height="50" relative="1" as="geometry">
            <mxPoint x="600" y="250" as="sourcePoint" />
            <mxPoint x="650" y="200" as="targetPoint" />
          </mxGeometry>
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>`;
    
    fs.writeFileSync(path.join(DIAGRAMS_DIR, 'medallion-architecture.drawio'), sampleDiagram);
    console.log('📄 Created sample diagram: medallion-architecture.drawio');
  }
  
  const files = fs.readdirSync(DIAGRAMS_DIR)
    .filter(file => file.endsWith('.drawio'))
    .map(file => path.join(DIAGRAMS_DIR, file));
  
  return files;
}

/**
 * Generate markdown documentation with embedded diagrams
 */
function generateMarkdownDocs(exportResults) {
  const docContent = `# Architecture Diagrams

This document contains automatically generated diagrams from the draw.io files.

*Last updated: ${new Date().toISOString()}*

---

`;

  let content = docContent;

  Object.entries(exportResults).forEach(([baseName, formats]) => {
    content += `## ${baseName.replace(/-/g, ' ').toUpperCase()}\n\n`;
    
    if (formats.png) {
      content += `![${baseName}](./assets/diagrams/${path.basename(formats.png)})\n\n`;
    }
    
    content += `**Available formats:**\n`;
    Object.entries(formats).forEach(([format, filePath]) => {
      content += `- [${format.toUpperCase()}](./assets/diagrams/${path.basename(filePath)})\n`;
    });
    content += '\n---\n\n';
  });

  const docPath = path.join('./docs', 'ARCHITECTURE_DIAGRAMS.md');
  fs.writeFileSync(docPath, content);
  console.log(`📚 Generated documentation: ${docPath}`);
}

/**
 * Main execution function
 */
function main() {
  console.log('🎨 Draw.io Diagram Export Workflow');
  console.log('='.repeat(40));
  
  // Check if draw.io is available
  const drawioPath = checkDrawIoAvailable();
  
  if (!drawioPath) {
    console.log('\n📝 Manual Export Instructions:');
    console.log('1. Open https://app.diagrams.net/');
    console.log('2. Open each .drawio file from ./docs/diagrams/');
    console.log('3. Export as PNG, SVG, and PDF to ./docs/assets/diagrams/');
    console.log('4. Run this script again to generate documentation');
    return;
  }
  
  // Find all diagram files
  const diagramFiles = findDrawioFiles();
  
  if (diagramFiles.length === 0) {
    console.log('📁 No .drawio files found in ./docs/diagrams/');
    return;
  }
  
  console.log(`📄 Found ${diagramFiles.length} diagram file(s)`);
  
  // Export all diagrams
  const exportResults = {};
  
  diagramFiles.forEach(inputFile => {
    const baseName = path.basename(inputFile, '.drawio');
    console.log(`\n🔄 Processing: ${baseName}`);
    
    const results = exportDiagram(drawioPath, inputFile, baseName);
    exportResults[baseName] = results;
  });
  
  // Generate markdown documentation
  generateMarkdownDocs(exportResults);
  
  console.log('\n✅ Diagram export workflow completed!');
  console.log(`📊 Exported ${Object.keys(exportResults).length} diagrams`);
  console.log(`📁 Output directory: ${OUTPUT_DIR}`);
}

// Run the workflow
if (require.main === module) {
  main();
}

module.exports = { exportDiagram, findDrawioFiles, generateMarkdownDocs };