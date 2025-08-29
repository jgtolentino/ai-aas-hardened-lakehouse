#!/usr/bin/env node

/**
 * Figma Design-to-Code Extractor for Scout Dashboard
 * 
 * This script extracts design tokens, components, and layouts from Figma files
 * and generates corresponding React components with proper styling.
 */

const fs = require('fs');
const path = require('path');
const axios = require('axios');

// Configuration
const CONFIG = {
  figmaToken: process.env.FIGMA_ACCESS_TOKEN,
  fileId: process.env.FIGMA_FILE_ID || 'scout-dashboard-design-file',
  outputDir: path.join(__dirname, '../../apps/scout-dashboard/src/components/generated'),
  stylesDir: path.join(__dirname, '../../apps/scout-dashboard/src/styles/generated'),
  apiBase: 'https://api.figma.com/v1'
};

// Figma API client
class FigmaClient {
  constructor(token) {
    this.token = token;
    this.client = axios.create({
      baseURL: CONFIG.apiBase,
      headers: {
        'X-Figma-Token': token,
        'Content-Type': 'application/json'
      }
    });
  }

  async getFile(fileId) {
    try {
      const response = await this.client.get(`/files/${fileId}`);
      return response.data;
    } catch (error) {
      console.error('Error fetching Figma file:', error.response?.data || error.message);
      throw error;
    }
  }

  async getImages(fileId, nodeIds, format = 'png', scale = 2) {
    try {
      const response = await this.client.get(`/images/${fileId}`, {
        params: {
          ids: nodeIds.join(','),
          format,
          scale
        }
      });
      return response.data;
    } catch (error) {
      console.error('Error fetching images:', error.response?.data || error.message);
      throw error;
    }
  }
}

// Design token extractor
class DesignTokenExtractor {
  constructor() {
    this.tokens = {
      colors: {},
      typography: {},
      spacing: {},
      shadows: {},
      borders: {}
    };
  }

  extractFromStyles(styles) {
    if (!styles) return;

    Object.values(styles).forEach(style => {
      switch (style.styleType) {
        case 'FILL':
          this.extractColors(style);
          break;
        case 'TEXT':
          this.extractTypography(style);
          break;
        case 'EFFECT':
          this.extractShadows(style);
          break;
      }
    });
  }

  extractColors(style) {
    const name = this.camelCase(style.name);
    if (style.fills && style.fills[0]) {
      const fill = style.fills[0];
      if (fill.type === 'SOLID') {
        const { r, g, b } = fill.color;
        const alpha = fill.opacity || 1;
        this.tokens.colors[name] = alpha === 1 
          ? `rgb(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)})`
          : `rgba(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)}, ${alpha})`;
      }
    }
  }

  extractTypography(style) {
    const name = this.camelCase(style.name);
    if (style.textStyles) {
      const textStyle = style.textStyles;
      this.tokens.typography[name] = {
        fontSize: `${textStyle.fontSize}px`,
        fontWeight: textStyle.fontWeight,
        fontFamily: textStyle.fontFamily,
        lineHeight: textStyle.lineHeightPx ? `${textStyle.lineHeightPx}px` : 'normal',
        letterSpacing: textStyle.letterSpacing ? `${textStyle.letterSpacing}px` : 'normal'
      };
    }
  }

  extractShadows(style) {
    const name = this.camelCase(style.name);
    if (style.effects) {
      const shadows = style.effects
        .filter(effect => effect.type === 'DROP_SHADOW')
        .map(shadow => {
          const { r, g, b } = shadow.color;
          const alpha = shadow.color.a || 1;
          return `${shadow.offset.x}px ${shadow.offset.y}px ${shadow.radius}px rgba(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)}, ${alpha})`;
        });
      
      if (shadows.length > 0) {
        this.tokens.shadows[name] = shadows.join(', ');
      }
    }
  }

  camelCase(str) {
    return str.replace(/(?:^\w|[A-Z]|\b\w)/g, (word, index) => {
      return index === 0 ? word.toLowerCase() : word.toUpperCase();
    }).replace(/\s+/g, '');
  }

