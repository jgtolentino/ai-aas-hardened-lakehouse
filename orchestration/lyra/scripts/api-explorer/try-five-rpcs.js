#!/usr/bin/env node
/**
 * W6: API Explorer - Test 5 RPCs to ensure they succeed live
 */

console.log('🧪 Testing 5 RPCs for API Explorer validation...');

async function testRPCs() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  const userJWT = process.env.USER_JWT;
  const tenantId = process.env.TENANT_ID || 'test-tenant';
  
  if (!supabaseUrl || !anonKey || !userJWT) {
    throw new Error('Missing required environment variables');
  }
  
  // First, get the API catalog
  const apiExplorerUrl = `${supabaseUrl}/functions/v1/api-explorer`;
  
  console.log('📋 Fetching API catalog...');
  const catalogResponse = await fetch(apiExplorerUrl, {
    headers: {
      'Authorization': `Bearer ${userJWT}`,
      'X-Tenant-Id': tenantId
    }
  });
  
  if (!catalogResponse.ok) {
    throw new Error(`Failed to fetch API catalog: ${catalogResponse.status}`);
  }
  
  const catalog = await catalogResponse.json();
  console.log(`📊 Found ${catalog.functions.length} functions to test`);
  
  // Select 5 functions to test (or all if fewer than 5)
  const functionsToTest = catalog.functions.slice(0, 5);
  const testResults = [];
  
  for (const func of functionsToTest) {
    console.log(`🔍 Testing RPC: ${func.name}`);
    
    try {
      // Test via API Explorer's test endpoint
      const testUrl = `${apiExplorerUrl}?action=test&endpoint=${func.name}&params={}`;
      
      const testResponse = await fetch(testUrl, {
        headers: {
          'Authorization': `Bearer ${userJWT}`,
          'X-Tenant-Id': tenantId
        }
      });
      
      const testResult = await testResponse.json();
      
      if (testResult.test_result.success) {
        console.log(`✅ ${func.name}: SUCCESS (${testResult.test_result.response_time_ms}ms)`);
        testResults.push({
          function_name: func.name,
          status: 'SUCCESS',
          response_time_ms: testResult.test_result.response_time_ms,
          result_preview: testResult.test_result.result_preview
        });
      } else {
        console.log(`❌ ${func.name}: FAILED - ${testResult.test_result.error}`);
        testResults.push({
          function_name: func.name,
          status: 'FAILED',
          error: testResult.test_result.error,
          postgrest_code: testResult.test_result.postgrest_code,
          postgrest_details: testResult.test_result.postgrest_details
        });
      }
      
    } catch (error) {
      console.log(`❌ ${func.name}: ERROR - ${error.message}`);
      testResults.push({
        function_name: func.name,
        status: 'ERROR',
        error: error.message
      });
    }
  }
  
  // Generate test summary
  const successCount = testResults.filter(r => r.status === 'SUCCESS').length;
  const totalCount = testResults.length;
  const successRate = totalCount > 0 ? (successCount / totalCount * 100) : 0;
  
  console.log(`\n📋 RPC Test Summary:`);
  console.log(`   ✅ Successful: ${successCount}/${totalCount} (${successRate.toFixed(1)}%)`);
  console.log(`   ❌ Failed: ${totalCount - successCount}/${totalCount}`);
  
  // Save test report
  const report = {
    timestamp: new Date().toISOString(),
    catalog_summary: catalog.summary,
    test_results: testResults,
    summary: {
      total_tested: totalCount,
      successful: successCount,
      failed: totalCount - successCount,
      success_rate: successRate
    }
  };
  
  const fs = await import('fs');
  const reportPath = './orchestration/lyra/artifacts/rpc-test-report.json';
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`📄 Test report saved: ${reportPath}`);
  
  // Gate condition: At least 5 RPCs must succeed (or all if fewer than 5 available)
  const REQUIRED_SUCCESS_COUNT = Math.min(5, totalCount);
  if (successCount >= REQUIRED_SUCCESS_COUNT) {
    console.log(`✅ RPC testing PASSED (${successCount} >= ${REQUIRED_SUCCESS_COUNT})`);
    return true;
  } else {
    console.log(`❌ RPC testing FAILED (${successCount} < ${REQUIRED_SUCCESS_COUNT})`);
    return false;
  }
}

// Main execution
testRPCs()
  .then(success => {
    process.exit(success ? 0 : 1);
  })
  .catch(error => {
    console.error('❌ RPC testing failed:', error.message);
    process.exit(1);
  });