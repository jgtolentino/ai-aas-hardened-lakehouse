/**
 * CSV Export Utility
 * Handles conversion of various data types to CSV format with customization options
 */

export interface CSVExportOptions {
  filename?: string;
  headers?: string[];
  delimiter?: string;
  includeTimestamp?: boolean;
  dateFormat?: 'iso' | 'local' | 'short';
  booleanFormat?: 'true/false' | 'yes/no' | '1/0';
  nullValue?: string;
  customFormatters?: Record<string, (value: any) => string>;
}

export interface CSVExportResult {
  success: boolean;
  filename: string;
  rowCount: number;
  error?: string;
}

export class CSVExporter {
  private options: Required<CSVExportOptions>;

  constructor(options: CSVExportOptions = {}) {
    this.options = {
      filename: options.filename || `export_${new Date().toISOString().split('T')[0]}.csv`,
      headers: options.headers || [],
      delimiter: options.delimiter || ',',
      includeTimestamp: options.includeTimestamp ?? true,
      dateFormat: options.dateFormat || 'iso',
      booleanFormat: options.booleanFormat || 'true/false',
      nullValue: options.nullValue || '',
      customFormatters: options.customFormatters || {}
    };
  }

  /**
   * Export array of objects to CSV
   */
  async exportData<T extends Record<string, any>>(
    data: T[],
    customOptions: Partial<CSVExportOptions> = {}
  ): Promise<CSVExportResult> {
    try {
      if (!data || data.length === 0) {
        throw new Error('No data to export');
      }

      // Merge options
      const options = { ...this.options, ...customOptions };
      
      // Extract headers
      const headers = options.headers.length > 0 
        ? options.headers 
        : this.extractHeaders(data[0]);

      // Add timestamp to filename if requested
      const filename = options.includeTimestamp && !customOptions.filename
        ? this.addTimestampToFilename(options.filename)
        : options.filename;

      // Convert data to CSV string
      const csvContent = this.convertToCSV(data, headers, options);

      // Download the file
      this.downloadCSV(csvContent, filename);

      return {
        success: true,
        filename,
        rowCount: data.length
      };
    } catch (error) {
      return {
        success: false,
        filename: '',
        rowCount: 0,
        error: error instanceof Error ? error.message : 'Export failed'
      };
    }
  }

  /**
   * Export table recommendations data
   */
  async exportRecommendations(
    recommendations: Array<{
      id: string;
      type: string;
      title: string;
      description: string;
      confidence: number;
      priority: string;
      category: string;
      impact: {
        type: string;
        estimated_value?: number;
        timeframe?: string;
      };
      metadata?: {
        last_updated?: string;
        data_sources?: string[];
      };
    }>
  ): Promise<CSVExportResult> {
    const transformedData = recommendations.map(rec => ({
      ID: rec.id,
      Type: rec.type,
      Title: rec.title,
      Description: rec.description,
      'Confidence (%)': rec.confidence,
      Priority: rec.priority,
      Category: rec.category,
      'Impact Type': rec.impact.type.replace('_', ' '),
      'Estimated Value': rec.impact.estimated_value || '',
      Timeframe: rec.impact.timeframe || '',
      'Last Updated': rec.metadata?.last_updated 
        ? new Date(rec.metadata.last_updated).toLocaleDateString()
        : '',
      'Data Sources': rec.metadata?.data_sources?.join('; ') || ''
    }));

    return this.exportData(transformedData, {
      filename: 'ai_recommendations.csv',
      headers: [
        'ID', 'Type', 'Title', 'Description', 'Confidence (%)',
        'Priority', 'Category', 'Impact Type', 'Estimated Value',
        'Timeframe', 'Last Updated', 'Data Sources'
      ]
    });
  }

  /**
   * Export KPI summary data
   */
  async exportKPISummary(
    kpis: Array<{
      metric: string;
      value: number | string;
      change?: number;
      trend?: 'up' | 'down' | 'stable';
      target?: number;
      unit?: string;
    }>
  ): Promise<CSVExportResult> {
    const transformedData = kpis.map(kpi => ({
      Metric: kpi.metric,
      Value: kpi.value,
      Change: kpi.change ? `${kpi.change > 0 ? '+' : ''}${kpi.change}%` : '',
      Trend: kpi.trend || '',
      Target: kpi.target || '',
      Unit: kpi.unit || '',
      'Performance vs Target': kpi.target && typeof kpi.value === 'number' 
        ? `${((kpi.value / kpi.target) * 100).toFixed(1)}%`
        : ''
    }));

    return this.exportData(transformedData, {
      filename: 'kpi_summary.csv'
    });
  }

