#!/usr/bin/env node
/**
 * Process Eugene's JSON files: Upload to Storage AND insert to Database
 * This ensures data is both archived and queryable
 */

const fs = require('fs');
const path = require('path');

// Configuration - Replace with your actual credentials
const SUPABASE_URL = 'https://cxzllzyxwpyptfretryc.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

if (!SUPABASE_SERVICE_KEY) {
    console.error('❌ Set SUPABASE_SERVICE_KEY environment variable');
    process.exit(1);
}

async function uploadToStorage(filepath, storagePath) {
    const fileContent = fs.readFileSync(filepath);
    
    const response = await fetch(`${SUPABASE_URL}/storage/v1/object/sample/${storagePath}`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
            'Content-Type': 'application/json'
        },
        body: fileContent
    });
    
    return response.ok;
}

async function insertToDatabase(records) {
    const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/insert_bronze_batch`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal'
        },
        body: JSON.stringify({ records })
    });
    
    return response.ok;
}

async function processEugeneData() {
    console.log('🚀 Processing Eugene\'s Edge Device Data');
    console.log('=====================================\n');
    
    const jsonDir = '/Users/tbwa/Downloads/json';
    const devices = fs.readdirSync(jsonDir).filter(d => d.startsWith('scoutpi-'));
    
    let totalFiles = 0;
    let uploadedToStorage = 0;
    let insertedToDb = 0;
    
    for (const device of devices) {
        console.log(`\n📱 Processing device: ${device}`);
        const deviceDir = path.join(jsonDir, device);
        const files = fs.readdirSync(deviceDir).filter(f => f.endsWith('.json'));
        
        console.log(`   Found ${files.length} transaction files`);
        
        // Process in batches
        const batchSize = 100;
        const records = [];
        
        for (let i = 0; i < files.length; i += batchSize) {
            const batch = files.slice(i, i + batchSize);
            console.log(`   Processing batch ${Math.floor(i/batchSize) + 1}/${Math.ceil(files.length/batchSize)}...`);
            
            for (const file of batch) {
                const filepath = path.join(deviceDir, file);
                
                try {
                    // 1. Upload original JSON to Storage
                    const storagePath = `scout/v1/bronze/eugene_batch/${device}/${file}`;
                    const uploaded = await uploadToStorage(filepath, storagePath);
                    if (uploaded) uploadedToStorage++;
                    
                    // 2. Parse and prepare for database
                    const content = fs.readFileSync(filepath, 'utf8');
                    const data = JSON.parse(content);
                    const items = Array.isArray(data) ? data : [data];
                    
                    for (const item of items) {
                        records.push({
                            device_id: device,
                            captured_at: item.timestamp || item.captured_at || new Date().toISOString(),
                            src_filename: file,
                            payload: item
                        });
                    }
                    
                    totalFiles++;
                } catch (error) {
                    console.error(`   ⚠️  Error with ${file}:`, error.message);
                }
            }
            
            // Insert batch to database
            if (records.length >= 500) {
                const inserted = await insertToDatabase(records.splice(0, 500));
                if (inserted) insertedToDb += 500;
            }
        }
        
        // Insert remaining records
        if (records.length > 0) {
            const inserted = await insertToDatabase(records);
            if (inserted) insertedToDb += records.length;
        }
    }
    
    // Create manifest in storage
    const manifest = {
        upload_date: new Date().toISOString(),
        source: 'eugene_email_2025-08-08',
        devices: devices,
        total_files: totalFiles,
        uploaded_to_storage: uploadedToStorage,
        inserted_to_database: insertedToDb,
        storage_path: 'scout/v1/bronze/eugene_batch/'
    };
    
    await fetch(`${SUPABASE_URL}/storage/v1/object/sample/scout/v1/bronze/eugene_batch/manifest.json`, {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(manifest, null, 2)
    });
    
    console.log('\n📊 Final Summary:');
    console.log('=================');
    console.log(`✅ Files processed: ${totalFiles}`);
    console.log(`💾 Uploaded to storage: ${uploadedToStorage}`);
    console.log(`🗄️  Inserted to database: ${insertedToDb}`);
    console.log(`📁 Storage location: sample/scout/v1/bronze/eugene_batch/`);
    
    console.log('\n🎯 Data is now:');
    console.log('   1. Archived in Supabase Storage (for backup)');
    console.log('   2. Available in scout.bronze_edge_raw table (for querying)');
    console.log('   3. Normalized in scout.silver_edge_events view');
}

// Run
processEugeneData().catch(console.error);