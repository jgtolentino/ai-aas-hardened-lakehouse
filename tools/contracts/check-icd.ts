#!/usr/bin/env node
import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';
import { z } from 'zod';

const REPO_ROOT = path.resolve(process.cwd());
const ICD_PATH = path.join(REPO_ROOT, 'docs', 'scout', 'ICD.md');
const CONTRACTS_PATH = path.join(REPO_ROOT, 'packages', 'contracts', 'src');

/**
 * Schema for ICD endpoint definition
 */
const EndpointSchema = z.object({
  endpoint: z.string(),
  method: z.enum(['GET', 'POST', 'PUT', 'DELETE', 'PATCH']),
  version: z.string().regex(/^\d+\.\d+\.\d+$/),
  request: z.object({
    type: z.string(),
    schema: z.record(z.any())
  }),
  response: z.object({
    type: z.string(),
    schema: z.any()
  }),
  errors: z.array(z.object({
    code: z.number(),
    type: z.string()
  })),
  sla: z.object({
    p95: z.string(),
    p99: z.string()
  })
});

/**
 * Extract endpoint definitions from ICD
 */
function extractEndpoints(icdContent: string): any[] {
  const endpoints = [];
  const yamlBlocks = icdContent.match(/```yaml\n([\s\S]*?)```/g);
  
  if (yamlBlocks) {
    yamlBlocks.forEach(block => {
      const content = block.replace(/```yaml\n/, '').replace(/```/, '');
      try {
        const parsed = yaml.load(content);
        if (parsed && parsed.endpoint) {
          endpoints.push(parsed);
        }
      } catch (e) {
        // Skip non-endpoint YAML blocks
      }
    });
  }
  
  return endpoints;
}

/**
 * Load TypeScript contracts from packages/contracts
 */
async function loadTypeScriptContracts() {
  const contracts = new Map();
  
  // Look for index.ts
  const indexPath = path.join(CONTRACTS_PATH, 'index.ts');
  if (fs.existsSync(indexPath)) {
    const content = fs.readFileSync(indexPath, 'utf-8');
    
    // Extract exported interfaces
    const interfaceMatches = content.matchAll(/export\s+interface\s+(\w+)\s*{([^}]*)}/g);
    for (const match of interfaceMatches) {
      const name = match[1];
      const body = match[2];
      contracts.set(name, { name, body, type: 'interface' });
    }
    
    // Extract exported types
    const typeMatches = content.matchAll(/export\s+type\s+(\w+)\s*=\s*([^;]+);/g);
    for (const match of typeMatches) {
      const name = match[1];
      const definition = match[2];
      contracts.set(name, { name, definition, type: 'type' });
    }
  }
  
  return contracts;
}

/**
 * Validate ICD against TypeScript contracts
 */
async function validateContracts() {
  console.log('🔍 Validating ICD against TypeScript contracts...\n');
  
  // Read ICD
  const icdContent = fs.readFileSync(ICD_PATH, 'utf-8');
  const endpoints = extractEndpoints(icdContent);
  
  console.log(`Found ${endpoints.length} endpoints in ICD`);
  
  // Load TypeScript contracts
  const tsContracts = await loadTypeScriptContracts();
  console.log(`Found ${tsContracts.size} TypeScript contracts\n`);
  
  const issues = [];
  
  // Validate each endpoint
  endpoints.forEach(endpoint => {
    console.log(`Checking ${endpoint.endpoint}...`);
    
    // Validate schema
    try {
      EndpointSchema.parse(endpoint);
      console.log(`  ✅ Schema valid`);
    } catch (e) {
      issues.push(`Schema validation failed for ${endpoint.endpoint}: ${e.message}`);
      console.log(`  ❌ Schema invalid: ${e.message}`);
    }
    
    // Check if request type exists in TypeScript
    if (endpoint.request?.type) {
      if (!tsContracts.has(endpoint.request.type)) {
        issues.push(`Missing TypeScript type: ${endpoint.request.type}`);
        console.log(`  ⚠️  Request type '${endpoint.request.type}' not found in contracts`);
      } else {
        console.log(`  ✅ Request type found`);
      }
    }
    
    // Check if response type exists in TypeScript
    if (endpoint.response?.type) {
      const responseType = endpoint.response.type.replace('[]', '');
      if (!tsContracts.has(responseType)) {
        issues.push(`Missing TypeScript type: ${responseType}`);
        console.log(`  ⚠️  Response type '${responseType}' not found in contracts`);
      } else {
        console.log(`  ✅ Response type found`);
      }
    }
    
    console.log('');
  });
  
  // Report results
  if (issues.length > 0) {
    console.log('❌ Validation failed with issues:\n');
    issues.forEach(issue => console.log(`  - ${issue}`));
    process.exit(1);
  } else {
    console.log('✅ All ICD contracts validated successfully!');
  }
}