  /**
   * Export geographic data
   */
  async exportGeoData(
    geoData: Array<{
      region?: string;
      province?: string;
      city?: string;
      barangay?: string;
      metric: string;
      value: number;
      coordinates?: [number, number];
    }>
  ): Promise<CSVExportResult> {
    const transformedData = geoData.map(item => ({
      Region: item.region || '',
      Province: item.province || '',
      City: item.city || '',
      Barangay: item.barangay || '',
      Metric: item.metric,
      Value: item.value,
      Latitude: item.coordinates?.[1] || '',
      Longitude: item.coordinates?.[0] || ''
    }));

    return this.exportData(transformedData, {
      filename: 'geographic_data.csv'
    });
  }

  private extractHeaders(obj: Record<string, any>): string[] {
    return Object.keys(obj);
  }

  private addTimestampToFilename(filename: string): string {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').split('T')[0];
    const ext = filename.split('.').pop();
    const name = filename.replace(`.${ext}`, '');
    return `${name}_${timestamp}.${ext}`;
  }

  private convertToCSV<T extends Record<string, any>>(
    data: T[],
    headers: string[],
    options: Required<CSVExportOptions>
  ): string {
    // Create header row
    const headerRow = headers.map(h => this.escapeCSVValue(h, options.delimiter)).join(options.delimiter);
    
    // Create data rows
    const dataRows = data.map(row => {
      return headers.map(header => {
        const value = row[header];
        const formattedValue = this.formatValue(value, header, options);
        return this.escapeCSVValue(formattedValue, options.delimiter);
      }).join(options.delimiter);
    });

    return [headerRow, ...dataRows].join('\n');
  }

  private formatValue(
    value: any, 
    header: string, 
    options: Required<CSVExportOptions>
  ): string {
    // Check for custom formatter
    if (options.customFormatters[header]) {
      return options.customFormatters[header](value);
    }

    // Handle null/undefined
    if (value === null || value === undefined) {
      return options.nullValue;
    }

    // Handle dates
    if (value instanceof Date || (typeof value === 'string' && !isNaN(Date.parse(value)))) {
      const date = new Date(value);
      switch (options.dateFormat) {
        case 'local':
          return date.toLocaleDateString();
        case 'short':
          return date.toLocaleDateString('en-US', { 
            year: '2-digit', 
            month: '2-digit', 
            day: '2-digit' 
          });
        default:
          return date.toISOString();
      }
    }

    // Handle booleans
    if (typeof value === 'boolean') {
      switch (options.booleanFormat) {
        case 'yes/no':
          return value ? 'Yes' : 'No';
        case '1/0':
          return value ? '1' : '0';
        default:
          return value ? 'true' : 'false';
      }
    }

    // Handle arrays
    if (Array.isArray(value)) {
      return value.join('; ');
    }

    // Handle objects
    if (typeof value === 'object') {
      return JSON.stringify(value);
    }

    return String(value);
  }

  private escapeCSVValue(value: string, delimiter: string): string {
    // If value contains delimiter, newlines, or quotes, wrap in quotes
    if (value.includes(delimiter) || value.includes('\n') || value.includes('\r') || value.includes('"')) {
      // Escape existing quotes by doubling them
      const escaped = value.replace(/"/g, '""');
      return `"${escaped}"`;
    }
    return value;
  }

  private downloadCSV(content: string, filename: string): void {
    // Create blob with BOM for proper Excel handling
    const BOM = '\uFEFF';
    const blob = new Blob([BOM + content], { type: 'text/csv;charset=utf-8;' });
    
    // Create download link
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    
    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    link.style.visibility = 'hidden';
    
    // Trigger download
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    
    // Clean up
    URL.revokeObjectURL(url);
  }
}

// Default instance
export const csvExporter = new CSVExporter();

// Utility functions
export const exportToCSV = <T extends Record<string, any>>(
  data: T[],
  options?: CSVExportOptions
): Promise<CSVExportResult> => {
  return csvExporter.exportData(data, options);
};

export const exportRecommendationsToCSV = (
  recommendations: Parameters<CSVExporter['exportRecommendations']>[0]
): Promise<CSVExportResult> => {
  return csvExporter.exportRecommendations(recommendations);
};

export const exportKPIsToCSV = (
  kpis: Parameters<CSVExporter['exportKPISummary']>[0]
): Promise<CSVExportResult> => {
  return csvExporter.exportKPISummary(kpis);
};

export const exportGeoDataToCSV = (
  geoData: Parameters<CSVExporter['exportGeoData']>[0]
): Promise<CSVExportResult> => {
  return csvExporter.exportGeoData(geoData);
};