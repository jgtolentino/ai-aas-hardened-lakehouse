#!/usr/bin/env node
/**
 * Process JSON files from Eugene's email and upload to Supabase
 * Usage: node process-eugene-json.js /path/to/json/files
 */

const fs = require('fs');
const path = require('path');
const { createClient } = require('@supabase/supabase-js');

// Configuration
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://cxzllzyxwpyptfretryc.supabase.co';
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY;

if (!SUPABASE_KEY) {
    console.error('❌ SUPABASE_SERVICE_KEY environment variable required');
    process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function processJsonFiles(directory) {
    console.log('📂 Processing JSON files from:', directory);
    
    const files = fs.readdirSync(directory)
        .filter(f => f.endsWith('.json'));
    
    console.log(`📊 Found ${files.length} JSON files`);
    
    const records = [];
    
    for (const file of files) {
        const filepath = path.join(directory, file);
        console.log(`📄 Reading: ${file}`);
        
        try {
            const content = fs.readFileSync(filepath, 'utf8');
            const data = JSON.parse(content);
            
            // Extract device info from filename or content
            const deviceMatch = file.match(/device[_-]?(\d+)/i);
            const deviceId = deviceMatch ? `device_${deviceMatch[1]}` : 
                            data.device_id || data.device || 'unknown';
            
            // Handle both single records and arrays
            const items = Array.isArray(data) ? data : [data];
            
            for (const item of items) {
                records.push({
                    device_id: deviceId,
                    captured_at: item.timestamp || item.captured_at || item.date || new Date().toISOString(),
                    src_filename: file,
                    payload: item,
                    ingested_at: new Date().toISOString()
                });
            }
            
        } catch (error) {
            console.error(`❌ Error processing ${file}:`, error.message);
        }
    }
    
    console.log(`\n📤 Uploading ${records.length} records to scout.bronze_edge_raw...`);
    
    // Batch insert into bronze table
    const batchSize = 100;
    let uploaded = 0;
    
    for (let i = 0; i < records.length; i += batchSize) {
        const batch = records.slice(i, i + batchSize);
        
        const { data, error } = await supabase
            .from('bronze_edge_raw')
            .insert(batch);
        
        if (error) {
            console.error('❌ Upload error:', error);
        } else {
            uploaded += batch.length;
            console.log(`✅ Uploaded ${uploaded}/${records.length} records`);
        }
    }
    
    // Also save to Storage for backup
    const manifest = {
        upload_date: new Date().toISOString(),
        source: 'eugene_email',
        device_count: new Set(records.map(r => r.device_id)).size,
        record_count: records.length,
        files_processed: files
    };
    
    const manifestBlob = new Blob([JSON.stringify(manifest, null, 2)], { type: 'application/json' });
    
    const { data: storageData, error: storageError } = await supabase.storage
        .from('sample')
        .upload(
            `scout/v1/bronze/eugene_batch_${Date.now()}.json`,
            manifestBlob,
            { contentType: 'application/json' }
        );
    
    if (storageError) {
        console.error('⚠️ Storage backup failed:', storageError);
    } else {
        console.log('💾 Backup saved to Storage');
    }
    
    console.log('\n📊 Summary:');
    console.log(`  - Files processed: ${files.length}`);
    console.log(`  - Records uploaded: ${uploaded}`);
    console.log(`  - Unique devices: ${new Set(records.map(r => r.device_id)).size}`);
    
    // Show sample query
    console.log('\n🔍 Query your data with:');
    console.log(`SELECT * FROM scout.bronze_edge_raw WHERE src_filename LIKE 'device%' ORDER BY captured_at DESC LIMIT 10;`);
    console.log(`SELECT * FROM scout.silver_edge_events WHERE device_id != 'unknown' ORDER BY captured_at DESC;`);
}

// Run if called directly
if (require.main === module) {
    const dir = process.argv[2];
    if (!dir) {
        console.error('Usage: node process-eugene-json.js /path/to/json/files');
        process.exit(1);
    }
    
    processJsonFiles(dir).catch(console.error);
}

module.exports = { processJsonFiles };