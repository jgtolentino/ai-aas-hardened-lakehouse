#!/usr/bin/env node

/**
 * Code Connect Validator
 * 
 * Validates all *.figma.tsx mappings to ensure consistency
 * and prevent CI failures from missing required props
 */

import { readFileSync, readdirSync, statSync } from 'fs';
import { join, extname } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const rootDir = join(__dirname, '..');

class CodeConnectValidator {
  constructor() {
    this.errors = [];
    this.warnings = [];
    this.validatedFiles = 0;
  }

  /**
   * Find all .figma.tsx files in the project
   */
  findFigmaFiles(dir = rootDir) {
    const figmaFiles = [];
    
    const scan = (currentDir) => {
      const entries = readdirSync(currentDir);
      
      for (const entry of entries) {
        const fullPath = join(currentDir, entry);
        const stat = statSync(fullPath);
        
        if (stat.isDirectory()) {
          // Skip node_modules and hidden directories
          if (!entry.startsWith('.') && entry !== 'node_modules' && entry !== 'dist') {
            scan(fullPath);
          }
        } else if (entry.endsWith('.figma.tsx') || entry.endsWith('.figma.ts')) {
          figmaFiles.push(fullPath);
        }
      }
    };
    
    scan(dir);
    return figmaFiles;
  }

  /**
   * Validate a single Figma Code Connect mapping file
   */
  validateFigmaFile(filePath) {
    try {
      const content = readFileSync(filePath, 'utf8');
      const relativePath = filePath.replace(rootDir, '').replace(/^\//, '');
      
      this.validatedFiles++;
      console.log(`[${this.validatedFiles}] Validating ${relativePath}`);
      
      // Check for required Code Connect patterns
      const checks = [
        {
          pattern: /figma\.connect/,
          message: 'Missing figma.connect() call',
          required: true,
        },
        {
          pattern: /component:\s*[A-Za-z]/,
          message: 'Missing component reference in figma.connect()',
          required: true,
        },
        {
          pattern: /figmaNodeUrl:\s*['"]/,
          message: 'Missing figmaNodeUrl in figma.connect()',
          required: true,
        },
        {
          pattern: /@figmaId\s*:\s*['"]/,
          message: 'Consider using @figmaId annotation for better IDE integration',
          required: false,
        },
        {
          pattern: /variant:\s*{/,
          message: 'Missing variant mapping for component states',
          required: false,
        },
        {
          pattern: /import.*figma/i,
          message: 'Missing Figma Code Connect import',
          required: true,
        },
      ];

      for (const check of checks) {
        if (!check.pattern.test(content)) {
          const issue = `${relativePath}: ${check.message}`;
          
          if (check.required) {
            this.errors.push(issue);
          } else {
            this.warnings.push(issue);
          }
        }
      }

      // Check for component name consistency
      const componentNameMatch = content.match(/component:\s*([A-Za-z][A-Za-z0-9]*)/);
      const fileNameMatch = filePath.match(/([A-Za-z][A-Za-z0-9]*)\.figma\.tsx?$/);
      
      if (componentNameMatch && fileNameMatch) {
        const componentName = componentNameMatch[1];
        const fileName = fileNameMatch[1];
        
        if (componentName !== fileName) {
          this.warnings.push(
            `${relativePath}: Component name "${componentName}" doesn't match file name "${fileName}"`
          );
        }
      }

      // Check for Figma URL format
      const figmaUrlMatch = content.match(/figmaNodeUrl:\s*['"]([^'"]+)['"]/);
      if (figmaUrlMatch) {
        const url = figmaUrlMatch[1];
        if (!url.includes('figma.com') || !url.includes('node-id=')) {
          this.errors.push(
            `${relativePath}: Invalid Figma URL format. Should include figma.com and node-id parameter`
          );
        }
      }

      // Check for props validation
      const propsMatch = content.match(/props:\s*{([^}]+)}/s);
      if (propsMatch) {
        const propsContent = propsMatch[1];
        
        // Look for TypeScript prop types
        const propLines = propsContent.split('\n').filter(line => line.trim() && !line.trim().startsWith('//'));
        
        for (const line of propLines) {
          const propMatch = line.match(/(\w+):\s*(.+)/);
          if (propMatch) {
            const [, propName, propMapping] = propMatch;
            
            // Check for proper prop mapping
            if (!propMapping.includes('figma.') && !propMapping.includes('props.') && !propMapping.includes('"') && !propMapping.includes("'")) {
              this.warnings.push(
                `${relativePath}: Prop "${propName}" may need explicit mapping or default value`
              );
            }
          }
        }
      }

    } catch (error) {
      this.errors.push(`${filePath}: Failed to parse file - ${error.message}`);
    }
  }

  /**
   * Run validation on all Figma files
   */
  async validate() {
    console.log('🔍 Starting Code Connect validation...\n');
    
    const figmaFiles = this.findFigmaFiles();
    
    if (figmaFiles.length === 0) {
      console.log('⚠️  No .figma.tsx files found in the project');
      return { success: true, errors: [], warnings: [] };
    }

    console.log(`Found ${figmaFiles.length} Code Connect mapping files\n`);

    for (const file of figmaFiles) {
      this.validateFigmaFile(file);
    }

    return this.getResults();
  }

  /**
   * Get validation results
   */
  getResults() {
    const hasErrors = this.errors.length > 0;
    const hasWarnings = this.warnings.length > 0;

    console.log('\n📊 Validation Results:');
    console.log(`Files checked: ${this.validatedFiles}`);
    console.log(`Errors: ${this.errors.length}`);
    console.log(`Warnings: ${this.warnings.length}`);

    if (hasErrors) {
      console.log('\n❌ Errors:');
      this.errors.forEach(error => console.log(`  - ${error}`));
    }

    if (hasWarnings) {
      console.log('\n⚠️  Warnings:');
      this.warnings.forEach(warning => console.log(`  - ${warning}`));
    }

    if (!hasErrors && !hasWarnings) {
      console.log('\n✅ All Code Connect mappings are valid!');
    }

    return {
      success: !hasErrors,
      errors: this.errors,
      warnings: this.warnings,
      filesChecked: this.validatedFiles,
    };
  }
}

// CLI execution
if (import.meta.url === `file://${process.argv[1]}`) {
  const validator = new CodeConnectValidator();
  
  validator.validate()
    .then((results) => {
      if (results.success) {
        console.log('\n🎉 Code Connect validation passed!');
        process.exit(0);
      } else {
        console.log('\n💥 Code Connect validation failed!');
        process.exit(1);
      }
    })
    .catch((error) => {
      console.error('Validation failed with error:', error);
      process.exit(1);
    });
}

export { CodeConnectValidator };