#!/usr/bin/env tsx
/**
 * Scout Analytics Dataset Publisher
 * 
 * Exports Gold/Platinum tables to Supabase Storage with production-grade features:
 * - Idempotent uploads with retry/backoff
 * - Checksum validation (SHA256)
 * - Type inference for CSV columns
 * - Staging table swaps (zero-downtime)
 * - Comprehensive error handling
 * 
 * Usage:
 *   tsx scripts/publish-datasets.ts
 * 
 * Environment Variables:
 *   SUPABASE_URL - Project URL
 *   SUPABASE_SERVICE_KEY - Service role key
 *   PGURI - PostgreSQL connection string
 */

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { execSync } from "node:child_process";
import { parse } from "csv-parse/sync";
import { createClient } from "@supabase/supabase-js";

// Configuration
const supabase = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_KEY!
);

const DATE = new Date().toISOString().slice(0, 10);
const BASE_PATH = "scout/v1";
const TMP_DIR = ".tmp_datasets";
const BUCKET = "sample";
const SCHEMA = "scout_datasets";

// Ensure temp directory exists
fs.mkdirSync(TMP_DIR, { recursive: true });

// ANSI colors for logging
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  red: '\x1b[31m',
  cyan: '\x1b[36m'
};

const log = {
  info: (msg: string) => console.log(`${colors.blue}ℹ${colors.reset} ${msg}`),
  success: (msg: string) => console.log(`${colors.green}✓${colors.reset} ${msg}`),
  warning: (msg: string) => console.log(`${colors.yellow}⚠${colors.reset} ${msg}`),
  error: (msg: string) => console.log(`${colors.red}✗${colors.reset} ${msg}`),
  step: (msg: string) => console.log(`${colors.cyan}▶${colors.reset} ${msg}`)
};

// Dataset definitions
interface Dataset {
  id: string;
  sql: string;
  description?: string;
  materialize_to_db?: boolean;
}

const datasets: Dataset[] = [
  {
    id: "gold/txn_daily",
    sql: "SELECT * FROM scout.gold_txn_daily ORDER BY date_key DESC",
    description: "Daily transaction aggregates by store and region",
    materialize_to_db: true
  },
  {
    id: "gold/product_mix",
    sql: "SELECT * FROM scout.gold_product_mix ORDER BY date_key DESC, revenue DESC",
    description: "Product performance and mix analysis",
    materialize_to_db: true
  },
  {
    id: "gold/basket_patterns",
    sql: "SELECT * FROM scout.gold_basket_patterns ORDER BY support DESC",
    description: "Market basket analysis and product associations"
  },
  {
    id: "gold/substitution_flows",
    sql: "SELECT * FROM scout.gold_substitution_flows ORDER BY flow_strength DESC",
    description: "Product substitution patterns and flows"
  },
  {
    id: "gold/request_behavior",
    sql: "SELECT * FROM scout.gold_request_behavior ORDER BY date_key DESC",
    description: "Customer request and interaction patterns"
  },
  {
    id: "gold/demographics",
    sql: "SELECT * FROM scout.gold_demographics ORDER BY segment, region",
    description: "Anonymized customer demographic segments"
  },
  {
    id: "platinum/features_sales_7d",
    sql: "SELECT * FROM scout.platinum_features_sales_7d ORDER BY date_key DESC",
    description: "7-day rolling sales features for ML models",
    materialize_to_db: true
  },
  {
    id: "platinum/store_perf",
    sql: "SELECT * FROM scout.platinum_features_store_performance ORDER BY performance_score DESC",
    description: "Store performance features and rankings"
  },
  {
    id: "platinum/customer_segments",
    sql: "SELECT * FROM scout.platinum_features_customer_segments ORDER BY segment_value DESC",
    description: "ML-derived customer segmentation features"
  }
];

// Enhanced types for manifest
interface DatasetMetadata {
  latest_csv: string;
  latest_parquet?: string;
  date: string;
  row_count: number;
  sha256: string;
  size_bytes: number;
  content_type: string;
  schema_version: string;
  last_modified: string;
  description?: string;
}

interface DatasetManifest {
  generated_at: string;
  version: string;
  total_datasets: number;
  datasets: Record<string, DatasetMetadata>;
  integrity: {
    manifest_sha256: string;
    total_size_bytes: number;
  };
}

