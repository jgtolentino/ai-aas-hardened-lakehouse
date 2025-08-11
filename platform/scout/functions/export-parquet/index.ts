import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/**
 * Parquet Export Function for Scout Analytics
 * 
 * Exports Gold and Platinum layer data to Parquet format for efficient
 * columnar storage and analytics processing.
 * 
 * Features:
 * - Streaming exports for large datasets
 * - Partitioned exports by date/store
 * - Compressed Parquet files
 * - Schema validation
 */

interface ExportRequest {
  dataset: string;
  format?: 'parquet' | 'csv' | 'json';
  partition_by?: string;
  date_range?: {
    start: string;
    end: string;
  };
  compression?: 'snappy' | 'gzip' | 'lz4' | 'brotli';
  limit?: number;
}

interface ParquetExportResult {
  export_id: string;
  file_path: string;
  file_size: number;
  row_count: number;
  schema: Record<string, string>;
  compression: string;
  created_at: string;
  signed_url?: string;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

// Initialize Supabase client
const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

/**
 * Available datasets for export
 */
const AVAILABLE_DATASETS = {
  // Gold Layer
  'daily_transactions': {
    table: 'scout_gold.daily_transactions',
    partition_column: 'transaction_date',
    schema: {
      transaction_date: 'date',
      device_id: 'string',
      transaction_count: 'int64',
      total_revenue: 'double',
      avg_transaction_value: 'double',
      cash_pct: 'double',
      gcash_pct: 'double',
      card_pct: 'double',
      morning_pct: 'double',
      afternoon_pct: 'double',
      evening_pct: 'double',
    }
  },
  'store_rankings': {
    table: 'scout_gold.store_rankings',
    partition_column: 'region',
    schema: {
      store_id: 'string',
      region: 'string',
      city: 'string',
      total_revenue: 'double',
      revenue_rank: 'int64',
      performance_tier: 'string',
    }
  },
  'hourly_patterns': {
    table: 'scout_gold.hourly_patterns',
    partition_column: 'transaction_date',
    schema: {
      transaction_date: 'date',
      hour_of_day: 'int64',
      total_transactions: 'int64',
      total_revenue: 'double',
      avg_transaction_value: 'double',
      peak_indicator: 'boolean',
    }
  },
  'payment_trends': {
    table: 'scout_gold.payment_trends',
    partition_column: 'transaction_date',
    schema: {
      transaction_date: 'date',
      payment_method: 'string',
      transaction_count: 'int64',
      total_amount: 'double',
      percentage_of_total: 'double',
    }
  },
  
  // Platinum Layer  
  'store_features': {
    table: 'scout_platinum.store_features',
    partition_column: 'region',
    schema: {
      store_id: 'string',
      region: 'string',
      city: 'string',
      revenue_forecast_next_7d: 'double',
      churn_probability: 'double',
      growth_potential_score: 'double',
      seasonality_index: 'double',
      customer_lifetime_value: 'double',
      last_updated: 'timestamp',
    }
  },
  'ml_predictions': {
    table: 'scout_platinum.ml_predictions',
    partition_column: 'prediction_date',
    schema: {
      prediction_date: 'date',
      store_id: 'string',
      predicted_revenue: 'double',
      confidence_interval_lower: 'double',
      confidence_interval_upper: 'double',
      model_version: 'string',
      prediction_accuracy: 'double',
    }
  }
};

/**
 * Generate a Python script for Arrow/Parquet conversion
 * This script will be executed in a subprocess to create Parquet files
 */
function generateParquetScript(
  data: any[], 
  schema: Record<string, string>,
  compression: string = 'snappy'
): string {
  const schemaMapping = Object.entries(schema).map(([col, type]) => {
    const pyArrowType = {
      'string': 'pa.string()',
      'int64': 'pa.int64()', 
      'double': 'pa.float64()',
      'boolean': 'pa.bool_()',
      'date': 'pa.date32()',
      'timestamp': 'pa.timestamp("us")',
    }[type] || 'pa.string()';
    
    return `('${col}', ${pyArrowType})`;
  }).join(', ');

  return `
import pyarrow as pa
import pyarrow.parquet as pq
import json
import sys

# Read JSON data from stdin
data = json.load(sys.stdin)

# Define schema
schema = pa.schema([${schemaMapping}])

# Create Arrow table
table = pa.Table.from_pylist(data, schema=schema)

# Write to Parquet with compression
pq.write_table(
    table, 
    sys.argv[1],  # Output file path
    compression='${compression}',
    use_dictionary=True,
    row_group_size=50000,
    data_page_size=1024*1024,
    write_statistics=True,
    use_deprecated_int96_timestamps=False
)

# Output file stats
import os
file_size = os.path.getsize(sys.argv[1])
print(json.dumps({
    'file_size': file_size,
    'row_count': len(table),
    'compression': '${compression}',
    'columns': len(table.schema),
}))
`;
}

/**
 * Execute the Parquet conversion using Python/PyArrow
 */
async function convertToParquet(
  data: any[],
  outputPath: string,
  schema: Record<string, string>,
  compression: string = 'snappy'
): Promise<{ file_size: number; row_count: number }> {
  
  const script = generateParquetScript(data, schema, compression);
  
  // Write Python script to temporary file
  const scriptPath = `/tmp/convert_${Date.now()}.py`;
  await Deno.writeTextFile(scriptPath, script);
  
  try {
    // Create process to run Python script
    const process = new Deno.Command('python3', {
      args: [scriptPath, outputPath],
      stdin: 'piped',
      stdout: 'piped',
      stderr: 'piped',
    });

    const child = process.spawn();
    
    // Write data to stdin
    const writer = child.stdin.getWriter();
    await writer.write(new TextEncoder().encode(JSON.stringify(data)));
    await writer.close();
    
    // Wait for completion
    const { code, stdout, stderr } = await child.status;
    
    if (code !== 0) {
      const errorText = new TextDecoder().decode(stderr);
      throw new Error(`Parquet conversion failed: ${errorText}`);
    }
    
    const result = JSON.parse(new TextDecoder().decode(stdout));
    return result;
    
  } finally {
    // Clean up script file
    try {
      await Deno.remove(scriptPath);
    } catch (e) {
      console.warn('Failed to cleanup script file:', e);
    }
  }
}

/**
 * Query data from the specified dataset
 */
async function queryDataset(
  dataset: string,
  dateRange?: { start: string; end: string },
  limit?: number
): Promise<any[]> {
  const config = AVAILABLE_DATASETS[dataset];
  if (!config) {
    throw new Error(`Unknown dataset: ${dataset}`);
  }

  let query = supabase.from(config.table.split('.')[1]).select('*');

  // Apply date range filter if provided
  if (dateRange && config.partition_column) {
    query = query
      .gte(config.partition_column, dateRange.start)
      .lte(config.partition_column, dateRange.end);
  }

  // Apply limit if provided
  if (limit) {
    query = query.limit(limit);
  }

  const { data, error } = await query;
  
  if (error) {
    throw new Error(`Query failed: ${error.message}`);
  }

  return data || [];
}

/**
 * Generate a unique file path for the export
 */
function generateFilePath(
  dataset: string,
  format: string,
  partition?: string
): string {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const partitionSuffix = partition ? `_${partition}` : '';
  return `exports/${dataset}${partitionSuffix}_${timestamp}.${format}`;
}

/**
 * Upload file to Supabase Storage and return signed URL
 */
async function uploadToStorage(
  filePath: string,
  localPath: string
): Promise<string> {
  
  // Read file content
  const fileContent = await Deno.readFile(localPath);
  
  // Upload to storage
  const { data, error } = await supabase.storage
    .from('scout-platinum')
    .upload(filePath, fileContent, {
      contentType: 'application/octet-stream',
      upsert: true
    });

  if (error) {
    throw new Error(`Storage upload failed: ${error.message}`);
  }

  // Generate signed URL (valid for 1 hour)
  const { data: signedUrl } = await supabase.storage
    .from('scout-platinum')
    .createSignedUrl(filePath, 3600);

  return signedUrl?.signedUrl || '';
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const { pathname } = url;

    // Route: Export dataset to Parquet
    if (pathname === '/export' && req.method === 'POST') {
      const exportRequest: ExportRequest = await req.json();
      
      const {
        dataset,
        format = 'parquet',
        partition_by,
        date_range,
        compression = 'snappy',
        limit
      } = exportRequest;

      // Validate dataset
      if (!AVAILABLE_DATASETS[dataset]) {
        return new Response(JSON.stringify({
          error: 'Invalid dataset',
          available_datasets: Object.keys(AVAILABLE_DATASETS)
        }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Query data
      console.log(`Querying dataset: ${dataset}`);
      const data = await queryDataset(dataset, date_range, limit);
      
      if (data.length === 0) {
        return new Response(JSON.stringify({
          error: 'No data found for specified criteria'
        }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Generate file paths
      const exportId = crypto.randomUUID();
      const filePath = generateFilePath(dataset, format, partition_by);
      const localPath = `/tmp/${exportId}.${format}`;

      let fileSize = 0;
      let rowCount = data.length;

      // Export based on format
      if (format === 'parquet') {
        const config = AVAILABLE_DATASETS[dataset];
        const result = await convertToParquet(data, localPath, config.schema, compression);
        fileSize = result.file_size;
        rowCount = result.row_count;
      } else if (format === 'csv') {
        // CSV export
        const csv = [
          Object.keys(data[0]).join(','),
          ...data.map(row => Object.values(row).join(','))
        ].join('\n');
        
        await Deno.writeTextFile(localPath, csv);
        const stat = await Deno.stat(localPath);
        fileSize = stat.size;
      } else if (format === 'json') {
        // JSON export
        await Deno.writeTextFile(localPath, JSON.stringify(data, null, 2));
        const stat = await Deno.stat(localPath);
        fileSize = stat.size;
      }

      // Upload to storage
      console.log(`Uploading to storage: ${filePath}`);
      const signedUrl = await uploadToStorage(filePath, localPath);

      // Clean up local file
      try {
        await Deno.remove(localPath);
      } catch (e) {
        console.warn('Failed to cleanup local file:', e);
      }

      const result: ParquetExportResult = {
        export_id: exportId,
        file_path: filePath,
        file_size: fileSize,
        row_count: rowCount,
        schema: AVAILABLE_DATASETS[dataset].schema,
        compression: format === 'parquet' ? compression : 'none',
        created_at: new Date().toISOString(),
        signed_url: signedUrl,
      };

      return new Response(JSON.stringify(result), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: List available datasets
    if (pathname === '/datasets') {
      const datasets = Object.entries(AVAILABLE_DATASETS).map(([name, config]) => ({
        name,
        table: config.table,
        partition_column: config.partition_column,
        schema: config.schema,
        columns: Object.keys(config.schema).length,
      }));

      return new Response(JSON.stringify({ datasets }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    // Route: Health check
    if (pathname === '/health') {
      // Check if Python/PyArrow is available
      try {
        const process = new Deno.Command('python3', {
          args: ['-c', 'import pyarrow; print(pyarrow.__version__)'],
          stdout: 'piped',
          stderr: 'piped',
        });
        
        const child = process.spawn();
        const { code, stdout } = await child.status;
        
        const pyArrowVersion = code === 0 ? 
          new TextDecoder().decode(stdout).trim() : 
          'not available';

        return new Response(JSON.stringify({
          status: 'healthy',
          parquet_support: code === 0,
          pyarrow_version: pyArrowVersion,
          available_datasets: Object.keys(AVAILABLE_DATASETS).length,
          timestamp: new Date().toISOString(),
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      } catch (error) {
        return new Response(JSON.stringify({
          status: 'degraded',
          parquet_support: false,
          error: error.message,
          timestamp: new Date().toISOString(),
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }
    }

    return new Response(JSON.stringify({ error: 'Not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Parquet export error:', error);
    
    return new Response(JSON.stringify({
      error: 'Internal server error',
      message: error.message,
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});