#!/usr/bin/env node
/**
 * W1: Azure Design System - Apply theme tokens & CSS import
 * Gate: build passes; no Percy diffs > 0.5% on core pages
 */

import fs from 'fs';
import path from 'path';

console.log('🎨 Applying Azure Design System theme...');

const azureThemeTokens = {
  colors: {
    primary: '#0078d4',
    secondary: '#106ebe',
    accent: '#0060c7',
    neutral: {
      50: '#fafafa',
      100: '#f5f5f5',
      200: '#eeeeee',
      300: '#e0e0e0',
      400: '#bdbdbd',
      500: '#9e9e9e',
      600: '#757575',
      700: '#616161',
      800: '#424242',
      900: '#212121'
    }
  },
  typography: {
    fontFamily: "'Segoe UI', Tahoma, Geneva, Verdana, sans-serif",
    fontSize: {
      xs: '0.75rem',
      sm: '0.875rem',
      base: '1rem',
      lg: '1.125rem',
      xl: '1.25rem',
      '2xl': '1.5rem',
      '3xl': '1.875rem',
      '4xl': '2.25rem'
    }
  },
  spacing: {
    xs: '0.25rem',
    sm: '0.5rem',
    md: '1rem',
    lg: '1.5rem',
    xl: '3rem'
  },
  borderRadius: {
    sm: '2px',
    md: '4px',
    lg: '8px'
  }
};

// Generate CSS custom properties
const cssVariables = Object.entries(azureThemeTokens.colors).map(([key, value]) => {
  if (typeof value === 'object') {
    return Object.entries(value).map(([subKey, subValue]) => 
      `  --color-${key}-${subKey}: ${subValue};`
    ).join('\n');
  }
  return `  --color-${key}: ${value};`;
}).join('\n');

const azureThemeCSS = `
/* Azure Design System Theme */
:root {
${cssVariables}
  --font-family-primary: ${azureThemeTokens.typography.fontFamily};
  --border-radius-sm: ${azureThemeTokens.borderRadius.sm};
  --border-radius-md: ${azureThemeTokens.borderRadius.md};
  --border-radius-lg: ${azureThemeTokens.borderRadius.lg};
  --spacing-xs: ${azureThemeTokens.spacing.xs};
  --spacing-sm: ${azureThemeTokens.spacing.sm};
  --spacing-md: ${azureThemeTokens.spacing.md};
  --spacing-lg: ${azureThemeTokens.spacing.lg};
  --spacing-xl: ${azureThemeTokens.spacing.xl};
}

/* Azure component styles */
.azure-button {
  background-color: var(--color-primary);
  color: white;
  border: none;
  border-radius: var(--border-radius-md);
  padding: var(--spacing-sm) var(--spacing-md);
  font-family: var(--font-family-primary);
  cursor: pointer;
  transition: background-color 0.2s ease;
}

.azure-button:hover {
  background-color: var(--color-secondary);
}

.azure-card {
  background: white;
  border: 1px solid var(--color-neutral-200);
  border-radius: var(--border-radius-lg);
  padding: var(--spacing-lg);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.azure-input {
  border: 1px solid var(--color-neutral-300);
  border-radius: var(--border-radius-md);
  padding: var(--spacing-sm);
  font-family: var(--font-family-primary);
  transition: border-color 0.2s ease;
}

.azure-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px rgba(0, 120, 212, 0.2);
}
`;

try {
  // Check if we're in scout-analytics-blueprint-doc or ai-aas-hardened-lakehouse
  const possiblePaths = [
    './scout-analytics-blueprint-doc/src/styles/azure-theme.css',
    './src/styles/azure-theme.css',
    './styles/azure-theme.css',
    './public/css/azure-theme.css'
  ];

  let targetPath = null;
  for (const p of possiblePaths) {
    const dir = path.dirname(p);
    if (fs.existsSync(dir) || p.includes('scout-analytics')) {
      targetPath = p;
      break;
    }
  }

  if (!targetPath) {
    // Create default path
    targetPath = './styles/azure-theme.css';
    fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  }

  fs.writeFileSync(targetPath, azureThemeCSS);
  console.log(`✅ Azure theme written to: ${targetPath}`);

  // Update main CSS/index files to import the theme
  const importStatement = `@import './azure-theme.css';`;
  const mainCSSPaths = [
    './scout-analytics-blueprint-doc/src/styles/globals.css',
    './src/styles/globals.css',
    './styles/main.css',
    './public/css/main.css'
  ];

  for (const cssPath of mainCSSPaths) {
    if (fs.existsSync(cssPath)) {
      let content = fs.readFileSync(cssPath, 'utf8');
      if (!content.includes('azure-theme.css')) {
        content = importStatement + '\n' + content;
        fs.writeFileSync(cssPath, content);
        console.log(`✅ Import added to: ${cssPath}`);
      }
      break;
    }
  }

  // Create theme.json for design tokens
  const themeTokensPath = './public/theme-tokens.json';
  fs.mkdirSync(path.dirname(themeTokensPath), { recursive: true });
  fs.writeFileSync(themeTokensPath, JSON.stringify(azureThemeTokens, null, 2));
  console.log(`✅ Theme tokens written to: ${themeTokensPath}`);

  console.log('🎨 Azure Design System applied successfully');
  process.exit(0);

} catch (error) {
  console.error('❌ Error applying Azure theme:', error.message);
  process.exit(1);
}