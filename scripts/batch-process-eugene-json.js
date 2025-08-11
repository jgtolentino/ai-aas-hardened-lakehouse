#!/usr/bin/env node
/**
 * Batch process all Eugene's JSON files into Scout database
 * Optimized for 1000+ files
 */

const fs = require('fs');
const path = require('path');

// Supabase configuration
const PGURI = process.env.PGURI || 'postgresql://postgres.[password]@db.cxzllzyxwpyptfretryc.supabase.co:5432/postgres';

console.log('🚀 Processing Eugene\'s JSON files...\n');

// Check if pg module is available
try {
    const { Client } = require('pg');
} catch (err) {
    console.log('Installing pg module...');
    require('child_process').execSync('npm install pg', { stdio: 'inherit' });
}

const { Client } = require('pg');

async function processAllFiles() {
    const client = new Client(PGURI);
    
    try {
        await client.connect();
        console.log('✅ Connected to database\n');
        
        const jsonDir = '/Users/tbwa/Downloads/json';
        const devices = ['scoutpi-0002', 'scoutpi-0006'];
        
        let totalProcessed = 0;
        let totalInserted = 0;
        
        for (const device of devices) {
            const deviceDir = path.join(jsonDir, device);
            
            if (!fs.existsSync(deviceDir)) {
                console.log(`⚠️  Directory not found: ${deviceDir}`);
                continue;
            }
            
            const files = fs.readdirSync(deviceDir).filter(f => f.endsWith('.json'));
            console.log(`📱 Device ${device}: ${files.length} files to process`);
            
            // Process in batches of 100
            const batchSize = 100;
            
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
                            const timestamp = record.timestamp || record.captured_at || new Date().toISOString();
                            values.push({
                                device_id: device,
                                captured_at: timestamp,
                                src_filename: file,
                                payload: record
                            });
                        }
                        
                        totalProcessed++;
                    } catch (error) {
                        console.error(`   ❌ Error in ${file}: ${error.message}`);
                    }
                }
                
                // Batch insert
                if (values.length > 0) {
                    try {
                        // Build INSERT query with UNNEST for better performance
                        const insertQuery = `
                            INSERT INTO scout.bronze_edge_raw (device_id, captured_at, src_filename, payload)
                            SELECT * FROM UNNEST(
                                $1::text[],
                                $2::timestamptz[],
                                $3::text[],
                                $4::jsonb[]
                            ) AS t(device_id, captured_at, src_filename, payload)
                            ON CONFLICT (id) DO NOTHING
                        `;
                        
                        const result = await client.query(insertQuery, [
                            values.map(v => v.device_id),
                            values.map(v => v.captured_at),
                            values.map(v => v.src_filename),
                            values.map(v => JSON.stringify(v.payload))
                        ]);
                        
                        totalInserted += result.rowCount;
                        process.stdout.write(`   ✅ Batch ${Math.floor(i/batchSize) + 1}/${Math.ceil(files.length/batchSize)}: ${result.rowCount} records\r`);
                    } catch (error) {
                        console.error(`\n   ❌ Insert error: ${error.message}`);
                    }
                }
            }
            console.log(''); // New line after progress
        }
        
        console.log('\n📊 Final Summary:');
        console.log(`   Files processed: ${totalProcessed}`);
        console.log(`   Records inserted: ${totalInserted}`);
        
        // Verify final counts
        const verifyQuery = `
            SELECT 
                device_id,
                COUNT(*) as total_records,
                COUNT(DISTINCT src_filename) as unique_files,
                MIN(captured_at) as earliest,
                MAX(captured_at) as latest
            FROM scout.bronze_edge_raw
            GROUP BY device_id
            ORDER BY device_id
        `;
        
        const result = await client.query(verifyQuery);
        console.log('\n📈 Database Status:');
        console.table(result.rows);
        
    } catch (error) {
        console.error('Fatal error:', error);
    } finally {
        await client.end();
    }
}

// Run if called directly
if (require.main === module) {
    console.log('Set PGURI environment variable with your database password:');
    console.log('export PGURI="postgresql://postgres:[YOUR-PASSWORD]@db.cxzllzyxwpyptfretryc.supabase.co:5432/postgres"');
    console.log('\nThen run this script again.\n');
    
    if (process.env.PGURI && !process.env.PGURI.includes('[YOUR-PASSWORD]')) {
        processAllFiles().catch(console.error);
    }
}

module.exports = { processAllFiles };