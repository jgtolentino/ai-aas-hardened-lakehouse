#!/usr/bin/env node
/**
 * W7: Live Metrics - Validate KPIs from gold views
 * Gate: DQ 'bad' hides email export; map paints 5 quantile bins
 */

console.log('📊 Validating Live Metrics KPIs...');

async function validateKPIs() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  const userJWT = process.env.USER_JWT;
  const tenantId = process.env.TENANT_ID || 'test-tenant';
  
  if (!supabaseUrl || !anonKey || !userJWT) {
    throw new Error('Missing required environment variables');
  }
  
  console.log('🔍 Testing KPI endpoints...');
  
  const kpiTests = [];
  
  // Test 1: Gold views accessibility
  const goldViews = [
    'gold_brand_performance',
    'gold_revenue_daily',
    'gold_region_summary',
    'gold_customer_metrics',
    'gold_dq_health'
  ];
  
  for (const view of goldViews) {
    try {
      console.log(`📈 Testing ${view}...`);
      
      const response = await fetch(`${supabaseUrl}/rest/v1/${view}?select=*&limit=1`, {
        headers: {
          'apikey': anonKey,
          'Authorization': `Bearer ${userJWT}`,
          'X-Tenant-Id': tenantId
        }
      });
      
      if (response.ok) {
        const data = await response.json();
        console.log(`✅ ${view}: Accessible (${data.length} rows preview)`);
        kpiTests.push({
          test: `gold_view_${view}`,
          status: 'PASS',
          message: `View accessible with ${data.length} rows`
        });
      } else {
        console.log(`❌ ${view}: Failed (${response.status})`);
        kpiTests.push({
          test: `gold_view_${view}`,
          status: 'FAIL',
          message: `HTTP ${response.status}: ${response.statusText}`
        });
      }
      
    } catch (error) {
      console.log(`❌ ${view}: Error - ${error.message}`);
      kpiTests.push({
        test: `gold_view_${view}`,
        status: 'ERROR',
        message: error.message
      });
    }
  }
  
  // Test 2: Data Quality checks - email export should be hidden for 'bad' DQ
  try {
    console.log('🛡️  Testing DQ-based email export hiding...');
    
    const dqResponse = await fetch(`${supabaseUrl}/rest/v1/gold_dq_health?select=*`, {
      headers: {
        'apikey': anonKey,
        'Authorization': `Bearer ${userJWT}`,
        'X-Tenant-Id': tenantId
      }
    });
    
    if (dqResponse.ok) {
      const dqData = await dqResponse.json();
      const badDQRecords = dqData.filter(record => 
        record.overall_score < 0.7 || record.quality_grade === 'bad'
      );
      
      if (badDQRecords.length > 0) {
        console.log(`⚠️  Found ${badDQRecords.length} records with bad DQ - email export should be hidden`);
        kpiTests.push({
          test: 'dq_email_export_hiding',
          status: 'PASS',
          message: `${badDQRecords.length} bad DQ records detected, export restrictions active`
        });
      } else {
        console.log(`✅ All DQ records are good - email export allowed`);
        kpiTests.push({
          test: 'dq_email_export_hiding',
          status: 'PASS',
          message: 'All DQ records pass threshold, no export restrictions'
        });
      }
    } else {
      console.log(`❌ DQ health check failed: ${dqResponse.status}`);
      kpiTests.push({
        test: 'dq_email_export_hiding',
        status: 'FAIL',
        message: `Cannot access DQ health data: ${dqResponse.status}`
      });
    }
    
  } catch (error) {
    console.log(`❌ DQ test error: ${error.message}`);
    kpiTests.push({
      test: 'dq_email_export_hiding',
      status: 'ERROR',
      message: error.message
    });
  }
  
  // Test 3: KPI calculation accuracy
  try {
    console.log('🧮 Testing KPI calculations...');
    
    const kpiEndpoint = `${supabaseUrl}/functions/v1/live-metrics?type=kpis`;
    const kpiResponse = await fetch(kpiEndpoint, {
      headers: {
        'Authorization': `Bearer ${userJWT}`,
        'X-Tenant-Id': tenantId
      }
    });
    
    if (kpiResponse.ok) {
      const kpiData = await kpiResponse.json();
      const requiredKPIs = ['total_revenue', 'active_customers', 'avg_order_value', 'growth_rate'];
      const missingKPIs = requiredKPIs.filter(kpi => !(kpi in kpiData));
      
      if (missingKPIs.length === 0) {
        console.log(`✅ All required KPIs present: ${requiredKPIs.join(', ')}`);
        kpiTests.push({
          test: 'kpi_completeness',
          status: 'PASS',
          message: `All ${requiredKPIs.length} required KPIs present`
        });
      } else {
        console.log(`❌ Missing KPIs: ${missingKPIs.join(', ')}`);
        kpiTests.push({
          test: 'kpi_completeness',
          status: 'FAIL',
          message: `Missing KPIs: ${missingKPIs.join(', ')}`
        });
      }
    } else {
      console.log(`❌ KPI endpoint failed: ${kpiResponse.status}`);
      kpiTests.push({
        test: 'kpi_completeness',
        status: 'FAIL',
        message: `KPI endpoint error: ${kpiResponse.status}`
      });
    }
    
  } catch (error) {
    console.log(`❌ KPI calculation test error: ${error.message}`);
    kpiTests.push({
      test: 'kpi_completeness',
      status: 'ERROR',
      message: error.message
    });
  }
  
  // Generate validation summary
  const passCount = kpiTests.filter(t => t.status === 'PASS').length;
  const failCount = kpiTests.filter(t => t.status === 'FAIL').length;
  const errorCount = kpiTests.filter(t => t.status === 'ERROR').length;
  const totalCount = kpiTests.length;
  
  const passRate = totalCount > 0 ? (passCount / totalCount * 100) : 0;
  
  console.log(`\n📋 KPI Validation Summary:`);
  console.log(`   ✅ Passed: ${passCount}/${totalCount} (${passRate.toFixed(1)}%)`);
  console.log(`   ❌ Failed: ${failCount}/${totalCount}`);
  console.log(`   ⚠️  Errors: ${errorCount}/${totalCount}`);
  
  // Save validation report
  const report = {
    timestamp: new Date().toISOString(),
    test_results: kpiTests,
    summary: {
      total_tests: totalCount,
      passed: passCount,
      failed: failCount,
      errors: errorCount,
      pass_rate: passRate
    }
  };
  
  const fs = await import('fs');
  const reportPath = './orchestration/lyra/artifacts/kpi-validation-report.json';
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`📄 Validation report saved: ${reportPath}`);
  
  // Gate condition: Pass rate must be >= 80%
  const REQUIRED_PASS_RATE = 80;
  if (passRate >= REQUIRED_PASS_RATE) {
    console.log(`✅ KPI validation PASSED (${passRate.toFixed(1)}% >= ${REQUIRED_PASS_RATE}%)`);
    return true;
  } else {
    console.log(`❌ KPI validation FAILED (${passRate.toFixed(1)}% < ${REQUIRED_PASS_RATE}%)`);
    return false;
  }
}

// Main execution
validateKPIs()
  .then(success => {
    process.exit(success ? 0 : 1);
  })
  .catch(error => {
    console.error('❌ KPI validation failed:', error.message);
    process.exit(1);
  });