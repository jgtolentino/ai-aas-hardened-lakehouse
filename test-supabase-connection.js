#!/usr/bin/env node

// Test Supabase connection with the loaded credentials
const { createClient } = require('@supabase/supabase-js');

async function testSupabaseConnection() {
  console.log('🔗 Testing Supabase Connection...');
  
  // Get environment variables that should be loaded by the wrapper script
  const supabaseUrl = process.env.SUPABASE_URL || 'https://cxzllzyxwpyptfretryc.supabase.co';
  const supabaseKey = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
  
  if (!supabaseKey) {
    console.error('❌ No Supabase key found in environment');
    console.log('Available env vars:', Object.keys(process.env).filter(k => k.includes('SUPABASE')));
    return;
  }
  
  console.log('📋 Using Supabase URL:', supabaseUrl);
  console.log('🔑 Using key:', supabaseKey.substring(0, 20) + '...');
  
  try {
    const supabase = createClient(supabaseUrl, supabaseKey);
    
    // Test basic connection
    console.log('🧪 Testing basic connection...');
    const { data, error } = await supabase
      .from('scout.agents')
      .select('count')
      .limit(1);
    
    if (error) {
      console.error('❌ Connection test failed:', error.message);
      
      // Try to check if scout schema exists
      console.log('🔍 Checking if scout schema exists...');
      const { data: schemaData, error: schemaError } = await supabase
        .rpc('scout_get_schema_info', {})
        .single();
        
      if (schemaError) {
        console.log('⚠️ Scout schema may not be deployed yet');
        console.log('Run: npx supabase db push');
      }
    } else {
      console.log('✅ Supabase connection successful!');
      console.log('📊 Scout agents table accessible');
    }
    
  } catch (err) {
    console.error('❌ Unexpected error:', err.message);
  }
}

testSupabaseConnection();