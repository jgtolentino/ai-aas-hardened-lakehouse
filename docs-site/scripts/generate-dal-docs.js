#!/usr/bin/env node

/**
 * Script to auto-generate DAL documentation from TypeScript source files
 * Reads gold-dal.ts and generates comprehensive markdown documentation
 */

const fs = require('fs');
const path = require('path');
const ts = require('typescript');

// Paths
const DAL_SOURCE_PATH = path.join(__dirname, '../modules/scout-analytics-dashboard/src/lib/gold-dal.ts');
const DAL_ALIGNMENT_PATH = path.join(__dirname, '../packages/scout-alignment/dal.ts');
const OUTPUT_PATH = path.join(__dirname, 'docs/dal/gold-fetchers.md');

/**
 * Parse TypeScript file and extract function signatures
 */
function parseTypeScriptFile(filePath) {
  const sourceCode = fs.readFileSync(filePath, 'utf8');
  const sourceFile = ts.createSourceFile(
    filePath,
    sourceCode,
    ts.ScriptTarget.Latest,
    true
  );

  const functions = [];
  
  function visit(node) {
    if (ts.isFunctionDeclaration(node) || ts.isMethodDeclaration(node)) {
      const name = node.name?.getText(sourceFile);
      const params = node.parameters.map(param => ({
        name: param.name.getText(sourceFile),
        type: param.type?.getText(sourceFile) || 'any',
        optional: !!param.questionToken,
        default: param.initializer?.getText(sourceFile)
      }));
      
      const returnType = node.type?.getText(sourceFile) || 'void';
      const jsDoc = getJSDocComment(node, sourceFile);
      
      functions.push({
        name,
        params,
        returnType,
        description: jsDoc?.description || '',
        example: jsDoc?.example || ''
      });
    }
    
    ts.forEachChild(node, visit);
  }
  
  visit(sourceFile);
  return functions;
}

/**
 * Extract JSDoc comments
 */
function getJSDocComment(node, sourceFile) {
  const jsDocs = ts.getJSDocCommentsAndTags(node);
  if (jsDocs.length > 0) {
    const comment = jsDocs[0].comment;
    if (typeof comment === 'string') {
      return parseJSDocText(comment);
    }
  }
  return null;
}

/**
 * Parse JSDoc text into structured format
 */
function parseJSDocText(text) {
  const lines = text.split('\n');
  let description = '';
  let example = '';
  let isExample = false;
  
  lines.forEach(line => {
    if (line.includes('@example')) {
      isExample = true;
    } else if (line.includes('@')) {
      isExample = false;
    } else if (isExample) {
      example += line + '\n';
    } else {
      description += line + ' ';
    }
  });
  
  return {
    description: description.trim(),
    example: example.trim()
  };
}

/**
 * Generate markdown documentation
 */
function generateMarkdown(functions) {
  let markdown = `---
title: Gold Layer DAL Functions
sidebar_label: Gold Fetchers
sidebar_position: 3
---

# Gold Layer DAL Function Reference

This document provides a comprehensive reference for all Data Abstraction Layer (DAL) functions that interact with the Gold layer views.

## 📦 Import

\`\`\`typescript
import { makeGoldDal } from '@/lib/gold-dal';
import { createClient } from '@supabase/supabase-js';

// Initialize Supabase client
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

// Create DAL instance
const dal = makeGoldDal(supabase);
\`\`\`

## 📊 Core Functions

`;

  // Group functions by category
  const categories = {
    'Brand Analytics': ['getBrandShare', 'getBrandPenetration', 'getBrandPerformance'],
    'Customer Analytics': ['getCustomerSegments', 'getCustomerRetention', 'getCustomerActivity'],
    'Product Analytics': ['getProductVelocity', 'getProductAffinity', 'getProductPerformance'],
    'Geographic Analytics': ['getGeoPerformance', 'getGeoHeatmap', 'getGeoSales'],
    'Competitive Intelligence': ['getCompetitiveShare', 'getSubstitutionMatrix'],
    'Time Series': ['getSalesForecast', 'getTrendAnalysis'],
    'Aggregations': ['getDailySummary', 'getWeeklyBusinessReview', 'getExecutiveSummary']
  };

  Object.entries(categories).forEach(([category, functionNames]) => {
    markdown += `\n### ${category}\n\n`;
    
    const categoryFunctions = functions.filter(f => 
      functionNames.some(name => f.name?.toLowerCase().includes(name.toLowerCase()))
    );
    
    if (categoryFunctions.length === 0) {
      // If no matching functions found, add placeholder
      markdown += `*Functions in development*\n\n`;
    } else {
      categoryFunctions.forEach(func => {
        markdown += generateFunctionDoc(func);
      });
    }
  });

  // Add unmatched functions
  const allCategoryFunctions = Object.values(categories).flat();
  const unmatchedFunctions = functions.filter(f => 
    !allCategoryFunctions.some(name => f.name?.toLowerCase().includes(name.toLowerCase()))
  );
  
  if (unmatchedFunctions.length > 0) {
    markdown += `\n### Other Functions\n\n`;
    unmatchedFunctions.forEach(func => {
      markdown += generateFunctionDoc(func);
    });
  }

  // Add best practices section
  markdown += `
## 🎯 Best Practices

### Error Handling

Always wrap DAL calls in try-catch blocks:

\`\`\`typescript
try {
  const data = await dal.getBrandShare({
    date_from: '2025-01-01',
    date_to: '2025-01-31'
  });
  // Process data
} catch (error) {
  console.error('Failed to fetch brand share:', error);
  // Handle error appropriately
}
\`\`\`

### Pagination

For large datasets, use pagination parameters:

\`\`\`typescript
const PAGE_SIZE = 100;
let offset = 0;
let hasMore = true;

while (hasMore) {
  const data = await dal.listTxnItems({
    date_from: '2025-01-01',
    date_to: '2025-01-31',
    limit: PAGE_SIZE,
    offset: offset
  });
  
  // Process batch
  processBatch(data);
  
  hasMore = data.length === PAGE_SIZE;
  offset += PAGE_SIZE;
}
\`\`\`

### Caching

Implement client-side caching for frequently accessed data:

\`\`\`typescript
const cache = new Map();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

async function getCachedData(key, fetcher) {
  const cached = cache.get(key);
  
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.data;
  }
  
  const data = await fetcher();
  cache.set(key, { data, timestamp: Date.now() });
  return data;
}

// Usage
const brandShare = await getCachedData(
  'brand-share-2025-01',
  () => dal.getBrandShare({ date_from: '2025-01-01', date_to: '2025-01-31' })
);
\`\`\`

### Type Safety

Always use TypeScript interfaces for parameters and return types:

\`\`\`typescript
interface BrandShareParams {
  date_from: string;
  date_to: string;
  region_id?: number;
  category_id?: number;
}

interface BrandShareResult {
  brand_id: number;
  brand_name: string;
  market_share_pct: number;
  trend: 'up' | 'down' | 'stable';
}

async function analyzeBrandPerformance(
  params: BrandShareParams
): Promise<BrandShareResult[]> {
  return await dal.getBrandShare(params);
}
\`\`\`

## 🔗 Related Documentation

- [DAL Overview](/docs/dal/overview)
- [DAL Usage Guide](/docs/dal/usage)
- [API Reference](/docs/api/gold-apis)
- [Migration Guide](/docs/dal/migration-guide)

---

*Generated from source code on ${new Date().toISOString().split('T')[0]}*
`;

  return markdown;
}

