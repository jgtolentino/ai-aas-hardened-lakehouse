#!/usr/bin/env node

/**
 * Process Edge Inbox Files
 * Downloads and processes files from scout-ingest/edge-inbox/ bucket
 */

const { createClient } = require('@supabase/supabase-js');
const fetch = require('node-fetch');
const JSZip = require('jszip');
const fs = require('fs').promises;
const path = require('path');

// Initialize Supabase client
const supabaseUrl = process.env.SUPABASE_URL || 'https://cxzllzyxwpyptfretryc.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

if (!supabaseKey) {
  console.error('❌ Missing SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// File URLs to process
const FILES_TO_PROCESS = [
  {
    name: 'json.zip',
    url: 'https://cxzllzyxwpyptfretryc.supabase.co/storage/v1/object/sign/scout-ingest/edge-inbox/json.zip?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9lZDdiZGI2YS05YzY1LTQxOTktYTJkNS01NzFmMWQ4NWIyZjciLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJzY291dC1pbmdlc3QvZWRnZS1pbmJveC9qc29uLnppcCIsImlhdCI6MTc1NDkwNDA5MiwiZXhwIjoxNzU1NTA4ODkyfQ.HZE-BRypOov2xldWCkIynMDVTQlM8zhb4Qf1s73Ke1o'
  },
  {
    name: 'scoutpi-0003.zip',
    url: 'https://cxzllzyxwpyptfretryc.supabase.co/storage/v1/object/sign/scout-ingest/edge-inbox/scoutpi-0003.zip?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV9lZDdiZGI2YS05YzY1LTQxOTktYTJkNS01NzFmMWQ4NWIyZjciLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJzY291dC1pbmdlc3QvZWRnZS1pbmJveC9zY291dHBpLTAwMDMuemlwIiwiaWF0IjoxNzU0OTA0MTA1LCJleHAiOjE3NTU1MDg5MDV9.LyPjPuRXlHv0wj7FalB1kXGAOmH0UvJm_oAwVD9els4'
  }
];

async function downloadFile(url, filename) {
  console.log(`📥 Downloading ${filename}...`);
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to download ${filename}: ${response.statusText}`);
  }
  const buffer = await response.buffer();
  return buffer;
}

async function extractZip(buffer) {
  const zip = new JSZip();
  await zip.loadAsync(buffer);
  const files = [];
  
  for (const [filename, file] of Object.entries(zip.files)) {
    if (!file.dir) {
      const content = await file.async('string');
      files.push({ filename, content });
    }
  }
  
  return files;
}

async function processJsonFile(filename, content) {
  try {
    let records = [];
    
    // Try to parse as JSON array
    if (content.trim().startsWith('[')) {
      records = JSON.parse(content);
    } else {
      // Try JSON lines format
      records = content
        .trim()
        .split('\n')
        .filter(Boolean)
        .map(line => JSON.parse(line));
    }
    
    console.log(`  ✓ Parsed ${records.length} records from ${filename}`);
    return records;
  } catch (error) {
    console.error(`  ✗ Failed to parse ${filename}:`, error.message);
    return [];
  }
}

async function insertToBronze(records, sourceFile) {
  if (records.length === 0) return;
  
  // Prepare records for bronze table
  const bronzeRecords = records.map(record => ({
    device_id: record.device_id || record.store_id || 'unknown',
    captured_at: record.timestamp || record.captured_at || new Date().toISOString(),
    src_filename: sourceFile,
    payload: record,
    processing_status: 'pending'
  }));
  
  // Insert in batches of 1000
  const batchSize = 1000;
  let totalInserted = 0;
  
  for (let i = 0; i < bronzeRecords.length; i += batchSize) {
    const batch = bronzeRecords.slice(i, i + batchSize);
    
    const { error } = await supabase
      .from('bronze_edge_raw')
      .insert(batch);
    
    if (error) {
      console.error(`  ✗ Failed to insert batch ${i / batchSize + 1}:`, error.message);
    } else {
      totalInserted += batch.length;
      console.log(`  ✓ Inserted batch ${i / batchSize + 1} (${batch.length} records)`);
    }
  }
  
  return totalInserted;
}

async function processToSilver() {
  console.log('\n🥈 Processing Bronze → Silver layer...');
  
  // Call the transformation function
  const { data, error } = await supabase.rpc('process_bronze_to_silver');
  
  if (error) {
    console.error('  ✗ Failed to process to Silver:', error.message);
  } else {
    console.log('  ✓ Successfully processed to Silver layer');
  }
}

async function refreshGoldViews() {
  console.log('\n🥇 Refreshing Gold layer views...');
  
  const { error } = await supabase.rpc('refresh_gold_views');
  
  if (error) {
    console.error('  ✗ Failed to refresh Gold views:', error.message);
  } else {
    console.log('  ✓ Successfully refreshed Gold views');
  }
}

async function main() {
  console.log('🚀 Edge Inbox ETL Pipeline Processor');
  console.log('====================================\n');
  
  let totalRecordsProcessed = 0;
  
  for (const file of FILES_TO_PROCESS) {
    console.log(`\n📁 Processing ${file.name}`);
    console.log('-'.repeat(40));
    
    try {
      // Download the file
      const buffer = await downloadFile(file.url, file.name);
      console.log(`  ✓ Downloaded (${(buffer.length / 1024 / 1024).toFixed(2)} MB)`);
      
      // Extract ZIP contents
      const extractedFiles = await extractZip(buffer);
      console.log(`  ✓ Extracted ${extractedFiles.length} files`);
      
      // Process each file
      for (const extracted of extractedFiles) {
        if (extracted.filename.endsWith('.json')) {
          console.log(`\n  📄 Processing ${extracted.filename}`);
          const records = await processJsonFile(extracted.filename, extracted.content);
          const inserted = await insertToBronze(records, `edge-inbox/${file.name}/${extracted.filename}`);
          totalRecordsProcessed += inserted;
        }
      }
      
    } catch (error) {
      console.error(`\n❌ Error processing ${file.name}:`, error.message);
    }
  }
  
  console.log(`\n✅ Total records processed: ${totalRecordsProcessed}`);
  
  // Process through the medallion layers
  if (totalRecordsProcessed > 0) {
    await processToSilver();
    await refreshGoldViews();
    
    console.log('\n🎉 ETL Pipeline Complete!');
    console.log('\nNext steps:');
    console.log('1. Check bronze_edge_raw table for raw data');
    console.log('2. Check silver_transactions for cleaned data');
    console.log('3. Query gold views for analytics');
  }
}

// Run the processor
main().catch(console.error);