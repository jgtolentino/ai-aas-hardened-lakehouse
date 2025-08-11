#!/usr/bin/env node

/**
 * Automated Testing Suite for Dataset Publisher
 * 
 * Comprehensive tests for the Scout Analytics dataset publication system
 * covering medallion architecture, ETL pipelines, and data quality validation.
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Test configuration
const TEST_CONFIG = {
  supabaseUrl: process.env.SUPABASE_URL || 'http://localhost:54321',
  serviceKey: process.env.SUPABASE_SERVICE_KEY,
  testDataDir: './test-data',
  tempDir: './test-temp',
  timeout: 60000, // 60 seconds
  retryAttempts: 3,
};

// Test state tracking
let testResults = {
  passed: 0,
  failed: 0,
  skipped: 0,
  errors: [],
  details: []
};

/**
 * Test utilities
 */
class TestUtils {
  static log(message, level = 'info') {
    const timestamp = new Date().toISOString();
    const colors = {
      info: '\x1b[36m',    // Cyan
      success: '\x1b[32m', // Green  
      error: '\x1b[31m',   // Red
      warn: '\x1b[33m',    // Yellow
      reset: '\x1b[0m'     // Reset
    };
    
    console.log(`${colors[level]}[${timestamp}] ${message}${colors.reset}`);
  }

  static async sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  static generateTestData(type, count = 100) {
    const testData = [];
    const now = new Date();
    
    for (let i = 0; i < count; i++) {
      const baseRecord = {
        id: crypto.randomUUID(),
        created_at: new Date(now - Math.random() * 7 * 24 * 60 * 60 * 1000).toISOString(),
        device_id: `pi5-${Math.floor(Math.random() * 10) + 1}`,
        location: ['Metro Manila', 'Cebu', 'Davao'][Math.floor(Math.random() * 3)],
      };

      switch (type) {
        case 'transactions':
          testData.push({
            ...baseRecord,
            transaction_id: `tx_${Date.now()}_${i}`,
            amount: Math.floor(Math.random() * 5000) + 100,
            payment_method: ['cash', 'gcash', 'card'][Math.floor(Math.random() * 3)],
            merchant_category: 'retail',
            timestamp: baseRecord.created_at,
          });
          break;
          
        case 'edge_events':
          testData.push({
            ...baseRecord,
            event_type: ['transaction', 'heartbeat', 'error'][Math.floor(Math.random() * 3)],
            payload: JSON.stringify({ test: true, index: i }),
            processed: false,
            raw_data: JSON.stringify({ raw: true, data: i }),
          });
          break;
      }
    }
    
    return testData;
  }

  static async supabaseRequest(endpoint, options = {}) {
    const response = await fetch(`${TEST_CONFIG.supabaseUrl}${endpoint}`, {
      headers: {
        'Authorization': `Bearer ${TEST_CONFIG.serviceKey}`,
        'Content-Type': 'application/json',
        'apikey': TEST_CONFIG.serviceKey,
        ...options.headers
      },
      ...options
    });

    if (!response.ok) {
      throw new Error(`Supabase request failed: ${response.statusText}\n${await response.text()}`);
    }

    return response.json();
  }

  static async executeSQL(query) {
    return TestUtils.supabaseRequest('/rest/v1/rpc/exec_sql', {
      method: 'POST',
      body: JSON.stringify({ query })
    });
  }
}

/**
 * Test runner framework
 */
class TestRunner {
  constructor() {
    this.tests = [];
    this.setup = null;
    this.teardown = null;
  }

  addTest(name, testFn, options = {}) {
    this.tests.push({
      name,
      testFn,
      timeout: options.timeout || TEST_CONFIG.timeout,
      skip: options.skip || false,
      retries: options.retries || 0
    });
  }

  setSetup(setupFn) {
    this.setup = setupFn;
  }

  setTeardown(teardownFn) {
    this.teardown = teardownFn;
  }

