/**
 * Scout Dataset Client
 * 
 * Production-grade client for accessing Scout datasets from Supabase Storage
 * Features:
 * - Manifest-based dataset discovery
 * - Checksum validation
 * - Caching with TTL
 * - Signed URL support
 * - Type-safe interfaces
 */

import { createClient } from "@supabase/supabase-js";
import crypto from "crypto";
import { parse } from "csv-parse/sync";

// Types
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

interface DatasetInfo {
  id: string;
  rowCount: number;
  sizeMB: number;
  lastUpdated: string;
  description?: string;
  schemaVersion: string;
}

interface CacheEntry<T> {
  data: T;
  expires: number;
}

// Error classes
export class DatasetError extends Error {
  constructor(message: string, public readonly datasetId?: string) {
    super(message);
    this.name = 'DatasetError';
  }
}

export class ChecksumError extends DatasetError {
  constructor(datasetId: string, expected: string, actual: string) {
    super(`Checksum validation failed for dataset '${datasetId}'. Expected: ${expected}, Got: ${actual}`, datasetId);
    this.name = 'ChecksumError';
  }
}

export class DatasetNotFoundError extends DatasetError {
  constructor(datasetId: string) {
    super(`Dataset '${datasetId}' not found in manifest`, datasetId);
    this.name = 'DatasetNotFoundError';
  }
}

/**
 * Production dataset client with caching, validation, and error handling
 */
export class DatasetClient {
  private supabase;
  private manifestCache: CacheEntry<DatasetManifest> | null = null;
  private datasetCache = new Map<string, CacheEntry<string>>();
  
  // Configuration
  private readonly BUCKET = "sample";
  private readonly BASE_PATH = "scout/v1";
  private readonly MANIFEST_CACHE_TTL = 5 * 60 * 1000; // 5 minutes
  private readonly DATASET_CACHE_TTL = 15 * 60 * 1000; // 15 minutes
  private readonly MAX_DATASET_SIZE = 50 * 1024 * 1024; // 50MB limit for in-memory caching

  constructor(
    supabaseUrl?: string,
    supabaseKey?: string,
    private readonly enableCache = true
  ) {
    this.supabase = createClient(
      supabaseUrl || process.env.NEXT_PUBLIC_SUPABASE_URL!,
      supabaseKey || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
    );
  }

  /**
   * Get the latest dataset manifest with caching
   */
  async getManifest(forceRefresh = false): Promise<DatasetManifest> {
    // Check cache first
    if (
      !forceRefresh &&
      this.enableCache &&
      this.manifestCache &&
      Date.now() < this.manifestCache.expires
    ) {
      return this.manifestCache.data;
    }

    try {
      const { data, error } = await this.supabase.storage
        .from(this.BUCKET)
        .download(`${this.BASE_PATH}/manifests/latest.json`);

      if (error) {
        throw new DatasetError(`Failed to fetch manifest: ${error.message}`);
      }

      const manifestJson = await data.text();
      const manifest: DatasetManifest = JSON.parse(manifestJson);

      // Validate manifest integrity
      const calculatedHash = crypto
        .createHash('sha256')
        .update(manifestJson)
        .digest('hex');

      if (manifest.integrity?.manifest_sha256 && calculatedHash !== manifest.integrity.manifest_sha256) {
        throw new ChecksumError('manifest', manifest.integrity.manifest_sha256, calculatedHash);
      }

      // Cache the manifest
      if (this.enableCache) {
        this.manifestCache = {
          data: manifest,
          expires: Date.now() + this.MANIFEST_CACHE_TTL
        };
      }

      return manifest;

    } catch (error) {
      if (error instanceof DatasetError) throw error;
      throw new DatasetError(`Failed to load manifest: ${error}`);
    }
  }