// Upload with retry and exponential backoff
async function uploadWithRetry(
  key: string,
  data: Buffer,
  contentType: string,
  maxRetries = 5
): Promise<void> {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const { error } = await supabase.storage
        .from(BUCKET)
        .upload(key, data, {
          upsert: true,
          contentType,
          cacheControl: "public, max-age=31536000, immutable"
        });

      if (!error) {
        log.success(`Uploaded: ${key}`);
        return;
      }

      if (attempt === maxRetries) {
        throw new Error(`Upload failed after ${maxRetries} attempts: ${error.message}`);
      }

      log.warning(`Upload attempt ${attempt} failed: ${error.message}`);

    } catch (error) {
      if (attempt === maxRetries) throw error;
      
      const delay = Math.min(1000 * Math.pow(2, attempt), 30000);
      log.warning(`Retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

// Generate file metadata with checksum
function getFileMetadata(filePath: string): { sha256: string; size_bytes: number } {
  const data = fs.readFileSync(filePath);
  const sha256 = crypto.createHash('sha256').update(data).digest('hex');
  const size_bytes = data.length;
  return { sha256, size_bytes };
}

// Type inference for CSV columns
function inferColumnType(values: string[]): string {
  const sampleValues = values.slice(0, 100).filter(v => v && v.trim() && v.toLowerCase() !== 'null');
  
  if (sampleValues.length === 0) return 'text';
  
  // Try boolean first
  const boolValues = sampleValues.filter(v => 
    ['true', 'false', 't', 'f', '1', '0', 'yes', 'no'].includes(v.toLowerCase())
  );
  if (boolValues.length === sampleValues.length) return 'boolean';
  
  // Try numeric
  const numericValues = sampleValues.filter(v => !isNaN(Number(v)) && v.trim() !== '');
  if (numericValues.length === sampleValues.length) {
    const hasDecimals = numericValues.some(v => v.includes('.'));
    const hasLargeNumbers = numericValues.some(v => Math.abs(Number(v)) > 2147483647);
    
    if (hasDecimals) return 'numeric(15,4)';
    if (hasLargeNumbers) return 'bigint';
    return 'integer';
  }
  
  // Try timestamp
  const dateValues = sampleValues.filter(v => {
    const parsed = new Date(v);
    return !isNaN(parsed.getTime()) && v.length >= 8;
  });
  if (dateValues.length === sampleValues.length) {
    return 'timestamptz';
  }
  
  // Try UUID
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const uuidValues = sampleValues.filter(v => uuidPattern.test(v));
  if (uuidValues.length === sampleValues.length) return 'uuid';
  
  // Default to text with appropriate length
  const maxLength = Math.max(...sampleValues.map(v => v.length));
  if (maxLength <= 255) return 'varchar(255)';
  return 'text';
}

// Create typed table from CSV with staging swap
async function materializeToDatabase(csvPath: string, datasetId: string, description?: string): Promise<void> {
  const tableName = datasetId.replace('/', '_');
  const stagingTable = `${tableName}_staging`;
  
  log.step(`Creating typed table: ${SCHEMA}.${tableName}`);
  
  // Read and parse CSV for type inference
  const csvContent = fs.readFileSync(csvPath, 'utf8');
  const rows = parse(csvContent, { 
    columns: true, 
    skip_empty_lines: true,
    relax_quotes: true
  });
  
  if (rows.length === 0) {
    log.warning(`No data in ${datasetId}, skipping table creation`);
    return;
  }
  
  // Infer column types
  const columns = Object.keys(rows[0]);
  const columnDefs: string[] = [];
  
  for (const col of columns) {
    const values = rows.map(row => String(row[col] || ''));
    const colType = inferColumnType(values);
    columnDefs.push(`"${col}" ${colType}`);
  }
  
  // Create staging table
  const createSQL = `
    CREATE SCHEMA IF NOT EXISTS ${SCHEMA};
    DROP TABLE IF EXISTS ${SCHEMA}.${stagingTable};
    CREATE TABLE ${SCHEMA}.${stagingTable} (
      ${columnDefs.join(',\n      ')}
    );
  `;
  
  try {
    execSync(`psql "${process.env.PGURI}" -c "${createSQL.replace(/"/g, '\\"')}"`, { stdio: 'inherit' });
    
    // Load data with proper CSV handling
    execSync(`psql "${process.env.PGURI}" -c "\\copy ${SCHEMA}.${stagingTable} FROM '${csvPath}' WITH (FORMAT CSV, HEADER TRUE, QUOTE '\"', ESCAPE '\"', NULL '')"`, { stdio: 'inherit' });
    
    // Add metadata
    if (description) {
      execSync(`psql "${process.env.PGURI}" -c "COMMENT ON TABLE ${SCHEMA}.${stagingTable} IS '${description}'"`, { stdio: 'inherit' });
    }
    
    // Atomic swap
    const swapSQL = `
      BEGIN;
        DROP TABLE IF EXISTS ${SCHEMA}.${tableName}_backup;
        ALTER TABLE IF EXISTS ${SCHEMA}.${tableName} RENAME TO ${tableName}_backup;
        ALTER TABLE ${SCHEMA}.${stagingTable} RENAME TO ${tableName};
        DROP TABLE IF EXISTS ${SCHEMA}.${tableName}_backup;
      COMMIT;
    `;
    
    execSync(`psql "${process.env.PGURI}" -c "${swapSQL.replace(/"/g, '\\"')}"`, { stdio: 'inherit' });
    
    log.success(`Table created: ${SCHEMA}.${tableName} (${rows.length} rows)`);
    
  } catch (error) {
    log.error(`Failed to create table ${tableName}: ${error}`);
    throw error;
  }
}