  generateCSS() {
    const css = [];
    
    // CSS Custom Properties
    css.push(':root {');
    
    // Colors
    Object.entries(this.tokens.colors).forEach(([name, value]) => {
      css.push(`  --color-${this.kebabCase(name)}: ${value};`);
    });
    
    // Typography
    Object.entries(this.tokens.typography).forEach(([name, styles]) => {
      Object.entries(styles).forEach(([prop, value]) => {
        css.push(`  --typography-${this.kebabCase(name)}-${this.kebabCase(prop)}: ${value};`);
      });
    });
    
    // Shadows
    Object.entries(this.tokens.shadows).forEach(([name, value]) => {
      css.push(`  --shadow-${this.kebabCase(name)}: ${value};`);
    });
    
    css.push('}');
    
    // Utility classes
    css.push('');
    css.push('/* Typography Utilities */');
    Object.entries(this.tokens.typography).forEach(([name, styles]) => {
      css.push(`.text-${this.kebabCase(name)} {`);
      Object.entries(styles).forEach(([prop, value]) => {
        css.push(`  ${this.kebabCase(prop)}: var(--typography-${this.kebabCase(name)}-${this.kebabCase(prop)});`);
      });
      css.push('}');
    });
    
    return css.join('\n');
  }

  kebabCase(str) {
    return str.replace(/([a-z0-9]|(?=[A-Z]))([A-Z])/g, '$1-$2').toLowerCase();
  }
}

// Component generator
class ComponentGenerator {
  constructor(designTokens) {
    this.designTokens = designTokens;
  }

  generateFromNode(node, parentPath = '') {
    const componentName = this.getComponentName(node);
    const componentPath = path.join(CONFIG.outputDir, `${componentName}.tsx`);

    if (node.type === 'COMPONENT' || node.type === 'COMPONENT_SET') {
      const component = this.createReactComponent(node, componentName);
      return {
        name: componentName,
        path: componentPath,
        content: component
      };
    }

    return null;
  }

  createReactComponent(node, componentName) {
    const props = this.extractProps(node);
    const styles = this.extractStyles(node);
    const jsx = this.generateJSX(node);

    return `import React from 'react';
import './generated-styles.css';

export interface ${componentName}Props {
${props.map(prop => `  ${prop.name}${prop.optional ? '?' : ''}: ${prop.type};`).join('\n')}
  className?: string;
}

export const ${componentName}: React.FC<${componentName}Props> = ({
${props.map(prop => `  ${prop.name}${prop.defaultValue ? ` = ${prop.defaultValue}` : ''}`).join(',\n')}${props.length > 0 ? ',' : ''}
  className = ''
}) => {
  return (
${jsx}
  );
};

export default ${componentName};
`;
  }

  getComponentName(node) {
    return node.name
      .replace(/[^a-zA-Z0-9]/g, '')
      .replace(/^./, str => str.toUpperCase());
  }

  extractProps(node) {
    const props = [];
    
    // Extract variant properties
    if (node.componentPropertyDefinitions) {
      Object.entries(node.componentPropertyDefinitions).forEach(([key, definition]) => {
        props.push({
          name: this.camelCase(key),
          type: this.getFigmaPropertyType(definition.type),
          optional: !definition.defaultValue,
          defaultValue: this.getFigmaDefaultValue(definition)
        });
      });
    }

    return props;
  }

  extractStyles(node) {
    const styles = {};
    
    if (node.fills) {
      styles.backgroundColor = this.getFillColor(node.fills[0]);
    }
    
    if (node.strokes && node.strokes.length > 0) {
      styles.border = `${node.strokeWeight}px solid ${this.getFillColor(node.strokes[0])}`;
    }
    
    if (node.cornerRadius) {
      styles.borderRadius = `${node.cornerRadius}px`;
    }
    
    return styles;
  }

  generateJSX(node, indent = '    ') {
    const tag = this.getHTMLTag(node);
    const className = this.generateClassName(node);
    const styles = this.extractStyles(node);
    const styleStr = Object.keys(styles).length > 0 
      ? ` style={${JSON.stringify(styles)}}`
      : '';

    if (node.children && node.children.length > 0) {
      const children = node.children
        .map(child => this.generateJSX(child, indent + '  '))
        .join('\n');
      
      return `${indent}<${tag} className={\`${className} \${className}\`}${styleStr}>
${children}
${indent}</${tag}>`;
    } else {
      const content = this.getNodeContent(node);
      return `${indent}<${tag} className={\`${className} \${className}\`}${styleStr}>${content}</${tag}>`;
    }
  }

  getHTMLTag(node) {
    switch (node.type) {
      case 'TEXT':
        return 'span';
      case 'RECTANGLE':
      case 'FRAME':
      case 'COMPONENT':
        return 'div';
      case 'VECTOR':
        return 'svg';
      default:
        return 'div';
    }
  }

