#!/usr/bin/env tsx
/**
 * RPC + Edge smoke tests
 * Validates all Gold DAL operations and DQ health
 */
import { createClient } from "@supabase/supabase-js";

const URL = process.env.SUPABASE_URL ?? "";
const ANON = process.env.SUPABASE_ANON_KEY ?? "";
const JWT = process.env.USER_JWT ?? "";

function req(ok: boolean, msg: string) { if (!ok) throw new Error(msg); }
req(!!URL, "SUPABASE_URL missing");
req(!!ANON, "SUPABASE_ANON_KEY missing");

const supabase = createClient(URL, ANON, {
  global: { headers: { Authorization: `Bearer ${JWT || ANON}` } },
});

const green = (s:string)=>`\x1b[32m${s}\x1b[0m`;
const red   = (s:string)=>`\x1b[31m${s}\x1b[0m`;
const cyan  = (s:string)=>`\x1b[36m${s}\x1b[0m`;
const yellow= (s:string)=>`\x1b[33m${s}\x1b[0m`;

interface TestResult {
  name: string;
  status: 'PASS' | 'FAIL' | 'SKIP';
  message: string;
  data?: any;
}

const results: TestResult[] = [];

function test(name: string, fn: () => Promise<void>) {
  return async () => {
    try {
      await fn();
      results.push({ name, status: 'PASS', message: 'OK' });
      process.stdout.write(green('.'));
    } catch (error) {
      results.push({ name, status: 'FAIL', message: error.message });
      process.stdout.write(red('F'));
    }
  };
}

async function main() {
  console.log(cyan('Running RPC + Edge smoke tests...'));
  process.stdout.write('Progress: ');
  
  // Test 1: Gold transaction items
  await test('gold_txn_items_api', async () => {
    const { data, error } = await supabase
      .from('gold_txn_items_api')
      .select('*')
      .limit(5);
    if (error) throw error;
    if (!data || data.length === 0) throw new Error('No data returned');
  })();
  
  // Test 2: Gold sales day
  await test('gold_sales_day_api', async () => {
    const { data, error } = await supabase
      .from('gold_sales_day_api')
      .select('*')
      .limit(5);
    if (error) throw error;
    if (!data || data.length === 0) throw new Error('No data returned');
  })();
  
  // Test 3: Gold brand mix
  await test('gold_brand_mix_api', async () => {
    const { data, error } = await supabase
      .from('gold_brand_mix_api')
      .select('*')
      .limit(5);
    if (error) throw error;
    if (!data || data.length === 0) throw new Error('No data returned');
  })();
  
  // Test 4: Gold geo sales
  await test('gold_geo_sales_api', async () => {
    const { data, error } = await supabase
      .from('gold_geo_sales_api')
      .select('*')
      .limit(5);
    if (error) throw error;
    if (!data || data.length === 0) throw new Error('No data returned');
  })();
  
  // Test 5: DQ health summary
  await test('silver_dq_daily_summary_api', async () => {
    const { data, error } = await supabase
      .from('silver_dq_daily_summary_api')
      .select('*')
      .limit(5)
      .order('date', { ascending: false });
    if (error) throw error;
    if (!data || data.length === 0) throw new Error('No DQ data available');
    
    // Check that health index is reasonable
    const avgHealth = data.reduce((sum, row) => sum + (row.dq_health_index || 0), 0) / data.length;
    if (avgHealth < 50) throw new Error(`DQ health too low: ${avgHealth.toFixed(1)}`);
  })();
  
  // Test 6: DQ top issues
  await test('silver_dq_top_issues_api', async () => {
    const { data, error } = await supabase
      .from('silver_dq_top_issues_api')
      .select('*')
      .limit(10);
    if (error) throw error;
    // OK if no issues (good thing!)
  })();
  
  // Test 7: DQ health RPC
  await test('get_dq_health_rpc', async () => {
    const today = new Date().toISOString().split('T')[0];
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    
    const { data, error } = await supabase.rpc('get_dq_health', {
      p_date_from: weekAgo,
      p_date_to: today,
      p_store_id: null
    });
    if (error) throw error;
    if (!Array.isArray(data)) throw new Error('RPC returned non-array');
  })();
  
  // Test 8: Silver items view
  await test('silver_items_w_txn_store_api', async () => {
    const { data, error } = await supabase
      .from('silver_items_w_txn_store_api')
      .select('*')
      .limit(5);
    if (error) throw error;
    if (!data || data.length === 0) throw new Error('No Silver items found');
  })();
  
  // Test 9: Silver transactions
  await test('silver_transactions_api', async () => {
    const { data, error } = await supabase
      .from('silver_transactions_api')
      .select('*')
      .limit(5);
    if (error) throw error;
    if (!data || data.length === 0) throw new Error('No Silver transactions found');
  })();
  
  // Test 10: Data completeness check
  await test('data_completeness', async () => {
    const { count: silverCount } = await supabase
      .from('silver_txn_items_api')
      .select('*', { count: 'exact', head: true });
    
    const { count: goldCount } = await supabase
      .from('gold_txn_items_api')
      .select('*', { count: 'exact', head: true });
    
    if ((silverCount || 0) === 0) throw new Error('No Silver data');
    if ((goldCount || 0) === 0) throw new Error('No Gold data');
    
    const ratio = (goldCount || 0) / (silverCount || 1);
    if (ratio < 0.8) throw new Error(`Gold/Silver ratio too low: ${ratio.toFixed(2)}`);
  })();
  
  console.log('\n');
  
  // Print results
  const passed = results.filter(r => r.status === 'PASS').length;
  const failed = results.filter(r => r.status === 'FAIL').length;
  const total = results.length;
  
  console.log(cyan('\n📋 Test Results:'));
  console.log(cyan('================'));
  
  for (const result of results) {
    const status = result.status === 'PASS' 
      ? green('✓ PASS')
      : result.status === 'FAIL' 
        ? red('✗ FAIL') 
        : yellow('- SKIP');
    
    console.log(`${status} ${result.name}`);
    if (result.status === 'FAIL') {
      console.log(`      ${red(result.message)}`);
    }
  }
  
  console.log(cyan('\n📊 Summary:'));
  console.log(`Total: ${total}, Passed: ${green(passed.toString())}, Failed: ${failed > 0 ? red(failed.toString()) : '0'}`);
  
  if (failed > 0) {
    console.log(red('\n❌ Some tests failed - check configuration and data'));
    process.exit(1);
  } else {
    console.log(green('\n✅ All tests passed - Bronze→Silver→Gold pipeline is healthy'));
  }
}

main().catch(e => {
  console.error(red(`\nSmoke test crashed: ${e?.message || e}`));
  process.exit(1);
});