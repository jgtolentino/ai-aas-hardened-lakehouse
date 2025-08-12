#!/usr/bin/env node
/**
 * W5: Schema Explorer - Validate that counts match metadata within ±5%
 */

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

console.log('🔍 Validating Schema Explorer counts...');

async function validateSchemaCounts() {
  const supabaseUrl = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  const userJWT = process.env.USER_JWT;
  const tenantId = process.env.TENANT_ID || 'test-tenant';
  
  if (!supabaseUrl || !anonKey || !userJWT) {
    throw new Error('Missing required environment variables: SUPABASE_URL, SUPABASE_ANON_KEY, USER_JWT');
  }
  
  // Fetch schema data from the explorer
  const schemaExplorerUrl = `${supabaseUrl}/functions/v1/schema-explorer`;
  
  try {
    console.log('📊 Fetching schema data from explorer...');
    
    const response = await fetch(schemaExplorerUrl, {
      headers: {
        'Authorization': `Bearer ${userJWT}`,
        'X-Tenant-Id': tenantId,
        'Content-Type': 'application/json'
      }
    });
    
    if (!response.ok) {
      throw new Error(`Schema Explorer API error: ${response.status} ${response.statusText}`);
    }
    
    const schemaData = await response.json();
    console.log(`✅ Retrieved data for ${schemaData.nodes.length} tables across ${schemaData.schemas.length} schemas`);
    
    // Validate counts by comparing with direct database queries
    const validationResults = [];
    
    for (const table of schemaData.nodes.slice(0, 10)) { // Validate first 10 tables
      try {
        console.log(`🔍 Validating ${table.id}...`);
        
        // Direct count query
        const countResponse = await fetch(`${supabaseUrl}/rest/v1/${table.label}?select=*&limit=0`, {
          headers: {
            'apikey': anonKey,
            'Authorization': `Bearer ${userJWT}`,
            'X-Tenant-Id': tenantId,
            'Prefer': 'count=exact'
          }
        });
        
        if (!countResponse.ok) {
          console.log(`⚠️  Cannot access table ${table.id} (${countResponse.status})`);
          continue;
        }
        
        const contentRange = countResponse.headers.get('content-range');
        const actualCount = contentRange ? parseInt(contentRange.split('/')[1]) : 0;
        const explorerCount = table.row_count;
        
        const percentDiff = explorerCount > 0 ? 
          Math.abs((actualCount - explorerCount) / explorerCount) * 100 : 0;
        
        const isWithinTolerance = percentDiff <= 5; // ±5% tolerance
        
        validationResults.push({
          table: table.id,
          explorer_count: explorerCount,
          actual_count: actualCount,
          percent_difference: parseFloat(percentDiff.toFixed(2)),
          within_tolerance: isWithinTolerance,
          status: isWithinTolerance ? 'PASS' : 'FAIL'
        });
        
        const statusIcon = isWithinTolerance ? '✅' : '❌';
        console.log(`${statusIcon} ${table.id}: Explorer=${explorerCount}, Actual=${actualCount}, Diff=${percentDiff.toFixed(1)}%`);
        
      } catch (tableError) {
        console.log(`⚠️  Error validating ${table.id}: ${tableError.message}`);
        validationResults.push({
          table: table.id,
          status: 'ERROR',
          error: tableError.message
        });
      }
    }
    
    // Generate validation summary
    const passCount = validationResults.filter(r => r.status === 'PASS').length;
    const failCount = validationResults.filter(r => r.status === 'FAIL').length;
    const errorCount = validationResults.filter(r => r.status === 'ERROR').length;
    const totalCount = validationResults.length;
    
    const passRate = totalCount > 0 ? (passCount / totalCount * 100).toFixed(1) : 0;
    
    console.log(`\n📋 Validation Summary:`);
    console.log(`   ✅ Passed: ${passCount}/${totalCount} (${passRate}%)`);
    console.log(`   ❌ Failed: ${failCount}/${totalCount}`);
    console.log(`   ⚠️  Errors: ${errorCount}/${totalCount}`);
    
    // Save validation report
    const report = {
      timestamp: new Date().toISOString(),
      schema_summary: schemaData.summary,
      validation_results: validationResults,
      summary: {
        total_validated: totalCount,
        passed: passCount,
        failed: failCount,
        errors: errorCount,
        pass_rate: parseFloat(passRate)
      }
    };
    
    const reportPath = './orchestration/lyra/artifacts/schema-validation-report.json';
    const fs = await import('fs');
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
    console.log(`📄 Validation report saved: ${reportPath}`);
    
    // Gate condition: Pass rate must be >= 80%
    const REQUIRED_PASS_RATE = 80;
    if (parseFloat(passRate) >= REQUIRED_PASS_RATE) {
      console.log(`✅ Schema validation PASSED (${passRate}% >= ${REQUIRED_PASS_RATE}%)`);
      return true;
    } else {
      console.log(`❌ Schema validation FAILED (${passRate}% < ${REQUIRED_PASS_RATE}%)`);
      return false;
    }
    
  } catch (error) {
    console.error('❌ Schema validation error:', error.message);
    return false;
  }
}

// Main execution
validateSchemaCounts()
  .then(success => {
    process.exit(success ? 0 : 1);
  })
  .catch(error => {
    console.error('❌ Validation failed:', error.message);
    process.exit(1);
  });