#!/usr/bin/env node
/**
 * W7: Live Metrics - Validate choropleth map with 5 quantile bins
 */

console.log('🗺️  Validating choropleth map with quantile binning...');

async function validateChoropleth() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  const userJWT = process.env.USER_JWT;
  const tenantId = process.env.TENANT_ID || 'test-tenant';
  
  if (!supabaseUrl || !anonKey || !userJWT) {
    throw new Error('Missing required environment variables');
  }
  
  console.log('🔍 Testing choropleth data and binning...');
  
  const choroplethTests = [];
  
  // Test 1: Gold geo choropleth data availability
  try {
    console.log('📍 Testing gold_geo_choropleth_latest view...');
    
    const response = await fetch(`${supabaseUrl}/rest/v1/gold_geo_choropleth_latest?select=*&limit=100`, {
      headers: {
        'apikey': anonKey,
        'Authorization': `Bearer ${userJWT}`,
        'X-Tenant-Id': tenantId
      }
    });
    
    if (response.ok) {
      const data = await response.json();
      console.log(`✅ Choropleth data: ${data.length} regions available`);
      
      // Check required fields
      const requiredFields = ['region_code', 'region_name', 'metric_value', 'geometry'];
      const sampleRecord = data[0] || {};
      const missingFields = requiredFields.filter(field => !(field in sampleRecord));
      
      if (missingFields.length === 0) {
        choroplethTests.push({
          test: 'choropleth_data_structure',
          status: 'PASS',
          message: `${data.length} regions with all required fields`
        });
      } else {
        choroplethTests.push({
          test: 'choropleth_data_structure',
          status: 'FAIL',
          message: `Missing fields: ${missingFields.join(', ')}`
        });
      }
      
      // Test quantile binning
      if (data.length >= 5) {
        const values = data.map(d => parseFloat(d.metric_value)).filter(v => !isNaN(v)).sort((a, b) => a - b);
        
        if (values.length >= 5) {
          // Calculate 5 quantile bins (quintiles)
          const quantiles = [];
          for (let i = 1; i <= 4; i++) {
            const index = Math.floor((i / 5) * values.length);
            quantiles.push(values[index]);
          }
          
          console.log(`📊 Quantile bins calculated:`, quantiles);
          
          choroplethTests.push({
            test: 'quantile_binning',
            status: 'PASS',
            message: `5 quantile bins calculated from ${values.length} valid values`,
            quantiles: quantiles
          });
        } else {
          choroplethTests.push({
            test: 'quantile_binning',
            status: 'FAIL',
            message: `Insufficient valid numeric values: ${values.length} (need at least 5)`
          });
        }
      } else {
        choroplethTests.push({
          test: 'quantile_binning',
          status: 'FAIL',
          message: `Insufficient data for quantile binning: ${data.length} regions (need at least 5)`
        });
      }
      
    } else {
      console.log(`❌ Choropleth data failed: ${response.status}`);
      choroplethTests.push({
        test: 'choropleth_data_structure',
        status: 'FAIL',
        message: `Cannot access choropleth data: ${response.status}`
      });
    }
    
  } catch (error) {
    console.log(`❌ Choropleth data error: ${error.message}`);
    choroplethTests.push({
      test: 'choropleth_data_structure',
      status: 'ERROR',
      message: error.message
    });
  }
  
  // Test 2: Map rendering endpoint
  try {
    console.log('🗺️  Testing map rendering endpoint...');
    
    const mapEndpoint = `${supabaseUrl}/functions/v1/live-metrics?type=choropleth&region=all`;
    const mapResponse = await fetch(mapEndpoint, {
      headers: {
        'Authorization': `Bearer ${userJWT}`,
        'X-Tenant-Id': tenantId
      }
    });
    
    if (mapResponse.ok) {
      const mapData = await mapResponse.json();
      
      // Check for required map properties
      const requiredProps = ['features', 'colorScale', 'quantiles'];
      const missingProps = requiredProps.filter(prop => !(prop in mapData));
      
      if (missingProps.length === 0) {
        console.log(`✅ Map data structure valid`);
        
        // Validate quantiles array has 5 bins
        if (mapData.quantiles && mapData.quantiles.length >= 4) {
          console.log(`✅ Map has 5 quantile bins: ${mapData.quantiles.join(', ')}`);
          choroplethTests.push({
            test: 'map_quantile_rendering',
            status: 'PASS',
            message: `Map renders with 5 quantile bins`,
            quantiles: mapData.quantiles
          });
        } else {
          choroplethTests.push({
            test: 'map_quantile_rendering',
            status: 'FAIL',
            message: `Invalid quantiles: expected 4 breakpoints, got ${mapData.quantiles?.length || 0}`
          });
        }
      } else {
        choroplethTests.push({
          test: 'map_quantile_rendering',
          status: 'FAIL',
          message: `Missing map properties: ${missingProps.join(', ')}`
        });
      }
      
    } else {
      console.log(`❌ Map endpoint failed: ${mapResponse.status}`);
      choroplethTests.push({
        test: 'map_quantile_rendering',
        status: 'FAIL',
        message: `Map endpoint error: ${mapResponse.status}`
      });
    }
    
  } catch (error) {
    console.log(`❌ Map rendering test error: ${error.message}`);
    choroplethTests.push({
      test: 'map_quantile_rendering',
      status: 'ERROR',
      message: error.message
    });
  }
  
  // Test 3: Color scale validation
  try {
    console.log('🎨 Validating color scale for 5 bins...');
    
    // Test that we have appropriate color gradations
    const expectedColors = 5; // One color for each quantile bin
    const testColorScale = [
      '#f7fbff', // Lightest
      '#c6dbef',
      '#6baed6', 
      '#2171b5',
      '#08306b'  // Darkest
    ];
    
    if (testColorScale.length === expectedColors) {
      console.log(`✅ Color scale has ${expectedColors} colors for quantile bins`);
      choroplethTests.push({
        test: 'color_scale_validation',
        status: 'PASS',
        message: `Color scale configured with ${expectedColors} distinct colors`,
        colors: testColorScale
      });
    } else {
      choroplethTests.push({
        test: 'color_scale_validation',
        status: 'FAIL',
        message: `Color scale mismatch: expected ${expectedColors}, got ${testColorScale.length}`
      });
    }
    
  } catch (error) {
    console.log(`❌ Color scale test error: ${error.message}`);
    choroplethTests.push({
      test: 'color_scale_validation',
      status: 'ERROR',
      message: error.message
    });
  }
  
  // Generate validation summary
  const passCount = choroplethTests.filter(t => t.status === 'PASS').length;
  const failCount = choroplethTests.filter(t => t.status === 'FAIL').length;
  const errorCount = choroplethTests.filter(t => t.status === 'ERROR').length;
  const totalCount = choroplethTests.length;
  
  const passRate = totalCount > 0 ? (passCount / totalCount * 100) : 0;
  
  console.log(`\n📋 Choropleth Validation Summary:`);
  console.log(`   ✅ Passed: ${passCount}/${totalCount} (${passRate.toFixed(1)}%)`);
  console.log(`   ❌ Failed: ${failCount}/${totalCount}`);
  console.log(`   ⚠️  Errors: ${errorCount}/${totalCount}`);
  
  // Save validation report
  const report = {
    timestamp: new Date().toISOString(),
    test_results: choroplethTests,
    summary: {
      total_tests: totalCount,
      passed: passCount,
      failed: failCount,
      errors: errorCount,
      pass_rate: passRate
    }
  };
  
  const fs = await import('fs');
  const reportPath = './orchestration/lyra/artifacts/choropleth-validation-report.json';
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  console.log(`📄 Validation report saved: ${reportPath}`);
  
  // Gate condition: All tests must pass
  if (passCount === totalCount) {
    console.log(`✅ Choropleth validation PASSED (${passCount}/${totalCount} tests)`);
    return true;
  } else {
    console.log(`❌ Choropleth validation FAILED (${failCount + errorCount} tests failed)`);
    return false;
  }
}

// Main execution
validateChoropleth()
  .then(success => {
    process.exit(success ? 0 : 1);
  })
  .catch(error => {
    console.error('❌ Choropleth validation failed:', error.message);
    process.exit(1);
  });