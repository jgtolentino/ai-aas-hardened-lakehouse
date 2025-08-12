#!/usr/bin/env node

/**
 * Bronze Layer Verification Script
 * Verifies data flow from ZIP files → Bronze → Silver → Gold layers
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs').promises;
const path = require('path');

// Load environment variables
require('dotenv').config({ path: path.join(__dirname, '../.env.local') });

const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing Supabase credentials. Please check .env.local');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function verifyBronzeSchema() {
  console.log('\n📊 Verifying Bronze Layer Schema...');
  
  // Check for bronze tables
  const tables = [
    'scout.bronze_transactions',
    'scout.bronze_transaction_items',
    'scout.bronze_edge_raw',
    'scout.bronze_transactions_raw'
  ];
  
  for (const table of tables) {
    const { data, error } = await supabase
      .from(table.split('.')[1])
      .select('count')
      .limit(1);
    
    if (error) {
      console.log(`❌ Table ${table} not found or inaccessible`);
    } else {
      console.log(`✅ Table ${table} exists`);
    }
  }
}

async function checkBronzeData() {
  console.log('\n📈 Checking Bronze Layer Data...');
  
  // Check bronze_transactions
  const { data: txData, error: txError } = await supabase
    .from('bronze_transactions')
    .select('*', { count: 'exact', head: true });
  
  if (txError) {
    console.log('❌ Could not query bronze_transactions:', txError.message);
  } else {
    console.log(`✅ bronze_transactions: ${txData} records`);
  }
  
  // Check bronze_transaction_items
  const { data: itemData, error: itemError } = await supabase
    .from('bronze_transaction_items')
    .select('*', { count: 'exact', head: true });
  
  if (itemError) {
    console.log('❌ Could not query bronze_transaction_items:', itemError.message);
  } else {
    console.log(`✅ bronze_transaction_items: ${itemData} records`);
  }
}

async function verifySilverViews() {
  console.log('\n🥈 Verifying Silver Layer Views...');
  
  const views = [
    'silver_transactions_clean',
    'silver_transaction_items_clean',
    'silver_items_w_txn_store'
  ];
  
  for (const view of views) {
    const { data, error } = await supabase
      .from(view + '_api')
      .select('*')
      .limit(1);
    
    if (error) {
      console.log(`❌ View ${view} not accessible:`, error.message);
    } else {
      console.log(`✅ View ${view} accessible, sample record:`, data.length > 0 ? 'Found' : 'Empty');
    }
  }
}

async function verifyGoldViews() {
  console.log('\n🥇 Verifying Gold Layer Views...');
  
  const views = [
    'gold_txn_items_api',
    'gold_sales_day_api',
    'gold_brand_mix_api',
    'gold_geo_sales_api'
  ];
  
  for (const view of views) {
    const { data, error } = await supabase
      .from(view)
      .select('*')
      .limit(1);
    
    if (error) {
      console.log(`❌ View ${view} not accessible:`, error.message);
    } else {
      console.log(`✅ View ${view} accessible, sample record:`, data.length > 0 ? 'Found' : 'Empty');
    }
  }
}

async function verifyDQHealth() {
  console.log('\n📋 Verifying DQ Health Monitoring...');
  
  // Check DQ daily summary
  const { data: dqData, error: dqError } = await supabase
    .from('silver_dq_daily_summary_api')
    .select('*')
    .limit(5)
    .order('date', { ascending: false });
  
  if (dqError) {
    console.log('❌ DQ Health monitoring not accessible:', dqError.message);
  } else if (dqData && dqData.length > 0) {
    console.log('✅ DQ Health monitoring active:');
    dqData.forEach(row => {
      console.log(`   - ${row.date}: Health Index ${row.dq_health_index} (${row.dq_health_bucket})`);
    });
  } else {
    console.log('⚠️  DQ Health monitoring configured but no data yet');
  }
}

async function generateSampleData() {
  console.log('\n🔧 Generating Sample Bronze Data...');
  
  // Generate sample transactions
  const sampleTransactions = [];
  const stores = [1, 2, 3, 4, 5]; // Assuming store IDs 1-5 exist
  const devices = ['POS-001', 'POS-002', 'POS-003'];
  const paymentMethods = ['cash', 'gcash', 'card'];
  
  const baseDate = new Date('2025-08-01');
  
  for (let day = 0; day < 12; day++) {
    for (let txnCount = 0; txnCount < 50; txnCount++) {
      const txnDate = new Date(baseDate);
      txnDate.setDate(baseDate.getDate() + day);
      txnDate.setHours(Math.floor(Math.random() * 14) + 8); // 8 AM to 10 PM
      txnDate.setMinutes(Math.floor(Math.random() * 60));
      
      const txnId = `TXN-${txnDate.toISOString().split('T')[0]}-${String(txnCount).padStart(5, '0')}`;
      
      sampleTransactions.push({
        txn_id: txnId,
        device_id: devices[Math.floor(Math.random() * devices.length)],
        store_id: stores[Math.floor(Math.random() * stores.length)],
        txn_ts_utc: txnDate.toISOString(),
        tz_offset_min: 480, // Philippines UTC+8
        payment_method: paymentMethods[Math.floor(Math.random() * paymentMethods.length)],
        source: 'sample_generator',
        _ingest_batch_id: `BATCH-${txnDate.toISOString().split('T')[0]}`
      });
    }
  }
  
  console.log(`Generated ${sampleTransactions.length} sample transactions`);
  
  // Insert transactions
  const { error: txError } = await supabase
    .from('bronze_transactions')
    .upsert(sampleTransactions, { onConflict: 'txn_id' });
  
  if (txError) {
    console.log('❌ Failed to insert sample transactions:', txError.message);
    return;
  }
  
  console.log('✅ Sample transactions inserted successfully');
  
  // Generate sample transaction items
  const sampleItems = [];
  const products = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]; // Assuming product IDs 1-10
  const brands = [1, 2, 3]; // Assuming brand IDs 1-3
  const categories = [1, 2]; // Assuming category IDs 1-2
  const units = ['pc', 'kg', 'L', 'bundle', 'sachet'];
  
  for (const txn of sampleTransactions) {
    const itemCount = Math.floor(Math.random() * 5) + 1; // 1-5 items per transaction
    
    for (let i = 0; i < itemCount; i++) {
      const unitPrice = Math.floor(Math.random() * 500) + 10; // 10-510 pesos
      const qty = Math.floor(Math.random() * 3) + 1; // 1-3 qty
      const discount = Math.random() > 0.8 ? Math.floor(Math.random() * 50) : 0; // 20% chance of discount
      const gross = unitPrice * qty;
      const net = gross - discount;
      
      sampleItems.push({
        txn_id: txn.txn_id,
        item_seq: i + 1,
        product_id: products[Math.floor(Math.random() * products.length)],
        brand_id: brands[Math.floor(Math.random() * brands.length)],
        category_id: categories[Math.floor(Math.random() * categories.length)],
        unit_raw: units[Math.floor(Math.random() * units.length)],
        qty_raw: qty,
        unit_price_amt: unitPrice,
        discount_amt: discount,
        gross_sales_amt: gross,
        net_sales_amt: net,
        detection_method: 'scanner',
        confidence: 0.95 + Math.random() * 0.05, // 0.95-1.0
        source: 'sample_generator'
      });
    }
  }
  
  console.log(`Generated ${sampleItems.length} sample transaction items`);
  
  // Insert items
  const { error: itemError } = await supabase
    .from('bronze_transaction_items')
    .upsert(sampleItems, { onConflict: 'txn_id,item_seq' });
  
  if (itemError) {
    console.log('❌ Failed to insert sample items:', itemError.message);
    return;
  }
  
  console.log('✅ Sample transaction items inserted successfully');
}

async function main() {
  console.log('🚀 Scout Analytics Bronze Layer Verification');
  console.log('==========================================');
  
  try {
    await verifyBronzeSchema();
    await checkBronzeData();
    await verifySilverViews();
    await verifyGoldViews();
    await verifyDQHealth();
    
    // Check if we need to generate sample data
    const { count } = await supabase
      .from('bronze_transactions')
      .select('*', { count: 'exact', head: true });
    
    if (count === 0) {
      console.log('\n⚠️  No Bronze data found. Would you like to generate sample data?');
      console.log('Run with --generate-sample to create sample data');
    }
    
    if (process.argv.includes('--generate-sample')) {
      await generateSampleData();
    }
    
    console.log('\n✅ Bronze layer verification complete!');
    
  } catch (error) {
    console.error('❌ Verification failed:', error);
    process.exit(1);
  }
}

main();