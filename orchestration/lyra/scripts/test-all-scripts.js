#!/usr/bin/env node
/**
 * Test all Lyra orchestration scripts locally
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';

const execAsync = promisify(exec);

console.log('🧪 Testing all Lyra orchestration scripts...');

const testScripts = [
  {
    name: 'W1: Azure Design System',
    script: 'scripts/apply-azure-theme.js',
    required: true
  },
  {
    name: 'W2: Docs Chunking',
    script: 'scripts/docs/chunk-docs.js',
    args: '--src docs --out .test-chunks.jsonl',
    required: true
  },
  {
    name: 'W2: Docs Embedding', 
    script: 'scripts/docs/embed-docs.js',
    args: '--in .test-chunks.jsonl --tenant test',
    required: false // Optional due to OpenAI dependency
  },
  {
    name: 'W3: Ask Scout Hardening',
    script: 'scripts/ask-scout/add-cache-and-guards.js',
    required: true
  },
  {
    name: 'W4: SQL Playground Enhancement',
    script: 'scripts/playground/add-saved-queries.js',
    required: true
  },
  {
    name: 'W5: Schema Graph Builder',
    script: 'scripts/schema/build-graph.js',
    required: true
  },
  {
    name: 'W6: API Explorer Catalog',
    script: 'scripts/api-explorer/generate-catalog.js',
    required: true
  },
  {
    name: 'W8: Learning Paths Builder',
    script: 'scripts/learning/build-tracks.js',
    required: true
  },
  {
    name: 'W8: Sample Testing',
    script: 'scripts/learning/test-samples.js',
    required: true
  },
  {
    name: 'W9: Vercel Configuration',
    script: 'scripts/deploy/vercel-configure.js',
    required: true
  },
  {
    name: 'Report Generation',
    script: 'scripts/report/merge-gates.js',
    required: true
  }
];

async function testScript(test) {
  const { name, script, args = '', required } = test;
  const scriptPath = path.join(process.cwd(), script);
  
  if (!fs.existsSync(scriptPath)) {
    console.log(`❌ ${name}: Script not found - ${scriptPath}`);
    return { name, status: 'MISSING', required };
  }
  
  try {
    console.log(`🔍 Testing: ${name}...`);
    
    const command = `node ${scriptPath} ${args}`.trim();
    const { stdout, stderr } = await execAsync(command, {
      timeout: 30000, // 30 second timeout
      env: {
        ...process.env,
        // Mock environment for testing
        SUPABASE_URL: 'https://test.supabase.co',
        SUPABASE_ANON_KEY: 'test-key',
        USER_JWT: 'test-jwt',
        TENANT_ID: 'test-tenant'
      }
    });
    
    console.log(`✅ ${name}: SUCCESS`);
    return {
      name,
      status: 'SUCCESS',
      required,
      output: stdout.split('\n').slice(-3).join('\n') // Last 3 lines
    };
    
  } catch (error) {
    const status = required ? 'FAILED' : 'SKIPPED';
    const emoji = required ? '❌' : '⚠️';
    
    console.log(`${emoji} ${name}: ${status} - ${error.message.split('\n')[0]}`);
    
    return {
      name,
      status,
      required,
      error: error.message.split('\n')[0]
    };
  }
}

async function runAllTests() {
  const results = [];
  
  console.log(`🚀 Running ${testScripts.length} script tests...\n`);
  
  for (const test of testScripts) {
    const result = await testScript(test);
    results.push(result);
  }
  
  // Generate summary
  const totalTests = results.length;
  const successCount = results.filter(r => r.status === 'SUCCESS').length;
  const failedCount = results.filter(r => r.status === 'FAILED').length;
  const skippedCount = results.filter(r => r.status === 'SKIPPED').length;
  const missingCount = results.filter(r => r.status === 'MISSING').length;
  
  console.log(`\n📋 Test Summary:`);
  console.log(`   ✅ Successful: ${successCount}/${totalTests}`);
  console.log(`   ❌ Failed: ${failedCount}/${totalTests}`);
  console.log(`   ⚠️  Skipped: ${skippedCount}/${totalTests}`);
  console.log(`   📁 Missing: ${missingCount}/${totalTests}`);
  
  // Check for required failures
  const requiredFailures = results.filter(r => r.required && r.status !== 'SUCCESS');
  
  if (requiredFailures.length > 0) {
    console.log(`\n❌ Required script failures:`);
    requiredFailures.forEach(r => {
      console.log(`   - ${r.name}: ${r.status}`);
    });
  }
  
  // Save test report
  const report = {
    timestamp: new Date().toISOString(),
    summary: {
      total: totalTests,
      successful: successCount,
      failed: failedCount,
      skipped: skippedCount,
      missing: missingCount,
      required_failures: requiredFailures.length
    },
    results: results
  };
  
  const reportPath = './orchestration/lyra/artifacts/script-test-report.json';
  fs.mkdirSync(path.dirname(reportPath), { recursive: true });
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`\n📄 Test report saved: ${reportPath}`);
  
  // Cleanup test files
  try {
    if (fs.existsSync('.test-chunks.jsonl')) {
      fs.unlinkSync('.test-chunks.jsonl');
    }
  } catch (e) {
    // Ignore cleanup errors
  }
  
  // Exit with appropriate code
  if (requiredFailures.length > 0) {
    console.log(`\n❌ Testing FAILED: ${requiredFailures.length} required scripts failed`);
    process.exit(1);
  } else {
    console.log(`\n✅ Testing PASSED: All required scripts working`);
    process.exit(0);
  }
}

runAllTests().catch(error => {
  console.error('❌ Test runner failed:', error.message);
  process.exit(1);
});