// Export dataset to CSV
async function exportDataset(dataset: Dataset): Promise<{
  csvPath: string;
  rowCount: number;
}> {
  const safeName = dataset.id.replace('/', '_');
  const csvPath = path.join(TMP_DIR, `${safeName}_${DATE}.csv`);
  
  log.step(`Exporting: ${dataset.id}`);
  
  try {
    // Export with proper CSV formatting
    const copyCommand = `\\copy (${dataset.sql}) TO '${csvPath}' WITH (FORMAT CSV, HEADER TRUE, QUOTE '"', ESCAPE '"', NULL '')`;
    execSync(`psql "${process.env.PGURI}" -c "${copyCommand}"`, { stdio: 'inherit' });
    
    // Count rows
    const csvContent = fs.readFileSync(csvPath, 'utf8');
    const rows = parse(csvContent, { columns: true, skip_empty_lines: true });
    const rowCount = rows.length;
    
    log.success(`Exported ${rowCount} rows to ${csvPath}`);
    
    return { csvPath, rowCount };
    
  } catch (error) {
    log.error(`Failed to export ${dataset.id}: ${error}`);
    throw error;
  }
}

// Main execution
async function main(): Promise<void> {
  console.log(`${colors.cyan}🚀 Scout Dataset Publisher${colors.reset}`);
  console.log(`Publishing datasets to ${BUCKET}/${BASE_PATH}`);
  console.log(`Date: ${DATE}\n`);
  
  const manifest: DatasetManifest = {
    generated_at: new Date().toISOString(),
    version: "1.0.0",
    total_datasets: datasets.length,
    datasets: {},
    integrity: {
      manifest_sha256: "",
      total_size_bytes: 0
    }
  };
  
  let totalSize = 0;
  
  for (const dataset of datasets) {
    try {
      // Export to CSV
      const { csvPath, rowCount } = await exportDataset(dataset);
      
      // Get file metadata
      const { sha256, size_bytes } = getFileMetadata(csvPath);
      totalSize += size_bytes;
      
      // Upload to storage
      const csvKey = `${BASE_PATH}/${dataset.id}_${DATE}.csv`;
      const csvData = fs.readFileSync(csvPath);
      await uploadWithRetry(csvKey, csvData, "text/csv");
      
      // Materialize to database if requested
      if (dataset.materialize_to_db) {
        await materializeToDatabase(csvPath, dataset.id, dataset.description);
      }
      
      // Update manifest
      manifest.datasets[dataset.id] = {
        latest_csv: `/${csvKey}`,
        date: DATE,
        row_count: rowCount,
        sha256,
        size_bytes,
        content_type: "text/csv",
        schema_version: "1.0.0",
        last_modified: new Date().toISOString(),
        description: dataset.description
      };
      
      log.success(`Completed: ${dataset.id} (${rowCount} rows, ${(size_bytes / 1024 / 1024).toFixed(2)}MB)`);
      
    } catch (error) {
      log.error(`Failed to process ${dataset.id}: ${error}`);
      throw error;
    }
  }
  
  // Calculate manifest integrity
  manifest.integrity.total_size_bytes = totalSize;
  const manifestJson = JSON.stringify(manifest, null, 2);
  manifest.integrity.manifest_sha256 = crypto.createHash('sha256').update(manifestJson).digest('hex');
  
  // Upload manifest
  const finalManifestJson = JSON.stringify(manifest, null, 2);
  await uploadWithRetry(
    `${BASE_PATH}/manifests/latest.json`,
    Buffer.from(finalManifestJson),
    "application/json"
  );
  
  // Cleanup
  fs.rmSync(TMP_DIR, { recursive: true, force: true });
  
  console.log(`\n${colors.green}✅ Dataset publishing complete!${colors.reset}`);
  console.log(`📊 Published ${datasets.length} datasets`);
  console.log(`💾 Total size: ${(totalSize / 1024 / 1024).toFixed(2)}MB`);
  console.log(`🔗 Manifest: ${BUCKET}/${BASE_PATH}/manifests/latest.json`);
  console.log(`🕐 Generated at: ${manifest.generated_at}`);
}

// Error handling and execution
if (require.main === module) {
  // Validate environment
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_KEY || !process.env.PGURI) {
    log.error("Missing required environment variables:");
    log.error("- SUPABASE_URL");
    log.error("- SUPABASE_SERVICE_KEY"); 
    log.error("- PGURI");
    process.exit(1);
  }
  
  main().catch((error) => {
    log.error(`Dataset publishing failed: ${error.message}`);
    console.error(error);
    process.exit(1);
  });
}