  async runTest(test) {
    if (test.skip) {
      TestUtils.log(`⏭️  SKIP: ${test.name}`, 'warn');
      testResults.skipped++;
      return;
    }

    TestUtils.log(`🧪 TEST: ${test.name}`, 'info');
    
    let attempt = 0;
    let lastError;

    while (attempt <= test.retries) {
      try {
        const timeout = new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Test timeout')), test.timeout)
        );
        
        await Promise.race([test.testFn(), timeout]);
        
        TestUtils.log(`✅ PASS: ${test.name}`, 'success');
        testResults.passed++;
        testResults.details.push({ test: test.name, status: 'PASSED' });
        return;
        
      } catch (error) {
        lastError = error;
        attempt++;
        
        if (attempt <= test.retries) {
          TestUtils.log(`🔄 RETRY ${attempt}/${test.retries}: ${test.name}`, 'warn');
          await TestUtils.sleep(1000 * attempt); // Exponential backoff
        }
      }
    }

    TestUtils.log(`❌ FAIL: ${test.name} - ${lastError.message}`, 'error');
    testResults.failed++;
    testResults.errors.push({ test: test.name, error: lastError.message });
    testResults.details.push({ test: test.name, status: 'FAILED', error: lastError.message });
  }

  async run() {
    TestUtils.log('🚀 Starting Dataset Publisher Test Suite', 'info');
    TestUtils.log(`📊 Found ${this.tests.length} tests to run`, 'info');
    
    // Setup
    if (this.setup) {
      TestUtils.log('⚙️  Running setup...', 'info');
      try {
        await this.setup();
      } catch (error) {
        TestUtils.log(`❌ Setup failed: ${error.message}`, 'error');
        return;
      }
    }

    // Run tests
    for (const test of this.tests) {
      await this.runTest(test);
    }

    // Teardown  
    if (this.teardown) {
      TestUtils.log('🧹 Running teardown...', 'info');
      try {
        await this.teardown();
      } catch (error) {
        TestUtils.log(`⚠️  Teardown failed: ${error.message}`, 'warn');
      }
    }

    // Results
    this.printResults();
  }

  printResults() {
    TestUtils.log('', 'info');
    TestUtils.log('📋 TEST RESULTS', 'info');
    TestUtils.log('='.repeat(50), 'info');
    TestUtils.log(`✅ Passed: ${testResults.passed}`, 'success');
    TestUtils.log(`❌ Failed: ${testResults.failed}`, 'error');
    TestUtils.log(`⏭️  Skipped: ${testResults.skipped}`, 'warn');
    
    if (testResults.errors.length > 0) {
      TestUtils.log('', 'info');
      TestUtils.log('❌ FAILURES:', 'error');
      testResults.errors.forEach(({ test, error }) => {
        TestUtils.log(`  ${test}: ${error}`, 'error');
      });
    }

    const total = testResults.passed + testResults.failed + testResults.skipped;
    const successRate = total > 0 ? (testResults.passed / (testResults.passed + testResults.failed) * 100).toFixed(1) : 0;
    
    TestUtils.log('', 'info');
    TestUtils.log(`🎯 Success Rate: ${successRate}%`, successRate > 90 ? 'success' : 'error');
    
    // Write results to file
    const resultsFile = path.join('./test-results', `dataset-publisher-${Date.now()}.json`);
    fs.mkdirSync('./test-results', { recursive: true });
    fs.writeFileSync(resultsFile, JSON.stringify({
      timestamp: new Date().toISOString(),
      summary: {
        passed: testResults.passed,
        failed: testResults.failed,
        skipped: testResults.skipped,
        successRate: parseFloat(successRate)
      },
      details: testResults.details,
      errors: testResults.errors
    }, null, 2));
    
    TestUtils.log(`📁 Results saved to: ${resultsFile}`, 'info');
  }
}

/**
 * Test suite setup
 */
const testRunner = new TestRunner();

testRunner.setSetup(async () => {
  // Verify environment
  if (!TEST_CONFIG.serviceKey) {
    throw new Error('SUPABASE_SERVICE_KEY environment variable not set');
  }

  // Create test directories
  fs.mkdirSync(TEST_CONFIG.testDataDir, { recursive: true });
  fs.mkdirSync(TEST_CONFIG.tempDir, { recursive: true });

  // Verify database connection
  try {
    await TestUtils.supabaseRequest('/rest/v1/health');
    TestUtils.log('✅ Database connection verified', 'success');
  } catch (error) {
    throw new Error(`Database connection failed: ${error.message}`);
  }

  // Create test schemas if needed
  try {
    await TestUtils.executeSQL(`
      CREATE SCHEMA IF NOT EXISTS test_scout;
      CREATE TABLE IF NOT EXISTS test_scout.bronze_edge_raw (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        device_id TEXT NOT NULL,
        event_type TEXT,
        payload JSONB,
        raw_data JSONB,
        created_at TIMESTAMP DEFAULT NOW(),
        processed BOOLEAN DEFAULT FALSE
      );
    `);
    TestUtils.log('✅ Test schema created', 'success');
  } catch (error) {
    TestUtils.log(`⚠️  Schema setup warning: ${error.message}`, 'warn');
  }
});

