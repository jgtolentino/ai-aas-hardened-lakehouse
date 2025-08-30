// S3/ADLS2 Data Loader Edge Function
// Fetches data from external storage and loads into Scout bronze layer

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { S3Client, GetObjectCommand, ListObjectsV2Command } from 'https://esm.sh/@aws-sdk/client-s3@3'
import { BlobServiceClient } from 'https://esm.sh/@azure/storage-blob@12'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const supabase = createClient(supabaseUrl, supabaseServiceKey)

interface LoadRequest {
  environment: 'development' | 'staging' | 'production'
  storageType: 's3' | 'adls2'
  dataType: 'transactions' | 'items' | 'customers' | 'stores'
  dateRange?: {
    start: string
    end: string
  }
}

serve(async (req) => {
  try {
    const { environment, storageType, dataType, dateRange } = await req.json() as LoadRequest

    // Get storage configuration
    const { data: config, error: configError } = await supabase
      .from('external_storage_config')
      .select('*')
      .eq('environment', environment)
      .eq('storage_type', storageType)
      .single()

    if (configError) {
      throw new Error(`Storage config not found: ${configError.message}`)
    }

    // Initialize ETL job
    const { data: job, error: jobError } = await supabase
      .from('etl_job_runs')
      .insert({
        run_type: 'manual',
        status: 'running',
        started_at: new Date().toISOString()
      })
      .select()
      .single()

    if (jobError) {
      throw new Error(`Failed to create job: ${jobError.message}`)
    }

    let processedRecords = 0
    let failedRecords = 0

    // Process based on storage type
    if (storageType === 's3') {
      processedRecords = await processS3Data(config, dataType, dateRange)
    } else if (storageType === 'adls2') {
      processedRecords = await processADLS2Data(config, dataType, dateRange)
    }

    // Update job status
    await supabase
      .from('etl_job_runs')
      .update({
        status: 'completed',
        records_processed: processedRecords,
        records_failed: failedRecords,
        completed_at: new Date().toISOString()
      })
      .eq('run_id', job.run_id)

    // Trigger processing from Bronze to Silver
    await supabase.rpc('process_bronze_to_silver', { p_batch_size: 1000 })
    
    // Then Silver to Gold
    await supabase.rpc('process_silver_to_gold', { p_batch_size: 1000 })

    return new Response(
      JSON.stringify({
        success: true,
        jobId: job.run_id,
        recordsProcessed: processedRecords,
        recordsFailed: failedRecords
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('ETL Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})

async function processS3Data(
  config: any,
  dataType: string,
  dateRange?: { start: string; end: string }
): Promise<number> {
  
  // Initialize S3 client
  const s3Client = new S3Client({
    region: config.s3_region || 'us-east-1',
    credentials: config.s3_access_key_id ? {
      accessKeyId: config.s3_access_key_id,
      secretAccessKey: config.s3_secret_access_key
    } : undefined,
    endpoint: config.s3_endpoint
  })

  // Build S3 path
  const prefix = `${config.path_prefix}${dataType}/`
  
  // List objects
  const listCommand = new ListObjectsV2Command({
    Bucket: config.s3_bucket,
    Prefix: prefix,
    MaxKeys: 1000
  })
  
  const listResponse = await s3Client.send(listCommand)
  const files = listResponse.Contents || []
  
  let totalRecords = 0
  
  // Process each file
  for (const file of files) {
    if (!file.Key) continue
    
    // Check if file is in date range
    if (dateRange) {
      const fileDate = extractDateFromPath(file.Key)
      if (fileDate < dateRange.start || fileDate > dateRange.end) {
        continue
      }
    }
    
    // Get object
    const getCommand = new GetObjectCommand({
      Bucket: config.s3_bucket,
      Key: file.Key
    })
    
    const response = await s3Client.send(getCommand)
    const bodyString = await streamToString(response.Body)
    
    // Parse based on format
    let records: any[] = []
    if (config.file_format === 'json') {
      records = JSON.parse(bodyString)
    } else if (config.file_format === 'csv') {
      records = parseCSV(bodyString)
    } else if (config.file_format === 'parquet') {
      // For parquet, we'd need a specialized library
      // For now, assume it's been converted to JSON
      records = JSON.parse(bodyString)
    }
    
    // Insert into bronze layer
    if (dataType === 'transactions') {
      const { error } = await supabase
        .from('bronze_transactions')
        .insert(
          records.map(r => ({
            _source_file: file.Key,
            _raw_data: r,
            transaction_id: r.transaction_id || r.id,
            store_id: r.store_id,
            timestamp: r.timestamp || r.created_at,
            total_amount: r.total_amount || r.amount,
            items: r.items || r.line_items,
            payment_method: r.payment_method,
            customer_segment: r.customer_segment
          }))
        )
      
      if (error) {
        console.error('Insert error:', error)
      } else {
        totalRecords += records.length
      }
    }
  }
  
  return totalRecords
}

async function processADLS2Data(
  config: any,
  dataType: string,
  dateRange?: { start: string; end: string }
): Promise<number> {
  
  // Initialize Azure Blob client
  const blobServiceClient = BlobServiceClient.fromConnectionString(
    config.adls2_connection_string || 
    `DefaultEndpointsProtocol=https;AccountName=${config.adls2_account_name};AccountKey=${config.adls2_sas_token};EndpointSuffix=core.windows.net`
  )
  
  const containerClient = blobServiceClient.getContainerClient(config.adls2_container)
  
  // Build path
  const prefix = `${config.path_prefix}${dataType}/`
  
  let totalRecords = 0
  
  // List blobs
  for await (const blob of containerClient.listBlobsFlat({ prefix })) {
    // Check date range
    if (dateRange) {
      const fileDate = extractDateFromPath(blob.name)
      if (fileDate < dateRange.start || fileDate > dateRange.end) {
        continue
      }
    }
    
    // Download blob
    const blockBlobClient = containerClient.getBlockBlobClient(blob.name)
    const downloadResponse = await blockBlobClient.download(0)
    const bodyString = await streamToString(downloadResponse.readableStreamBody!)
    
    // Parse and process similar to S3
    let records: any[] = []
    if (config.file_format === 'json' || config.file_format === 'delta') {
      records = JSON.parse(bodyString)
    } else if (config.file_format === 'csv') {
      records = parseCSV(bodyString)
    }
    
    // Insert into bronze layer
    if (dataType === 'transactions') {
      const { error } = await supabase
        .from('bronze_transactions')
        .insert(
          records.map(r => ({
            _source_file: blob.name,
            _raw_data: r,
            transaction_id: r.transaction_id,
            store_id: r.store_id,
            timestamp: r.timestamp,
            total_amount: r.total_amount,
            items: r.items,
            payment_method: r.payment_method,
            customer_segment: r.customer_segment
          }))
        )
      
      if (!error) {
        totalRecords += records.length
      }
    }
  }
  
  return totalRecords
}

// Helper functions
async function streamToString(stream: any): Promise<string> {
  const chunks: Uint8Array[] = []
  for await (const chunk of stream) {
    chunks.push(chunk)
  }
  const buffer = new Uint8Array(chunks.reduce((acc, chunk) => acc + chunk.length, 0))
  let offset = 0
  for (const chunk of chunks) {
    buffer.set(chunk, offset)
    offset += chunk.length
  }
  return new TextDecoder().decode(buffer)
}

function parseCSV(csvString: string): any[] {
  const lines = csvString.split('\n')
  const headers = lines[0].split(',').map(h => h.trim())
  const records = []
  
  for (let i = 1; i < lines.length; i++) {
    if (!lines[i].trim()) continue
    const values = lines[i].split(',')
    const record: any = {}
    headers.forEach((header, index) => {
      record[header] = values[index]?.trim()
    })
    records.push(record)
  }
  
  return records
}

function extractDateFromPath(path: string): string {
  // Extract date from path patterns like: /2024/01/15/ or dt=2024-01-15
  const dateMatch = path.match(/(\d{4})[/-](\d{2})[/-](\d{2})/)
  if (dateMatch) {
    return `${dateMatch[1]}-${dateMatch[2]}-${dateMatch[3]}`
  }
  return new Date().toISOString().split('T')[0]
}
