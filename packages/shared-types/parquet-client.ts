/**
 * Parquet Export Client
 * 
 * TypeScript client for requesting and managing Parquet exports
 * from the Scout Analytics platform.
 */

export interface ParquetExportRequest {
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

export interface ParquetExportResult {
  export_id: string;
  file_path: string;
  file_size: number;
  row_count: number;
  schema: Record<string, string>;
  compression: string;
  created_at: string;
  signed_url?: string;
}

export interface DatasetInfo {
  name: string;
  table: string;
  partition_column: string;
  schema: Record<string, string>;
  columns: number;
}

export interface ParquetClientConfig {
  functionUrl: string;
  apiKey: string;
  timeout?: number;
}

export class ParquetExportClient {
  private config: ParquetClientConfig;
  private headers: Headers;

  constructor(config: ParquetClientConfig) {
    this.config = config;
    this.headers = new Headers({
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${config.apiKey}`,
    });
  }

  /**
   * Request a new Parquet export
   */
  async requestExport(request: ParquetExportRequest): Promise<ParquetExportResult> {
    const response = await fetch(`${this.config.functionUrl}/export`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify(request),
      signal: AbortSignal.timeout(this.config.timeout || 300000), // 5 minutes default
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(`Export failed: ${error.error || response.statusText}`);
    }

    return response.json();
  }

  /**
   * List available datasets for export
   */
  async listDatasets(): Promise<DatasetInfo[]> {
    const response = await fetch(`${this.config.functionUrl}/datasets`, {
      method: 'GET',
      headers: this.headers,
    });

    if (!response.ok) {
      throw new Error(`Failed to list datasets: ${response.statusText}`);
    }

    const result = await response.json();
    return result.datasets;
  }

  /**
   * Check service health and Parquet support
   */
  async checkHealth(): Promise<{
    status: string;
    parquet_support: boolean;
    pyarrow_version?: string;
    available_datasets: number;
    timestamp: string;
  }> {
    const response = await fetch(`${this.config.functionUrl}/health`, {
      method: 'GET',
      headers: this.headers,
    });

    if (!response.ok) {
      throw new Error(`Health check failed: ${response.statusText}`);
    }

    return response.json();
  }

  /**
   * Download a file from a signed URL
   */
  async downloadFile(signedUrl: string, outputPath?: string): Promise<Blob | void> {
    const response = await fetch(signedUrl);
    
    if (!response.ok) {
      throw new Error(`Download failed: ${response.statusText}`);
    }

    const blob = await response.blob();

    if (outputPath && typeof Deno !== 'undefined') {
      // Deno environment - write to file
      const arrayBuffer = await blob.arrayBuffer();
      await Deno.writeFile(outputPath, new Uint8Array(arrayBuffer));
      return;
    }

    return blob;
  }

  /**
   * Convenience method for exporting daily transactions
   */
  async exportDailyTransactions(
    dateRange: { start: string; end: string },
    format: 'parquet' | 'csv' = 'parquet'
  ): Promise<ParquetExportResult> {
    return this.requestExport({
      dataset: 'daily_transactions',
      format,
      date_range: dateRange,
      partition_by: 'transaction_date',
      compression: 'snappy',
    });
  }

  /**
   * Convenience method for exporting store features (ML data)
   */
  async exportStoreFeatures(
    region?: string,
    format: 'parquet' | 'csv' = 'parquet'
  ): Promise<ParquetExportResult> {
    const request: ParquetExportRequest = {
      dataset: 'store_features',
      format,
      compression: 'snappy',
    };

    if (region) {
      request.partition_by = 'region';
    }

    return this.requestExport(request);
  }

  /**
   * Convenience method for exporting store rankings
   */
  async exportStoreRankings(
    region?: string,
    format: 'parquet' | 'csv' = 'parquet'
  ): Promise<ParquetExportResult> {
    const request: ParquetExportRequest = {
      dataset: 'store_rankings',
      format,
      compression: 'snappy',
    };

    if (region) {
      request.partition_by = 'region';
    }

    return this.requestExport(request);
  }

  /**
   * Bulk export multiple datasets
   */
  async bulkExport(
    datasets: string[],
    options: Partial<ParquetExportRequest> = {}
  ): Promise<ParquetExportResult[]> {
    const promises = datasets.map(dataset =>
      this.requestExport({
        dataset,
        format: 'parquet',
        compression: 'snappy',
        ...options,
      })
    );

    return Promise.all(promises);
  }

  /**
   * Get file size estimate before export
   */
  async estimateExportSize(dataset: string, limit?: number): Promise<number> {
    // First get a small sample to estimate row size
    const sample = await this.requestExport({
      dataset,
      format: 'json',
      limit: limit || 100,
    });

    // Estimate based on sample
    const avgRowSize = sample.file_size / sample.row_count;
    
    // For Parquet, compression ratio is typically 3-5x better than JSON
    const parquetCompressionRatio = 0.25;
    
    return Math.ceil(avgRowSize * (limit || 10000) * parquetCompressionRatio);
  }

  /**
   * Update client configuration
   */
  updateConfig(newConfig: Partial<ParquetClientConfig>): void {
    this.config = { ...this.config, ...newConfig };
    
    if (newConfig.apiKey) {
      this.headers.set('Authorization', `Bearer ${newConfig.apiKey}`);
    }
  }
}

/**
 * Configuration constants
 */
export const ParquetConfig = {
  // Available datasets
  DATASETS: {
    DAILY_TRANSACTIONS: 'daily_transactions',
    STORE_RANKINGS: 'store_rankings',
    HOURLY_PATTERNS: 'hourly_patterns',
    PAYMENT_TRENDS: 'payment_trends',
    STORE_FEATURES: 'store_features',
    ML_PREDICTIONS: 'ml_predictions',
  },

  // Compression options
  COMPRESSION: {
    SNAPPY: 'snappy' as const,
    GZIP: 'gzip' as const,
    LZ4: 'lz4' as const,
    BROTLI: 'brotli' as const,
  },

  // Format options
  FORMATS: {
    PARQUET: 'parquet' as const,
    CSV: 'csv' as const,
    JSON: 'json' as const,
  },

  // Environment URLs
  FUNCTION_URLS: {
    development: 'http://localhost:54321/functions/v1/export-parquet',
    staging: 'https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/export-parquet',
    production: 'https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/export-parquet',
  },

  // Date range presets
  DATE_RANGES: {
    LAST_7_DAYS: () => ({
      start: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
      end: new Date().toISOString().split('T')[0],
    }),
    LAST_30_DAYS: () => ({
      start: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
      end: new Date().toISOString().split('T')[0],
    }),
    THIS_MONTH: () => {
      const now = new Date();
      const start = new Date(now.getFullYear(), now.getMonth(), 1);
      return {
        start: start.toISOString().split('T')[0],
        end: new Date().toISOString().split('T')[0],
      };
    },
  },
};

/**
 * Factory function for creating a Parquet client
 */
export const createParquetClient = (
  environment: 'development' | 'staging' | 'production' = 'production',
  apiKey: string,
  timeout?: number
): ParquetExportClient => {
  return new ParquetExportClient({
    functionUrl: ParquetConfig.FUNCTION_URLS[environment],
    apiKey,
    timeout,
  });
};

/**
 * React Hook for Parquet exports (to be implemented in React apps)
 */
export interface UseParquetExports {
  client: ParquetExportClient;
  datasets: DatasetInfo[] | null;
  loading: boolean;
  error: string | null;
  requestExport: (request: ParquetExportRequest) => Promise<ParquetExportResult>;
  downloadFile: (signedUrl: string) => Promise<Blob>;
  refetch: () => Promise<void>;
}

// Export a hook factory for React applications
export const createParquetHook = (client: ParquetExportClient) => {
  return (): UseParquetExports => {
    // This would be implemented in React applications using useState/useEffect
    throw new Error('useParquetExports hook should be implemented in React apps');
  };
};