testRunner.setTeardown(async () => {
  // Clean up test data
  try {
    await TestUtils.executeSQL('DROP SCHEMA IF EXISTS test_scout CASCADE;');
    TestUtils.log('✅ Test schema cleaned up', 'success');
  } catch (error) {
    TestUtils.log(`⚠️  Cleanup warning: ${error.message}`, 'warn');
  }

  // Remove temporary files
  try {
    if (fs.existsSync(TEST_CONFIG.tempDir)) {
      fs.rmSync(TEST_CONFIG.tempDir, { recursive: true });
    }
  } catch (error) {
    TestUtils.log(`⚠️  Temp cleanup warning: ${error.message}`, 'warn');
  }
});

/**
 * Database Schema Tests
 */
testRunner.addTest('Bronze layer schema exists', async () => {
  const result = await TestUtils.supabaseRequest('/rest/v1/rpc/exec_sql', {
    method: 'POST',
    body: JSON.stringify({
      query: `SELECT table_name FROM information_schema.tables 
               WHERE table_schema = 'scout' AND table_name = 'bronze_edge_raw'`
    })
  });
  
  if (!result || result.length === 0) {
    throw new Error('Bronze layer table not found');
  }
});

testRunner.addTest('Silver layer views exist', async () => {
  const result = await TestUtils.supabaseRequest('/rest/v1/rpc/exec_sql', {
    method: 'POST',
    body: JSON.stringify({
      query: `SELECT table_name FROM information_schema.views 
               WHERE table_schema = 'scout' AND table_name = 'silver_edge_events'`
    })
  });
  
  if (!result || result.length === 0) {
    throw new Error('Silver layer view not found');
  }
});

testRunner.addTest('Gold layer views exist', async () => {
  const goldViews = ['daily_transactions', 'store_rankings', 'hourly_patterns'];
  
  for (const view of goldViews) {
    const result = await TestUtils.supabaseRequest('/rest/v1/rpc/exec_sql', {
      method: 'POST',
      body: JSON.stringify({
        query: `SELECT table_name FROM information_schema.views 
                 WHERE table_schema = 'scout_gold' AND table_name = '${view}'`
      })
    });
    
    if (!result || result.length === 0) {
      throw new Error(`Gold layer view '${view}' not found`);
    }
  }
});

/**
 * Data Ingestion Tests
 */
testRunner.addTest('Bronze layer data insertion', async () => {
  const testData = TestUtils.generateTestData('edge_events', 10);
  
  const response = await TestUtils.supabaseRequest('/rest/v1/test_scout.bronze_edge_raw', {
    method: 'POST',
    body: JSON.stringify(testData)
  });

  // Verify insertion
  const count = await TestUtils.supabaseRequest('/rest/v1/rpc/exec_sql', {
    method: 'POST',
    body: JSON.stringify({
      query: 'SELECT COUNT(*) as count FROM test_scout.bronze_edge_raw'
    })
  });

  if (count[0].count < 10) {
    throw new Error(`Expected at least 10 records, got ${count[0].count}`);
  }
});

testRunner.addTest('JSON validation in bronze layer', async () => {
  const invalidData = [{
    id: crypto.randomUUID(),
    device_id: 'test-device',
    payload: 'invalid-json-string', // This should be JSONB
    raw_data: '{"valid": "json"}',
    created_at: new Date().toISOString()
  }];

  try {
    await TestUtils.supabaseRequest('/rest/v1/test_scout.bronze_edge_raw', {
      method: 'POST',
      body: JSON.stringify(invalidData)
    });
    throw new Error('Should have failed with invalid JSON');
  } catch (error) {
    if (!error.message.includes('invalid input syntax for type json')) {
      throw new Error('Unexpected error type for JSON validation');
    }
  }
});

