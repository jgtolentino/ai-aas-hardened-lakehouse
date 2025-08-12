#!/usr/bin/env node
/**
 * Ingest Eugene's edge device JSON files into Scout bronze_edge_raw
 */

const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

// Use your Supabase connection string
const PGURI = process.env.PGURI || 'postgresql://postgres.[password]@db.cxzllzyxwpyptfretryc.supabase.co:5432/postgres';

async function processEugeneJsonFiles() {
    console.log('📂 Processing Eugene\'s edge device JSON files...\n');
    
    const client = new Client(PGURI);
    await client.connect();
    
    const jsonDir = '/Users/tbwa/Downloads/json';
    const devices = ['scoutpi-0002', 'scoutpi-0006'];
    
    let totalProcessed = 0;
    let totalInserted = 0;
    
    for (const device of devices) {
        const deviceDir = path.join(jsonDir, device);
        const files = fs.readdirSync(deviceDir).filter(f => f.endsWith('.json'));
        
        console.log(`\n🔧 Processing device: ${device}`);
        console.log(`📊 Found ${files.length} JSON files`);
        
        // Process in batches of 50 files
        const batchSize = 50;
        
        for (let i = 0; i < files.length; i += batchSize) {
            const batch = files.slice(i, i + batchSize);
            const values = [];
            
            for (const file of batch) {
                try {
                    const filepath = path.join(deviceDir, file);
                    const content = fs.readFileSync(filepath, 'utf8');
                    const data = JSON.parse(content);
                    
                    // Handle array or single object
                    const records = Array.isArray(data) ? data : [data];
                    
                    for (const record of records) {
                        // Extract timestamp from record
                        const timestamp = record.timestamp || record.captured_at || new Date().toISOString();
                        
                        values.push(`(
                            '${device}',
                            '${timestamp}'::timestamptz,
                            '${file}',
                            '${JSON.stringify(record).replace(/'/g, "''")}'::jsonb
                        )`);
                    }
                    
                    totalProcessed++;
                } catch (error) {
                    console.error(`⚠️  Error processing ${file}:`, error.message);
                }
            }
            
            if (values.length > 0) {
                try {
                    const insertQuery = `
                        INSERT INTO scout.bronze_edge_raw 
                        (device_id, captured_at, src_filename, payload)
                        VALUES ${values.join(',\n')}
                    `;
                    
                    const result = await client.query(insertQuery);
                    totalInserted += result.rowCount;
                    
                    console.log(`✅ Batch ${Math.floor(i/batchSize) + 1}: Inserted ${result.rowCount} records`);
                } catch (error) {
                    console.error('❌ Batch insert failed:', error.message);
                }
            }
        }
    }
    
    // Create silver view if not exists
    await client.query(`
        CREATE OR REPLACE VIEW scout.silver_edge_events AS
        SELECT
            id,
            device_id,
            captured_at,
            src_filename,
            payload->>'id' as transaction_id,
            payload->>'store_id' as store_id,
            (payload->>'timestamp')::timestamptz as event_time,
            payload->'location'->>'region' as region,
            payload->'location'->>'province' as province,
            payload->'location'->>'city' as city,
            payload->'location'->>'barangay' as barangay,
            (payload->>'duration_seconds')::numeric as duration_seconds,
            (payload->>'is_tbwa_client')::boolean as is_tbwa_client,
            payload->>'brand_name' as brand_name,
            payload->>'sku' as sku,
            payload->>'product_category' as product_category,
            (payload->>'units_per_transaction')::integer as units_per_transaction,
            payload->>'request_type' as request_type,
            (payload->>'suggestion_accepted')::boolean as suggestion_accepted,
            payload->>'substitution_event' as substitution_event,
            (payload->>'campaign_influenced')::boolean as campaign_influenced,
            payload
        FROM scout.bronze_edge_raw
        WHERE device_id IN ('scoutpi-0002', 'scoutpi-0006')
    `);
    
    console.log('\n📊 Summary:');
    console.log(`  - Files processed: ${totalProcessed}`);
    console.log(`  - Records inserted: ${totalInserted}`);
    
    // Show sample data
    const sample = await client.query(`
        SELECT 
            device_id,
            COUNT(*) as record_count,
            MIN(captured_at) as earliest,
            MAX(captured_at) as latest
        FROM scout.bronze_edge_raw
        GROUP BY device_id
    `);
    
    console.log('\n📈 Data Overview:');
    console.table(sample.rows);
    
    await client.end();
    console.log('\n✅ Ingestion complete!');
}

// Run if called directly
if (require.main === module) {
    processEugeneJsonFiles().catch(console.error);
}

module.exports = { processEugeneJsonFiles };