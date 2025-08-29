#!/usr/bin/env node

/**
 * Check ICD document against TypeScript contracts
 * Run: node tools/contracts/check-icd.js
 */

const fs = require('fs');
const path = require('path');
const ts = require('typescript');
const yaml = require('js-yaml');

// Paths
const ICD_PATH = path.join(__dirname, '../../docs/scout/ICD.md');
const CONTRACTS_PATH = path.join(__dirname, '../../packages/contracts/src/index.ts');

// Parse ICD document
function parseICD(icdContent) {
  const endpoints = [];
  const yamlBlocks = icdContent.matchAll(/```yaml\n([\s\S]*?)\n```/g);
  
  for (const match of yamlBlocks) {
    try {
      const spec = yaml.load(match[1]);
      if (spec.endpoint) {
        endpoints.push(spec);
      }
    } catch (e) {
      // Skip non-endpoint YAML blocks
    }
  }
  
  return endpoints;
}

// Parse TypeScript contracts
function parseTypeScriptContracts(filePath) {
  const fileContent = fs.readFileSync(filePath, 'utf8');
  const sourceFile = ts.createSourceFile(
    filePath,
    fileContent,
    ts.ScriptTarget.Latest,
    true
  );
  
  const contracts = {};
  
  function visit(node) {
    if (ts.isInterfaceDeclaration(node) || ts.isTypeAliasDeclaration(node)) {
      const name = node.name.text;
      contracts[name] = {
        name,
        properties: extractProperties(node),
        kind: ts.isInterfaceDeclaration(node) ? 'interface' : 'type'
      };
    }
    ts.forEachChild(node, visit);
  }
  
  function extractProperties(node) {
    const properties = [];
    
    if (ts.isInterfaceDeclaration(node)) {
      node.members.forEach(member => {
        if (ts.isPropertySignature(member) && member.name) {
          properties.push({
            name: member.name.getText(),
            type: member.type ? member.type.getText() : 'any',
            optional: !!member.questionToken
          });
        }
      });
    }
    
    return properties;
  }
  
  visit(sourceFile);
  return contracts;
}

// Validate endpoint against contract
function validateEndpoint(endpoint, contracts) {
  const errors = [];
  const warnings = [];
  
  // Check if input/output types exist
  const inputTypeName = `${endpoint.endpoint}Input`;
  const outputTypeName = `${endpoint.endpoint}Output`;
  
  if (!contracts[inputTypeName]) {
    warnings.push(`Missing TypeScript type: ${inputTypeName}`);
  } else {
    // Validate input properties
    const inputContract = contracts[inputTypeName];
    const inputProps = endpoint.input?.properties || {};
    
    for (const [propName, propSpec] of Object.entries(inputProps)) {
      const contractProp = inputContract.properties.find(p => p.name === `"${propName}"`);
      if (!contractProp) {
        errors.push(`${endpoint.endpoint}: Input property '${propName}' not in TypeScript contract`);
      }
    }
  }
  
  if (!contracts[outputTypeName]) {
    warnings.push(`Missing TypeScript type: ${outputTypeName}`);
  } else {
    // Validate output properties
    const outputContract = contracts[outputTypeName];
    const outputProps = endpoint.output?.properties || {};
    
    for (const [propName, propSpec] of Object.entries(outputProps)) {
      const contractProp = outputContract.properties.find(p => p.name === `"${propName}"`);
      if (!contractProp) {
        errors.push(`${endpoint.endpoint}: Output property '${propName}' not in TypeScript contract`);
      }
    }
  }
  
  // Check SLA compliance
  if (endpoint.sla?.latency_p95) {
    const latency = parseInt(endpoint.sla.latency_p95);
    if (latency > 3000) {
      warnings.push(`${endpoint.endpoint}: High latency SLA (${latency}ms)`);
    }
  }
  
  return { errors, warnings };
}

// Main validation
async function main() {
  console.log('🔍 Validating ICD against TypeScript contracts...\n');
  
  try {
    // Read files
    const icdContent = fs.readFileSync(ICD_PATH, 'utf8');
    let contracts = {};
    
    // Parse TypeScript contracts if file exists
    if (fs.existsSync(CONTRACTS_PATH)) {
      contracts = parseTypeScriptContracts(CONTRACTS_PATH);
      console.log(`📦 Loaded ${Object.keys(contracts).length} TypeScript types`);
    } else {
      console.log('⚠️  Contracts file not found, skipping type validation');
    }
    
    // Parse ICD
    const endpoints = parseICD(icdContent);
    console.log(`📋 Found ${endpoints.length} endpoints in ICD\n`);
    
    // Validate each endpoint
    let totalErrors = 0;
    let totalWarnings = 0;
    
    for (const endpoint of endpoints) {
      const { errors, warnings } = validateEndpoint(endpoint, contracts);
      
      if (errors.length > 0 || warnings.length > 0) {
        console.log(`\n${endpoint.endpoint} (v${endpoint.version}):`);
        
        errors.forEach(error => {
          console.log(`  ❌ ${error}`);
          totalErrors++;
        });
        
        warnings.forEach(warning => {
          console.log(`  ⚠️  ${warning}`);
          totalWarnings++;
        });
      } else {
        console.log(`✅ ${endpoint.endpoint} (v${endpoint.version})`);
      }
    }
    
    // Summary
    console.log('\n' + '='.repeat(50));
    console.log('📊 Validation Summary:');
    console.log(`  Endpoints validated: ${endpoints.length}`);
    console.log(`  Errors: ${totalErrors}`);
    console.log(`  Warnings: ${totalWarnings}`);
    
    if (totalErrors > 0) {
      console.log('\n❌ ICD validation failed! Fix errors before proceeding.');
      process.exit(1);
    } else if (totalWarnings > 0) {
      console.log('\n⚠️  ICD validation passed with warnings.');
    } else {
      console.log('\n✅ ICD validation passed!');
    }
    
  } catch (error) {
    console.error('❌ Error validating ICD:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { parseICD, parseTypeScriptContracts, validateEndpoint };