  /**
   * Get raw CSV data for a dataset with checksum validation
   */
  async getDatasetRaw(datasetId: string, validateChecksum = true): Promise<string> {
    // Check cache first
    const cacheKey = `${datasetId}:raw`;
    if (this.enableCache) {
      const cached = this.datasetCache.get(cacheKey);
      if (cached && Date.now() < cached.expires) {
        return cached.data;
      }
    }

    const manifest = await this.getManifest();
    const dataset = manifest.datasets[datasetId];
    
    if (!dataset) {
      throw new DatasetNotFoundError(datasetId);
    }

    // Check size limit for caching
    if (this.enableCache && dataset.size_bytes > this.MAX_DATASET_SIZE) {
      console.warn(`Dataset ${datasetId} (${Math.round(dataset.size_bytes / 1024 / 1024)}MB) exceeds cache limit, caching disabled`);
    }

    try {
      const key = dataset.latest_csv.replace(/^\//, '');
      const { data, error } = await this.supabase.storage
        .from(this.BUCKET)
        .download(key);

      if (error) {
        throw new DatasetError(`Failed to fetch dataset '${datasetId}': ${error.message}`, datasetId);
      }

      const csvContent = await data.text();

      // Validate checksum if requested
      if (validateChecksum) {
        const actualHash = crypto.createHash('sha256').update(csvContent).digest('hex');
        if (actualHash !== dataset.sha256) {
          throw new ChecksumError(datasetId, dataset.sha256, actualHash);
        }
      }

      // Cache if within size limits
      if (this.enableCache && dataset.size_bytes <= this.MAX_DATASET_SIZE) {
        this.datasetCache.set(cacheKey, {
          data: csvContent,
          expires: Date.now() + this.DATASET_CACHE_TTL
        });
      }

      return csvContent;

    } catch (error) {
      if (error instanceof DatasetError) throw error;
      throw new DatasetError(`Failed to load dataset '${datasetId}': ${error}`, datasetId);
    }
  }

  /**
   * Get parsed dataset as array of objects
   */
  async getDataset(datasetId: string, options: {
    validateChecksum?: boolean;
    limit?: number;
    columns?: string[];
  } = {}): Promise<Record<string, any>[]> {
    const {
      validateChecksum = true,
      limit,
      columns
    } = options;

    const csvContent = await this.getDatasetRaw(datasetId, validateChecksum);

    try {
      const rows = parse(csvContent, {
        columns: true,
        skip_empty_lines: true,
        relax_quotes: true,
        cast: (value, info) => {
          // Auto-cast numeric values
          if (typeof value === 'string' && !isNaN(Number(value)) && value.trim() !== '') {
            return Number(value);
          }
          // Auto-cast booleans
          if (typeof value === 'string') {
            const lower = value.toLowerCase();
            if (lower === 'true' || lower === 't') return true;
            if (lower === 'false' || lower === 'f') return false;
          }
          return value;
        }
      });

      let result = rows;

      // Apply column filtering
      if (columns && columns.length > 0) {
        result = rows.map(row => {
          const filtered: Record<string, any> = {};
          columns.forEach(col => {
            if (col in row) filtered[col] = row[col];
          });
          return filtered;
        });
      }

      // Apply row limit
      if (limit && limit > 0) {
        result = result.slice(0, limit);
      }

      return result;

    } catch (error) {
      throw new DatasetError(`Failed to parse CSV for dataset '${datasetId}': ${error}`, datasetId);
    }
  }

  /**
   * Get signed URL for private dataset access
   */
  async getSignedUrl(datasetId: string, expiresIn = 3600): Promise<string> {
    const manifest = await this.getManifest();
    const dataset = manifest.datasets[datasetId];
    
    if (!dataset) {
      throw new DatasetNotFoundError(datasetId);
    }

    try {
      const key = dataset.latest_csv.replace(/^\//, '');
      const { data, error } = await this.supabase.storage
        .from(this.BUCKET)
        .createSignedUrl(key, expiresIn);

      if (error) {
        throw new DatasetError(`Failed to create signed URL for '${datasetId}': ${error.message}`, datasetId);
      }

      return data.signedUrl;

    } catch (error) {
      if (error instanceof DatasetError) throw error;
      throw new DatasetError(`Failed to generate signed URL for '${datasetId}': ${error}`, datasetId);
    }
  }

  /**
   * List all available datasets with metadata
   */
  async listDatasets(): Promise<DatasetInfo[]> {
    const manifest = await this.getManifest();
    
    return Object.entries(manifest.datasets).map(([id, info]) => ({
      id,
      rowCount: info.row_count,
      sizeMB: Math.round((info.size_bytes / 1024 / 1024) * 100) / 100,
      lastUpdated: info.last_modified,
      description: info.description,
      schemaVersion: info.schema_version
    })).sort((a, b) => a.id.localeCompare(b.id));
  }

  /**
   * Get dataset metadata without downloading content
   */
  async getDatasetInfo(datasetId: string): Promise<DatasetInfo> {
    const manifest = await this.getManifest();
    const dataset = manifest.datasets[datasetId];
    
    if (!dataset) {
      throw new DatasetNotFoundError(datasetId);
    }

    return {
      id: datasetId,
      rowCount: dataset.row_count,
      sizeMB: Math.round((dataset.size_bytes / 1024 / 1024) * 100) / 100,
      lastUpdated: dataset.last_modified,
      description: dataset.description,
      schemaVersion: dataset.schema_version
    };
  }

  /**
   * Check if datasets are up-to-date
   */
  async getDatasetStatus(): Promise<{
    manifestAge: number;
    oldestDataset: string;
    newestDataset: string;
    totalDatasets: number;
    totalSizeMB: number;
  }> {
    const manifest = await this.getManifest();
    const now = Date.now();
    const manifestTime = new Date(manifest.generated_at).getTime();
    
    const datasets = Object.entries(manifest.datasets);
    const times = datasets.map(([_, info]) => new Date(info.last_modified).getTime());
    
    const oldestTime = Math.min(...times);
    const newestTime = Math.max(...times);
    
    const oldestDataset = datasets.find(([_, info]) => 
      new Date(info.last_modified).getTime() === oldestTime
    )?.[0] || '';
    
    const newestDataset = datasets.find(([_, info]) => 
      new Date(info.last_modified).getTime() === newestTime
    )?.[0] || '';

    return {
      manifestAge: Math.round((now - manifestTime) / 1000 / 60), // minutes
      oldestDataset,
      newestDataset,
      totalDatasets: manifest.total_datasets,
      totalSizeMB: Math.round((manifest.integrity.total_size_bytes / 1024 / 1024) * 100) / 100
    };
  }

  /**
   * Clear all caches
   */
  clearCache(): void {
    this.manifestCache = null;
    this.datasetCache.clear();
  }

  /**
   * Get cache statistics
   */
  getCacheStats(): {
    manifestCached: boolean;
    datasetsCached: number;
    totalCacheSize: number;
  } {
    const datasetsCached = Array.from(this.datasetCache.values()).filter(
      entry => Date.now() < entry.expires
    ).length;

    const totalCacheSize = Array.from(this.datasetCache.values()).reduce(
      (total, entry) => total + entry.data.length,
      0
    );

    return {
      manifestCached: !!(this.manifestCache && Date.now() < this.manifestCache.expires),
      datasetsCached,
      totalCacheSize
    };
  }
}

// Default client instance
export const datasetClient = new DatasetClient();

// Export types for external use
export type {
  DatasetManifest,
  DatasetMetadata,
  DatasetInfo
};