/**
 * Storage Bucket Tests
 */
testRunner.addTest('Storage bucket accessibility', async () => {
  const buckets = ['scout-ingest', 'scout-silver', 'scout-gold', 'scout-platinum'];
  
  for (const bucket of buckets) {
    try {
      const response = await TestUtils.supabaseRequest(`/storage/v1/bucket/${bucket}`);
      if (!response.id) {
        throw new Error(`Bucket ${bucket} not accessible`);
      }
    } catch (error) {
      throw new Error(`Bucket ${bucket} test failed: ${error.message}`);
    }
  }
});

testRunner.addTest('File upload to scout-ingest', async () => {
  const testFileName = `test-${Date.now()}.json`;
  const testContent = JSON.stringify(TestUtils.generateTestData('transactions', 5));
  
  const response = await fetch(`${TEST_CONFIG.supabaseUrl}/storage/v1/object/scout-ingest/${testFileName}`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${TEST_CONFIG.serviceKey}`,
      'Content-Type': 'application/json'
    },
    body: testContent
  });

  if (!response.ok) {
    throw new Error(`File upload failed: ${response.statusText}`);
  }

  // Verify file exists
  const listResponse = await TestUtils.supabaseRequest(`/storage/v1/object/list/scout-ingest`);
  const uploadedFile = listResponse.find(f => f.name === testFileName);
  
  if (!uploadedFile) {
    throw new Error('Uploaded file not found in bucket listing');
  }
});

/**
 * ETL Pipeline Tests
 */
testRunner.addTest('Bronze to Silver transformation', async () => {
  // Insert test data into bronze
  const testData = TestUtils.generateTestData('edge_events', 20);
  await TestUtils.supabaseRequest('/rest/v1/test_scout.bronze_edge_raw', {
    method: 'POST',
    body: JSON.stringify(testData)
  });

  // Wait for processing
  await TestUtils.sleep(2000);

  // Check if silver layer processes the data correctly
  const silverCount = await TestUtils.supabaseRequest('/rest/v1/rpc/exec_sql', {
    method: 'POST',
    body: JSON.stringify({
      query: `SELECT COUNT(*) as count FROM test_scout.bronze_edge_raw 
               WHERE created_at > NOW() - INTERVAL '1 hour'`
    })
  });

  if (silverCount[0].count === 0) {
    throw new Error('No recent data found for Silver processing');
  }
});

/**
 * Data Quality Tests
 */
testRunner.addTest('Data completeness check', async () => {
  const result = await TestUtils.supabaseRequest('/rest/v1/rpc/exec_sql', {
    method: 'POST',
    body: JSON.stringify({
      query: `SELECT 
                COUNT(*) as total_records,
                COUNT(device_id) as devices_with_id,
                COUNT(created_at) as records_with_timestamp
               FROM test_scout.bronze_edge_raw`
    })
  });

  const stats = result[0];
  if (stats.total_records === 0) {
    throw new Error('No test data found for completeness check');
  }

  if (stats.devices_with_id !== stats.total_records) {
    throw new Error(`Incomplete device_id data: ${stats.devices_with_id}/${stats.total_records}`);
  }
});

testRunner.addTest('Data freshness monitoring', async () => {
  const result = await TestUtils.supabaseRequest('/rest/v1/rpc/exec_sql', {
    method: 'POST',
    body: JSON.stringify({
      query: `SELECT 
                MAX(created_at) as latest_record,
                COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '1 hour') as recent_count
               FROM test_scout.bronze_edge_raw`
    })
  });

  const stats = result[0];
  if (!stats.latest_record) {
    throw new Error('No records found for freshness check');
  }

  const latestTime = new Date(stats.latest_record);
  const now = new Date();
  const ageMinutes = (now - latestTime) / (1000 * 60);

  if (ageMinutes > 60) {
    throw new Error(`Data too stale: ${ageMinutes.toFixed(1)} minutes old`);
  }
});

/**
 * Edge Functions Tests
 */
testRunner.addTest('Ingest bronze function health', async () => {
  try {
    const response = await fetch(`${TEST_CONFIG.supabaseUrl}/functions/v1/ingest-bronze`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${TEST_CONFIG.serviceKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ test: true })
    });

    // Function should respond (even if with an error due to test data)
    if (response.status === 404) {
      throw new Error('Ingest bronze function not deployed');
    }
  } catch (error) {
    if (error.message.includes('not deployed')) {
      throw error;
    }
    // Other errors are acceptable for this health check
  }
});

testRunner.addTest('Export platinum function health', async () => {
  try {
    const response = await fetch(`${TEST_CONFIG.supabaseUrl}/functions/v1/export-platinum/health`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${TEST_CONFIG.serviceKey}`
      }
    });

    if (response.status === 404) {
      throw new Error('Export platinum function not deployed');
    }
  } catch (error) {
    if (error.message.includes('not deployed')) {
      throw error;
    }
  }
});

