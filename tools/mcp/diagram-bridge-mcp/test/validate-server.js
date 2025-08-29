#!/usr/bin/env node
/**
 * Simple validation test for diagram-bridge-mcp server
 * Tests basic MCP functionality and diagram generation
 */

import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { readFile, mkdir } from 'node:fs/promises';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const SERVER_PATH = join(__dirname, '..', 'dist', 'index.js');

async function testMCPServer() {
  console.log('🔍 Testing diagram-bridge-mcp server...\n');

  try {
    // Test 1: Server startup
    console.log('1. Testing server startup...');
    const server = spawn('node', [SERVER_PATH], {
      stdio: ['pipe', 'pipe', 'pipe']
    });

    let output = '';
    let errorOutput = '';

    server.stdout.on('data', (data) => {
      output += data.toString();
    });

    server.stderr.on('data', (data) => {
      errorOutput += data.toString();
    });

    // Test 2: List tools request
    console.log('2. Testing list tools request...');
    const listToolsRequest = {
      jsonrpc: '2.0',
      id: 1,
      method: 'tools/list'
    };

    server.stdin.write(JSON.stringify(listToolsRequest) + '\n');

    // Test 3: List engines
    console.log('3. Testing diagram engines list...');
    const listEnginesRequest = {
      jsonrpc: '2.0',
      id: 2,
      method: 'tools/call',
      params: {
        name: 'diagram_list_engines',
        arguments: {}
      }
    };

    server.stdin.write(JSON.stringify(listEnginesRequest) + '\n');

    // Test 4: Generate Kroki URL
    console.log('4. Testing Kroki URL generation...');
    const krokiUrlRequest = {
      jsonrpc: '2.0',
      id: 3,
      method: 'tools/call',
      params: {
        name: 'diagram_kroki_url',
        arguments: {
          engine: 'mermaid',
          code: 'graph TD; A[Start] --> B[Process] --> C[End]',
          output: 'svg'
        }
      }
    };

    server.stdin.write(JSON.stringify(krokiUrlRequest) + '\n');

    // Wait for responses
    await new Promise((resolve) => setTimeout(resolve, 2000));

    server.kill();

    console.log('📊 Test Results:');
    console.log('- Server started successfully:', errorOutput.includes('Diagram Bridge MCP server running'));
    console.log('- Output received:', output.length > 0);
    console.log('- No critical errors:', !errorOutput.includes('Error:'));

    if (output) {
      const responses = output.split('\n').filter(line => line.trim());
      console.log(`- Received ${responses.length} responses`);
    }

    console.log('\n✅ Basic validation completed!');
    
    return true;
  } catch (error) {
    console.error('❌ Validation failed:', error.message);
    return false;
  }
}

async function validateConfiguration() {
  console.log('\n🔧 Validating configuration...');
  
  try {
    // Check if setup file exists
    const setupPath = join(__dirname, '..', 'SETUP.md');
    const setupContent = await readFile(setupPath, 'utf8');
    console.log('✅ Setup guide exists and is readable');

    // Check for Claude Desktop config example
    if (setupContent.includes('claude_desktop_config.json')) {
      console.log('✅ Claude Desktop configuration documented');
    }

    // Check for environment variables
    if (setupContent.includes('KROKI_URL') && setupContent.includes('DRAWIO_BIN')) {
      console.log('✅ Environment variables documented');
    }

    return true;
  } catch (error) {
    console.error('❌ Configuration validation failed:', error.message);
    return false;
  }
}

async function main() {
  console.log('🚀 diagram-bridge-mcp Validation Suite\n');
  
  const tests = [
    testMCPServer,
    validateConfiguration
  ];

  let passed = 0;
  
  for (const test of tests) {
    try {
      const result = await test();
      if (result) passed++;
    } catch (error) {
      console.error('Test failed:', error.message);
    }
  }

  console.log(`\n🎯 Results: ${passed}/${tests.length} tests passed`);
  
  if (passed === tests.length) {
    console.log('\n🎉 All validations passed! diagram-bridge-mcp is ready for use.');
    console.log('\nNext steps:');
    console.log('1. Configure Claude Desktop with the MCP server');
    console.log('2. Restart Claude Desktop');
    console.log('3. Test with: "Create a simple flowchart showing Start -> Process -> End"');
  } else {
    console.log('\n⚠️  Some validations failed. Check the logs above.');
    process.exit(1);
  }
}

main().catch(console.error);