  generateClassName(node) {
    const classes = ['figma-component'];
    
    if (node.name) {
      classes.push(this.kebabCase(node.name));
    }
    
    return classes.join(' ');
  }

  getNodeContent(node) {
    if (node.type === 'TEXT' && node.characters) {
      return node.characters;
    }
    return '';
  }

  getFillColor(fill) {
    if (!fill || fill.type !== 'SOLID') return 'transparent';
    
    const { r, g, b } = fill.color;
    const alpha = fill.opacity || 1;
    
    return alpha === 1 
      ? `rgb(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)})`
      : `rgba(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(b * 255)}, ${alpha})`;
  }

  getFigmaPropertyType(figmaType) {
    switch (figmaType) {
      case 'BOOLEAN':
        return 'boolean';
      case 'TEXT':
        return 'string';
      case 'INSTANCE_SWAP':
        return 'React.ComponentType';
      case 'VARIANT':
        return 'string';
      default:
        return 'any';
    }
  }

  getFigmaDefaultValue(definition) {
    switch (definition.type) {
      case 'BOOLEAN':
        return definition.defaultValue ? 'true' : 'false';
      case 'TEXT':
        return `"${definition.defaultValue || ''}"`;
      default:
        return undefined;
    }
  }

  camelCase(str) {
    return str.replace(/(?:^\w|[A-Z]|\b\w)/g, (word, index) => {
      return index === 0 ? word.toLowerCase() : word.toUpperCase();
    }).replace(/\s+/g, '');
  }

  kebabCase(str) {
    return str.replace(/([a-z0-9]|(?=[A-Z]))([A-Z])/g, '$1-$2').toLowerCase();
  }
}

// Main extraction function
async function extractFigmaDesign() {
  try {
    console.log('🎨 Starting Figma design extraction...');
    
    // Validate configuration
    if (!CONFIG.figmaToken) {
      throw new Error('FIGMA_ACCESS_TOKEN environment variable is required');
    }

    if (!CONFIG.fileId) {
      throw new Error('FIGMA_FILE_ID environment variable is required');
    }

    // Create output directories
    fs.mkdirSync(CONFIG.outputDir, { recursive: true });
    fs.mkdirSync(CONFIG.stylesDir, { recursive: true });

    // Initialize Figma client
    const figma = new FigmaClient(CONFIG.figmaToken);
    
    // Fetch design file
    console.log('📥 Fetching Figma file...');
    const fileData = await figma.getFile(CONFIG.fileId);
    
    // Extract design tokens
    console.log('🎯 Extracting design tokens...');
    const tokenExtractor = new DesignTokenExtractor();
    tokenExtractor.extractFromStyles(fileData.styles);
    
    // Generate CSS file
    const css = tokenExtractor.generateCSS();
    fs.writeFileSync(
      path.join(CONFIG.stylesDir, 'design-tokens.css'), 
      css
    );
    console.log('✅ Design tokens extracted to design-tokens.css');
    
    // Extract and generate components
    console.log('🔧 Generating React components...');
    const componentGenerator = new ComponentGenerator(tokenExtractor.tokens);
    const components = [];
    
    function traverseNodes(node) {
      const component = componentGenerator.generateFromNode(node);
      if (component) {
        components.push(component);
        fs.writeFileSync(component.path, component.content);
        console.log(`✅ Generated component: ${component.name}`);
      }
      
      if (node.children) {
        node.children.forEach(traverseNodes);
      }
    }
    
    fileData.document.children.forEach(traverseNodes);
    
    // Generate index file
    const indexContent = components.map(comp => 
      `export { ${comp.name} } from './${comp.name}';`
    ).join('\n');
    
    fs.writeFileSync(
      path.join(CONFIG.outputDir, 'index.ts'),
      indexContent
    );
    
    console.log('📊 Extraction Summary:');
    console.log(`  • ${Object.keys(tokenExtractor.tokens.colors).length} colors extracted`);
    console.log(`  • ${Object.keys(tokenExtractor.tokens.typography).length} typography styles extracted`);
    console.log(`  • ${Object.keys(tokenExtractor.tokens.shadows).length} shadows extracted`);
    console.log(`  • ${components.length} components generated`);
    console.log('🎉 Figma extraction completed successfully!');
    
  } catch (error) {
    console.error('❌ Extraction failed:', error.message);
    process.exit(1);
  }
}

// CLI interface
if (require.main === module) {
  extractFigmaDesign();
}

module.exports = {
  FigmaClient,
  DesignTokenExtractor,
  ComponentGenerator,
  extractFigmaDesign
};