/**
 * Generate documentation for a single function
 */
function generateFunctionDoc(func) {
  if (!func.name) return '';
  
  let doc = `#### \`${func.name}()\`\n\n`;
  
  if (func.description) {
    doc += `${func.description}\n\n`;
  }
  
  // Parameters
  if (func.params.length > 0) {
    doc += `**Parameters:**\n\n`;
    doc += `\`\`\`typescript\n{\n`;
    func.params.forEach(param => {
      const optional = param.optional ? '?' : '';
      const defaultVal = param.default ? ` = ${param.default}` : '';
      doc += `  ${param.name}${optional}: ${param.type}${defaultVal};\n`;
    });
    doc += `}\n\`\`\`\n\n`;
  }
  
  // Return type
  doc += `**Returns:** \`${func.returnType}\`\n\n`;
  
  // Example
  if (func.example) {
    doc += `**Example:**\n\n\`\`\`typescript\n${func.example}\n\`\`\`\n\n`;
  } else {
    // Generate default example
    doc += `**Example:**\n\n\`\`\`typescript\n`;
    doc += `const result = await dal.${func.name}({\n`;
    func.params.forEach(param => {
      if (!param.optional) {
        const exampleValue = getExampleValue(param.type);
        doc += `  ${param.name}: ${exampleValue},\n`;
      }
    });
    doc += `});\n\`\`\`\n\n`;
  }
  
  doc += `---\n\n`;
  return doc;
}

/**
 * Generate example values based on type
 */
function getExampleValue(type) {
  if (type.includes('string')) return `'example'`;
  if (type.includes('number')) return `123`;
  if (type.includes('boolean')) return `true`;
  if (type.includes('Date')) return `new Date()`;
  if (type.includes('[]')) return `[]`;
  return `{}`;
}

/**
 * Main execution
 */
async function main() {
  try {
    console.log('📚 Generating DAL documentation...');
    
    // Parse source files
    const goldDalFunctions = parseTypeScriptFile(DAL_SOURCE_PATH);
    const alignmentDalFunctions = parseTypeScriptFile(DAL_ALIGNMENT_PATH);
    
    // Combine functions (remove duplicates)
    const allFunctions = [...goldDalFunctions];
    alignmentDalFunctions.forEach(func => {
      if (!allFunctions.find(f => f.name === func.name)) {
        allFunctions.push(func);
      }
    });
    
    // Generate markdown
    const markdown = generateMarkdown(allFunctions);
    
    // Ensure output directory exists
    const outputDir = path.dirname(OUTPUT_PATH);
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
    
    // Write output
    fs.writeFileSync(OUTPUT_PATH, markdown);
    
    console.log(`✅ Documentation generated: ${OUTPUT_PATH}`);
    console.log(`📊 Documented ${allFunctions.length} functions`);
    
  } catch (error) {
    console.error('❌ Error generating documentation:', error);
    process.exit(1);
  }
}

// Run if executed directly
if (require.main === module) {
  main();
}

module.exports = {
  parseTypeScriptFile,
  generateMarkdown
};
