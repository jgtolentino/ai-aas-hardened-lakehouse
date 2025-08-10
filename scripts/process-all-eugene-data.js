#!/usr/bin/env node
/**
 * Process ALL Eugene's JSON files from the eugene-sample directory
 * Handles 1,220+ files efficiently with batching and progress tracking
 */

const fs = require('fs').promises;
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

// Configuration
const EUGENE_DIR = path.join(__dirname, '../eugene-sample');
const BATCH_SIZE = 50; // Process 50 files at a time
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://cxzllzyxwpyptfretryc.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;

if (!SUPABASE_KEY) {
  console.error('❌ Error: SUPABASE_SERVICE_KEY environment variable is required');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Progress tracking
let processed = 0;
let failed = 0;
let skipped = 0;

async function processJsonFile(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    const data = JSON.parse(content);
    
    // Extract metadata
    const fileName = path.basename(filePath);
    const deviceMatch = fileName.match(/scoutpi-(\d+)/);
    const deviceId = deviceMatch ? `scoutpi-${deviceMatch[1]}` : 'unknown';
    
    // Parse timestamp
    const timestampMatch = fileName.match(/(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})-(\d{2})/);
    let capturedAt = null;
    if (timestampMatch) {
      capturedAt = `${timestampMatch[1]}-${timestampMatch[2]}-${timestampMatch[3]}T${timestampMatch[4]}:${timestampMatch[5]}:${timestampMatch[6]}Z`;
    }
    
    // Check if already processed
    const { data: existing } = await supabase
      .from('bronze_edge_raw')
      .select('id')
      .eq('src_filename', fileName)
      .single();
    
    if (existing) {
      skipped++;
      return { status: 'skipped', fileName };
    }
    
    // Insert into bronze table
    const { error } = await supabase
      .from('bronze_edge_raw')
      .insert({
        device_id: deviceId,
        captured_at: capturedAt,
        src_filename: fileName,
        payload: data
      });
    
    if (error) throw error;
    
    processed++;
    return { status: 'success', fileName };
    
  } catch (error) {
    failed++;
    return { status: 'error', fileName: path.basename(filePath), error: error.message };
  }
}

async function processBatch(files) {
  const results = await Promise.all(files.map(processJsonFile));
  return results;
}

async function getAllJsonFiles(dir) {
  const files = [];
  const items = await fs.readdir(dir, { withFileTypes: true });
  
  for (const item of items) {
    const fullPath = path.join(dir, item.name);
    if (item.isDirectory()) {
      const subFiles = await getAllJsonFiles(fullPath);
      files.push(...subFiles);
    } else if (item.name.endsWith('.json')) {
      files.push(fullPath);
    }
  }
  
  return files;
}

async function main() {
  console.log('🚀 Starting Eugene data processing...');
  console.log(`📁 Directory: ${EUGENE_DIR}`);
  
  try {
    // Get all JSON files
    console.log('🔍 Scanning for JSON files...');
    const allFiles = await getAllJsonFiles(EUGENE_DIR);
    console.log(`📊 Found ${allFiles.length} JSON files to process`);
    
    // Process in batches
    const totalBatches = Math.ceil(allFiles.length / BATCH_SIZE);
    
    for (let i = 0; i < allFiles.length; i += BATCH_SIZE) {
      const batch = allFiles.slice(i, i + BATCH_SIZE);
      const batchNum = Math.floor(i / BATCH_SIZE) + 1;
      
      console.log(`\n🔄 Processing batch ${batchNum}/${totalBatches} (${batch.length} files)...`);
      const results = await processBatch(batch);
      
      // Show batch results
      const batchSuccess = results.filter(r => r.status === 'success').length;
      const batchSkipped = results.filter(r => r.status === 'skipped').length;
      const batchFailed = results.filter(r => r.status === 'error').length;
      
      console.log(`   ✅ Success: ${batchSuccess}, ⏭️  Skipped: ${batchSkipped}, ❌ Failed: ${batchFailed}`);
      
      // Show errors if any
      const errors = results.filter(r => r.status === 'error');
      if (errors.length > 0) {
        console.log('   Errors:');
        errors.forEach(e => console.log(`     - ${e.fileName}: ${e.error}`));
      }
      
      // Progress
      const totalProcessed = processed + failed + skipped;
      const percentage = ((totalProcessed / allFiles.length) * 100).toFixed(1);
      console.log(`   Progress: ${totalProcessed}/${allFiles.length} (${percentage}%)`);
    }
    
    // Final summary
    console.log('\n' + '='.repeat(50));
    console.log('📊 PROCESSING COMPLETE');
    console.log('='.repeat(50));
    console.log(`✅ Successfully processed: ${processed}`);
    console.log(`⏭️  Already existed (skipped): ${skipped}`);
    console.log(`❌ Failed: ${failed}`);
    console.log(`📈 Total files handled: ${processed + failed + skipped}`);
    
    // Verify in database
    const { count } = await supabase
      .from('bronze_edge_raw')
      .select('*', { count: 'exact', head: true });
    
    console.log(`\n🗄️  Total records in bronze table: ${count}`);
    
    // Show sample data
    const { data: sample } = await supabase
      .from('bronze_edge_raw')
      .select('device_id, captured_at')
      .order('captured_at', { ascending: false })
      .limit(5);
    
    console.log('\n📋 Latest records:');
    sample?.forEach(record => {
      console.log(`   ${record.device_id} - ${record.captured_at}`);
    });
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  }
}

// Run the processor
main().catch(console.error);