/**
 * Generate TypeScript types from ICD
 */
async function generateTypes() {
  console.log('🏗️  Generating TypeScript types from ICD...\n');
  
  const icdContent = fs.readFileSync(ICD_PATH, 'utf-8');
  const endpoints = extractEndpoints(icdContent);
  
  let output = `// Generated from ICD.md - DO NOT EDIT MANUALLY
// Run 'npm run icd:types' to regenerate

`;

  // Generate endpoint types
  endpoints.forEach(endpoint => {
    const typeName = endpoint.endpoint
      .split('/')
      .filter(p => p && !p.includes(':'))
      .map(p => p.charAt(0).toUpperCase() + p.slice(1))
      .join('');
    
    output += `// ${endpoint.endpoint} (v${endpoint.version})\n`;
    output += `export interface ${typeName}Request {\n`;
    
    if (endpoint.request?.schema) {
      Object.entries(endpoint.request.schema).forEach(([key, value]: [string, any]) => {
        const required = value.required ? '' : '?';
        const type = mapSchemaType(value.type || value);
        output += `  ${key}${required}: ${type};\n`;
      });
    }
    
    output += `}\n\n`;
    
    output += `export interface ${typeName}Response {\n`;
    
    if (endpoint.response?.schema) {
      if (Array.isArray(endpoint.response.schema)) {
        // Array response
        output += `  data: Array<{\n`;
        endpoint.response.schema[0] && Object.entries(endpoint.response.schema[0]).forEach(([key, value]: [string, any]) => {
          const type = mapSchemaType(value.type || value);
          output += `    ${key}: ${type};\n`;
        });
        output += `  }>;\n`;
      } else {
        // Object response
        Object.entries(endpoint.response.schema).forEach(([key, value]: [string, any]) => {
          const type = mapSchemaType(value.type || value);
          output += `  ${key}: ${type};\n`;
        });
      }
    }
    
    output += `}\n\n`;
  });
  
  // Write generated types
  const outputPath = path.join(CONTRACTS_PATH, 'generated.ts');
  fs.writeFileSync(outputPath, output);
  console.log(`✅ Generated types written to ${outputPath}`);
}

/**
 * Map ICD schema types to TypeScript types
 */
function mapSchemaType(schemaType: any): string {
  if (typeof schemaType === 'string') {
    switch (schemaType) {
      case 'string': return 'string';
      case 'integer': return 'number';
      case 'number': return 'number';
      case 'boolean': return 'boolean';
      case 'object': return 'Record<string, any>';
      case 'array': return 'any[]';
      case 'date-time': return 'string'; // ISO8601
      default: return schemaType; // Custom type reference
    }
  }
  
  if (schemaType.enum) {
    return schemaType.enum.map(v => `'${v}'`).join(' | ');
  }
  
  if (schemaType.type === 'array') {
    return `${mapSchemaType(schemaType.items || 'any')}[]`;
  }
  
  return 'any';
}

// Main execution
const command = process.argv[2];

switch (command) {
  case 'validate':
    validateContracts();
    break;
  case 'generate':
    generateTypes();
    break;
  default:
    console.log('Usage: check-icd.ts [validate|generate]');
    process.exit(1);
}