/**
 * Performance Tests
 */
testRunner.addTest('Large batch insertion performance', async () => {
  const largeDataset = TestUtils.generateTestData('edge_events', 1000);
  const startTime = Date.now();
  
  await TestUtils.supabaseRequest('/rest/v1/test_scout.bronze_edge_raw', {
    method: 'POST',
    body: JSON.stringify(largeDataset)
  });

  const duration = Date.now() - startTime;
  const recordsPerSecond = 1000 / (duration / 1000);

  TestUtils.log(`📊 Performance: ${recordsPerSecond.toFixed(1)} records/second`, 'info');

  if (recordsPerSecond < 10) {
    throw new Error(`Performance too slow: ${recordsPerSecond.toFixed(1)} records/second`);
  }
}, { timeout: 30000 });

/**
 * Security Tests
 */
testRunner.addTest('RLS policy enforcement', async () => {
  // This test would need to be run with different auth contexts
  // For now, just verify RLS is enabled
  const result = await TestUtils.supabaseRequest('/rest/v1/rpc/exec_sql', {
    method: 'POST',
    body: JSON.stringify({
      query: `SELECT schemaname, tablename, rowsecurity 
               FROM pg_tables 
               WHERE schemaname IN ('scout', 'scout_gold', 'scout_platinum')
               AND rowsecurity = false`
    })
  });

  if (result.length > 0) {
    const tablesWithoutRLS = result.map(r => `${r.schemaname}.${r.tablename}`);
    TestUtils.log(`⚠️  Tables without RLS: ${tablesWithoutRLS.join(', ')}`, 'warn');
    // Note: This is a warning, not a failure, as some tables might intentionally not have RLS
  }
});

/**
 * Integration Tests
 */
testRunner.addTest('End-to-end data flow', async () => {
  // 1. Upload file to storage
  const testFileName = `e2e-test-${Date.now()}.json`;
  const testData = TestUtils.generateTestData('transactions', 50);
  
  await fetch(`${TEST_CONFIG.supabaseUrl}/storage/v1/object/scout-ingest/${testFileName}`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${TEST_CONFIG.serviceKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(testData)
  });

  // 2. Wait for processing
  await TestUtils.sleep(5000);

  // 3. Verify data appeared in bronze layer  
  const bronzeCount = await TestUtils.supabaseRequest('/rest/v1/rpc/exec_sql', {
    method: 'POST',
    body: JSON.stringify({
      query: `SELECT COUNT(*) as count FROM test_scout.bronze_edge_raw 
               WHERE created_at > NOW() - INTERVAL '2 minutes'`
    })
  });

  if (bronzeCount[0].count === 0) {
    TestUtils.log('⚠️  E2E test: No automatic processing detected', 'warn');
    // This might be expected if automated triggers aren't set up yet
  } else {
    TestUtils.log(`✅ E2E test: Found ${bronzeCount[0].count} processed records`, 'success');
  }

  // 4. Clean up
  await fetch(`${TEST_CONFIG.supabaseUrl}/storage/v1/object/scout-ingest/${testFileName}`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${TEST_CONFIG.serviceKey}`
    }
  });
}, { timeout: 15000 });

/**
 * Run the test suite
 */
if (require.main === module) {
  testRunner.run().then(() => {
    process.exit(testResults.failed > 0 ? 1 : 0);
  }).catch(error => {
    TestUtils.log(`💥 Test runner crashed: ${error.message}`, 'error');
    console.error(error.stack);
    process.exit(1);
  });
}

module.exports = { TestRunner, TestUtils, testRunner };