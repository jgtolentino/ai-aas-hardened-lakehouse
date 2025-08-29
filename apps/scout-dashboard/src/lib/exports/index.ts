/**
 * Export utilities for Scout Dashboard
 * Centralized exports for CSV, PNG, and PDF functionality
 */

export {
  CSVExporter,
  csvExporter,
  exportToCSV,
  exportRecommendationsToCSV,
  exportKPIsToCSV,
  exportGeoDataToCSV
} from './csvExporter';

export {
  PNGExporter,
  pngExporter,
  exportElementToPNG,
  exportChartToPNG,
  exportKPIDashboardToPNG,
  exportRecommendationPanelToPNG
} from './pngExporter';

export {
  PDFExporter,
  pdfExporter,
  exportElementToPDF,
  exportReportToPDF,
  exportKPIDashboardToPDF,
  exportRecommendationsToPDF
} from './pdfExporter';

export type {
  CSVExportOptions,
  CSVExportResult
} from './csvExporter';

export type {
  PNGExportOptions,
  PNGExportResult
} from './pngExporter';

export type {
  PDFExportOptions,
  PDFExportResult,
  PDFReportConfig
} from './pdfExporter';

// Re-export UI components
export {
  ExportButton,
  RecommendationExportButton
} from '../../components/ui/export-button';

export type {
  ExportOption
} from '../../components/ui/export-button';

// Utility function to determine best export format for data type
export const getRecommendedExportFormat = (dataType: 'table' | 'chart' | 'map' | 'kpi' | 'dashboard' | 'recommendation'): string => {
  switch (dataType) {
    case 'table':
      return 'csv';
    case 'chart':
      return 'png';
    case 'map':
      return 'png';
    case 'kpi':
      return 'pdf'; // PDF is now available
    case 'dashboard':
      return 'pdf';
    case 'recommendation':
      return 'png';
    default:
      return 'csv';
  }
};

// Common export configurations
export const EXPORT_CONFIGS = {
  recommendations: {
    csv: {
      filename: 'ai_recommendations.csv',
      includeTimestamp: true,
      headers: [
        'ID', 'Type', 'Title', 'Description', 'Confidence (%)',
        'Priority', 'Category', 'Impact Type', 'Estimated Value',
        'Timeframe', 'Last Updated', 'Data Sources'
      ]
    },
    png: {
      filename: 'ai_recommendations.png',
      includeTimestamp: true,
      backgroundColor: '#ffffff',
      padding: 40,
      scale: 2,
      watermark: {
        text: 'TBWA Scout Dashboard',
        position: 'top-right' as const,
        opacity: 0.2
      }
    },
    pdf: {
      filename: 'ai_recommendations_report.pdf',
      includeTimestamp: true,
      orientation: 'portrait' as const,
      format: 'a4' as const,
      quality: 1.0,
      watermark: {
        text: 'TBWA Scout Dashboard',
        position: 'top-right' as const,
        opacity: 0.3
      }
    }
  },
  kpis: {
    csv: {
      filename: 'kpi_summary.csv',
      includeTimestamp: true,
      dateFormat: 'local' as const
    },
    png: {
      filename: 'kpi_dashboard.png',
      includeTimestamp: true,
      backgroundColor: '#f8fafc',
      padding: 40,
      scale: 2,
      watermark: {
        text: 'TBWA Scout Dashboard',
        position: 'top-right' as const,
        opacity: 0.2
      }
    },
    pdf: {
      filename: 'kpi_dashboard_report.pdf',
      includeTimestamp: true,
      orientation: 'portrait' as const,
      format: 'a4' as const,
      quality: 1.0,
      watermark: {
        text: 'TBWA Scout Dashboard',
        position: 'top-right' as const,
        opacity: 0.3
      }
    }
  },
  charts: {
    png: {
      filename: 'chart_export.png',
      includeTimestamp: true,
      backgroundColor: '#ffffff',
      padding: 30,
      scale: 2,
      watermark: {
        text: 'Scout Analytics',
        position: 'bottom-right' as const,
        opacity: 0.3
      }
    }
  },
  geographic: {
    csv: {
      filename: 'geographic_data.csv',
      includeTimestamp: true,
      customFormatters: {
        coordinates: (coords: [number, number]) => `${coords[1]}, ${coords[0]}`
      }
    }
  }
} as const;

// PDF utility functions
export const exportElementToPDF = async (
  element: HTMLElement,
  options?: import('./pdfExporter').PDFExportOptions
) => {
  const { pdfExporter } = await import('./pdfExporter');
  return pdfExporter.exportElement(element, options);
};

export const exportReportToPDF = async (
  config: import('./pdfExporter').PDFReportConfig
) => {
  const { pdfExporter } = await import('./pdfExporter');
  return pdfExporter.generateReport(config);
};

export const exportKPIDashboardToPDF = async (
  dashboardElement: HTMLElement
) => {
  const { pdfExporter } = await import('./pdfExporter');
  return pdfExporter.exportKPIDashboard(dashboardElement);
};

export const exportRecommendationsToPDF = async (
  recommendations: any[]
) => {
  const { pdfExporter } = await import('./pdfExporter');
  return pdfExporter.exportRecommendations(recommendations);
};