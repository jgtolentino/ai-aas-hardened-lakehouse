#!/usr/bin/env node
/**
 * Test Edge Function Integration
 * Tests both direct ingestion and storage-based loading
 */

const PROJECT_REF = 'cxzllzyxwpyptfretryc';
const BASE_URL = `https://${PROJECT_REF}.functions.supabase.co`;

// Test data
const testTransaction = {
  id: `TXN${Date.now()}`,
  store_id: '102',
  timestamp: new Date().toISOString(),
  location: {
    region: 'NCR',
    province: 'Metro Manila',
    city: 'Manila',
    barangay: 'Barangay 770'
  },
  product_category: 'beverages',
  brand_name: 'test-brand',
  sku: 'SKU123',
  units_per_transaction: 2,
  peso_value: 150.50,
  duration_seconds: 3,
  is_tbwa_client: true,
  campaign_influenced: false
};

async function testDirectIngestion() {
  console.log('📤 Testing direct JSON ingestion...');
  
  const response = await fetch(`${BASE_URL}/ingest-transaction`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-device-id': 'test-device-01'
    },
    body: JSON.stringify(testTransaction)
  });
  
  const result = await response.json();
  console.log('✅ Response:', result);
  return result;
}

async function testJSONLIngestion() {
  console.log('📤 Testing JSONL batch ingestion...');
  
  // Create JSONL data (3 transactions)
  const jsonl = [
    JSON.stringify({ ...testTransaction, id: `TXN${Date.now()}-1` }),
    JSON.stringify({ ...testTransaction, id: `TXN${Date.now()}-2`, peso_value: 200.00 }),
    JSON.stringify({ ...testTransaction, id: `TXN${Date.now()}-3`, peso_value: 75.25 })
  ].join('\n');
  
  const response = await fetch(`${BASE_URL}/ingest-transaction`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/jsonl',
      'x-device-id': 'test-device-02'
    },
    body: jsonl
  });
  
  const result = await response.json();
  console.log('✅ Response:', result);
  return result;
}

async function testStorageLoader() {
  console.log('📤 Testing storage loader function...');
  
  const today = new Date().toISOString().slice(0, 10);
  
  const response = await fetch(`${BASE_URL}/load-bronze-from-storage`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ date: today })
  });
  
  const result = await response.json();
  console.log('✅ Response:', result);
  return result;
}

async function runTests() {
  console.log('🧪 Starting Edge Function Tests');
  console.log('================================\n');
  
  try {
    // Test 1: Direct JSON
    await testDirectIngestion();
    console.log('');
    
    // Test 2: JSONL Batch
    await testJSONLIngestion();
    console.log('');
    
    // Test 3: Storage Loader
    await testStorageLoader();
    
    console.log('\n✅ All tests completed!');
    console.log('\n📊 Check data at:');
    console.log(`https://supabase.com/dashboard/project/${PROJECT_REF}/editor/scout_bronze.transactions_raw`);
    
  } catch (error) {
    console.error('❌ Test failed:', error);
    process.exit(1);
  }
}

// Run tests
runTests();