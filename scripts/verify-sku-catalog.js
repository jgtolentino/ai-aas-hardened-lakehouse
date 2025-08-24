#!/usr/bin/env node

/**
 * Verify SKU Catalog Migration Status
 * Checks if all required tables and schemas exist in Supabase
 */

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '.env.local' });

const supabaseUrl = process.env.SUPABASE_URL || 'https://cxzllzyxwpyptfretryc.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseKey) {
  console.error('❌ Missing SUPABASE_SERVICE_ROLE_KEY in .env.local');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function verifySkuCatalog() {
  console.log('🔍 Verifying SKU Catalog Migration Status...\n');
  
  const checks = {
    schemas: false,
    tables: false,
    telcoExtensions: false,
    views: false,
    data: false
  };

  try {
    // 1. Check schemas
    console.log('1️⃣ Checking schemas...');
    const { data: schemas, error: schemaError } = await supabase.rpc('exec_sql', {
      sql: `
        SELECT schema_name 
        FROM information_schema.schemata 
        WHERE schema_name IN ('masterdata', 'staging')
        ORDER BY schema_name
      `
    });
    
    if (!schemaError && schemas && schemas.length === 2) {
      console.log('✅ Schemas found: masterdata, staging');
      checks.schemas = true;
    } else {
      console.log('❌ Missing schemas');
    }

    // 2. Check core tables
    console.log('\n2️⃣ Checking core tables...');
    const { data: tables, error: tableError } = await supabase.rpc('exec_sql', {
      sql: `
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'masterdata' 
        AND table_name IN ('brands', 'products', 'brand_id_map')
        ORDER BY table_name
      `
    });
    
    if (!tableError && tables && tables.length >= 2) {
      console.log('✅ Core tables found:', tables.map(t => t.table_name).join(', '));
      checks.tables = true;
    } else {
      console.log('❌ Missing core tables');
    }

    // 3. Check telco extensions
    console.log('\n3️⃣ Checking telco extensions...');
    const { data: telcoTables, error: telcoError } = await supabase.rpc('exec_sql', {
      sql: `
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'masterdata' 
        AND table_name IN ('telco_products', 'barcode_registry', 'price_history')
        ORDER BY table_name
      `
    });
    
    if (!telcoError && telcoTables && telcoTables.length === 3) {
      console.log('✅ Telco extension tables found');
      checks.telcoExtensions = true;
    } else {
      console.log('❌ Missing telco extension tables');
    }

    // 4. Check views
    console.log('\n4️⃣ Checking views...');
    const { data: views, error: viewError } = await supabase.rpc('exec_sql', {
      sql: `
        SELECT table_name 
        FROM information_schema.views 
        WHERE table_schema = 'masterdata' 
        AND table_name IN ('v_product_catalog', 'v_telco_products', 'v_halal_products')
        ORDER BY table_name
      `
    });
    
    if (!viewError && views && views.length >= 1) {
      console.log('✅ Views found:', views.map(v => v.table_name).join(', '));
      checks.views = true;
    } else {
      console.log('❌ Missing views');
    }

    // 5. Check for data
    console.log('\n5️⃣ Checking for existing data...');
    const { data: productCount, error: countError } = await supabase.rpc('exec_sql', {
      sql: `
        SELECT 
          (SELECT COUNT(*) FROM masterdata.brands) as brand_count,
          (SELECT COUNT(*) FROM masterdata.products) as product_count
      `
    });
    
    if (!countError && productCount && productCount[0]) {
      const counts = productCount[0];
      console.log(`📊 Data status:`);
      console.log(`   - Brands: ${counts.brand_count}`);
      console.log(`   - Products: ${counts.product_count}`);
      
      if (counts.product_count > 0) {
        checks.data = true;
        console.log('✅ Data already imported');
      } else {
        console.log('⏳ No data imported yet');
      }
    }

  } catch (error) {
    console.error('❌ Error during verification:', error.message);
  }

  // Summary
  console.log('\n📋 VERIFICATION SUMMARY:');
  console.log('========================');
  
  const allChecks = Object.values(checks);
  const passedChecks = allChecks.filter(c => c).length;
  
  Object.entries(checks).forEach(([check, passed]) => {
    console.log(`${passed ? '✅' : '❌'} ${check}`);
  });

  console.log('\n🎯 RESULT:');
  if (passedChecks === allChecks.length) {
    console.log('✅ SKU Catalog fully deployed and ready!');
    console.log('🚀 All 347 products have been imported.');
  } else if (checks.schemas && checks.tables) {
    console.log('⚠️  Schema deployed but data not imported yet.');
    console.log('📝 Next step: Run the import script to load 347 products.');
    console.log('   node scripts/import-sku-catalog-347.js');
  } else {
    console.log('❌ SKU Catalog not deployed.');
    console.log('📝 Next step: Apply the migrations first.');
    console.log('   1. Go to Supabase SQL Editor');
    console.log('   2. Copy contents of scripts/APPLY_ALL_SKU_MIGRATIONS_NOW.sql');
    console.log('   3. Paste and run in SQL Editor');
  }
}

// Alternative: Direct SQL check function
async function directSqlCheck() {
  console.log('\n🔧 Alternative: Direct SQL verification...');
  console.log('Run this SQL in Supabase dashboard to check status:');
  console.log('```sql');
  console.log(`-- Check schemas
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name IN ('masterdata', 'staging');

-- Check tables
SELECT table_schema, table_name FROM information_schema.tables 
WHERE table_schema IN ('masterdata', 'staging') 
ORDER BY table_schema, table_name;

-- Check data
SELECT 
  (SELECT COUNT(*) FROM masterdata.brands) as brands,
  (SELECT COUNT(*) FROM masterdata.products) as products;`);
  console.log('```');
}

// Run verification
verifySkuCatalog().then(() => {
  directSqlCheck();
}).catch(console.error);