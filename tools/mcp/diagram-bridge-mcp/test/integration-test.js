#!/usr/bin/env node
/**
 * Integration test for diagram-bridge-mcp
 * Tests actual diagram generation via Kroki
 */

import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const SERVER_PATH = join(__dirname, '..', 'dist', 'index.js');

async function testDiagramGeneration() {
  console.log('🎨 Testing actual diagram generation...\n');

  const server = spawn('node', [SERVER_PATH], {
    stdio: ['pipe', 'pipe', 'pipe']
  });

  let responses = [];
  let complete = false;

  server.stdout.on('data', (data) => {
    const lines = data.toString().split('\n').filter(line => line.trim());
    for (const line of lines) {
      try {
        const response = JSON.parse(line);
        responses.push(response);
      } catch (e) {
        // Ignore non-JSON lines
      }
    }
  });

  // Test diagram rendering
  const renderRequest = {
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/call',
    params: {
      name: 'diagram_render',
      arguments: {
        engine: 'mermaid',
        code: `graph TD
    A[Start] --> B{Decision}
    B -->|Yes| C[Process]
    B -->|No| D[Alternative]
    C --> E[End]
    D --> E`,
        output: 'svg',
        saveFile: false,
        returnDataUri: true
      }
    }
  };

  console.log('Sending render request...');
  server.stdin.write(JSON.stringify(renderRequest) + '\n');

  // Wait for response
  await new Promise(resolve => setTimeout(resolve, 5000));

  server.kill();

  console.log('📋 Integration Test Results:');
  console.log(`- Total responses: ${responses.length}`);
  
  const renderResponse = responses.find(r => r.id === 1);
  if (renderResponse) {
    if (renderResponse.result?.content?.[0]?.text?.startsWith('data:image/svg+xml;base64,')) {
      console.log('✅ SVG diagram generated successfully');
      console.log('✅ Data URI format correct');
      return true;
    } else if (renderResponse.error) {
      console.log('❌ Render error:', renderResponse.error.message);
    } else {
      console.log('❌ Unexpected response format:', JSON.stringify(renderResponse, null, 2));
    }
  } else {
    console.log('❌ No render response received');
  }

  return false;
}

async function testKrokiConnectivity() {
  console.log('🌐 Testing Kroki API connectivity...');
  
  try {
    const response = await fetch('https://kroki.io/mermaid/svg', {
      method: 'POST',
      headers: { 'Content-Type': 'text/plain' },
      body: 'graph TD; A-->B;'
    });

    if (response.ok) {
      console.log('✅ Kroki API is accessible');
      return true;
    } else {
      console.log('❌ Kroki API returned:', response.status);
      return false;
    }
  } catch (error) {
    console.log('❌ Kroki connectivity failed:', error.message);
    return false;
  }
}

async function main() {
  console.log('🧪 diagram-bridge-mcp Integration Tests\n');

  const tests = [
    { name: 'Kroki Connectivity', fn: testKrokiConnectivity },
    { name: 'Diagram Generation', fn: testDiagramGeneration }
  ];

  let passed = 0;

  for (const { name, fn } of tests) {
    console.log(`\n--- ${name} ---`);
    try {
      const result = await fn();
      if (result) {
        console.log(`✅ ${name} passed`);
        passed++;
      } else {
        console.log(`❌ ${name} failed`);
      }
    } catch (error) {
      console.log(`❌ ${name} error:`, error.message);
    }
  }

  console.log(`\n🏁 Integration Results: ${passed}/${tests.length} tests passed`);
  
  if (passed === tests.length) {
    console.log('\n🎉 All integration tests passed! The MCP server is fully functional.');
  } else {
    console.log('\n⚠️  Some integration tests failed. The server may have limited functionality.');
  }
}

main().catch(console.error);