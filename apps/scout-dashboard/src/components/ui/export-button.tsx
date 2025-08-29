import React, { useState } from 'react';
import { Button } from './button';
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger, DropdownMenuSeparator } from './dropdown-menu';
import { Download, FileSpreadsheet, FileImage, FileText, Loader2, Check, AlertCircle } from 'lucide-react';
import { CSVExportOptions, CSVExportResult } from '@/lib/exports/csvExporter';
import { PNGExportOptions, PNGExportResult } from '@/lib/exports/pngExporter';
import { PDFExportResult } from '@/lib/exports/pdfExporter';
import { cn } from '@/lib/utils';
import { useExportWithProgress } from '@/hooks/useProgressTracking';
import { ExportProgressOverlay } from './progress-indicator';

export interface ExportOption {
  type: 'csv' | 'png' | 'pdf';
  label: string;
  icon: React.ReactNode;
  handler: () => Promise<any>;
  disabled?: boolean;
}

interface ExportButtonProps {
  data?: any[];
  className?: string;
  variant?: 'default' | 'outline' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  csvOptions?: CSVExportOptions;
  pngOptions?: PNGExportOptions & {
    targetSelector?: string; // CSS selector for element to capture
    targetElement?: HTMLElement; // Direct element reference
  };
  showDropdown?: boolean;
  showProgressModal?: boolean; // Show progress in modal overlay
  allowCancel?: boolean; // Allow canceling exports
  onExportStart?: (type: string) => void;
  onExportComplete?: (type: string, result: any) => void;
  onExportError?: (type: string, error: string) => void;
}

export const ExportButton: React.FC<ExportButtonProps> = ({
  data = [],
  className,
  variant = 'outline',
  size = 'sm',
  csvOptions,
  pngOptions,
  showDropdown = true,
  showProgressModal = false,
  allowCancel = true,
  onExportStart,
  onExportComplete,
  onExportError,
}) => {
  const [isExporting, setIsExporting] = useState(false);
  const [exportStatus, setExportStatus] = useState<{
    type: string;
    status: 'idle' | 'loading' | 'success' | 'error';
    message?: string;
  }>({ type: '', status: 'idle' });

  // Initialize progress tracking
  const {
    executeExport,
    modalProgress,
    closeModal,
    cancelProgress
  } = useExportWithProgress({
    showModal: showProgressModal,
    allowCancel,
    onComplete: (progress) => {
      setExportStatus({
        type: progress.type,
        status: 'success',
        message: `${progress.fileName} exported successfully`
      });
      onExportComplete?.(progress.type, { fileName: progress.fileName });
      
      // Clear success status after 3 seconds
      setTimeout(() => {
        setExportStatus({ type: '', status: 'idle' });
      }, 3000);
    },
    onError: (error, progress) => {
      setExportStatus({
        type: progress.type,
        status: 'error',
        message: error
      });
      onExportError?.(progress.type, error);
      
      // Clear error status after 5 seconds
      setTimeout(() => {
        setExportStatus({ type: '', status: 'idle' });
      }, 5000);
    },
    onCancel: (progress) => {
      setExportStatus({ type: '', status: 'idle' });
    }
  });

  const handleExport = async (type: string, exportHandler: () => Promise<any>) => {
    try {
      setIsExporting(true);
      setExportStatus({ type, status: 'loading' });
      onExportStart?.(type);

      // Generate filename
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-').split('T')[0];
      const fileName = `export_${type}_${timestamp}`;

      // Use progress tracking for export
      const result = await executeExport(
        type as 'csv' | 'png' | 'pdf',
        exportHandler,
        fileName
      );

      if (result?.success === false) {
        throw new Error(result.error || 'Export failed');
      }

      return result;

    } catch (error) {
      // Error handling is now managed by the progress tracking hook
      throw error;
    } finally {
      setIsExporting(false);
    }
  };

  const handleCSVExport = async () => {
    if (!data || data.length === 0) {
      throw new Error('No data available to export');
    }

    const { csvExporter } = await import('@/lib/exports/csvExporter');
    return csvExporter.exportData(data, csvOptions);
  };

  const handlePNGExport = async (): Promise<PNGExportResult> => {
    const { pngExporter } = await import('@/lib/exports/pngExporter');

    // Determine target element
    let targetElement: HTMLElement | null = null;

    if (pngOptions?.targetElement) {
      targetElement = pngOptions.targetElement;
    } else if (pngOptions?.targetSelector) {
      targetElement = document.querySelector(pngOptions.targetSelector) as HTMLElement;
    } else {
      // Default to capturing the closest container
      const button = document.activeElement as HTMLElement;
      const container = button?.closest('[data-export-container]') as HTMLElement ||
                       button?.closest('[role="main"]') as HTMLElement ||
                       button?.closest('.card') as HTMLElement ||
                       document.body;
      targetElement = container;
    }

    if (!targetElement) {
      throw new Error('No target element found for PNG export');
    }

    return pngExporter.exportElement(targetElement, pngOptions);
  };

  const handlePDFExport = async (): Promise<PDFExportResult> => {
    const { pdfExporter } = await import('@/lib/exports/pdfExporter');

    // Determine target element for PDF export (similar to PNG logic)
    let targetElement: HTMLElement | null = null;

    if (pngOptions?.targetElement) {
      targetElement = pngOptions.targetElement;
    } else if (pngOptions?.targetSelector) {
      targetElement = document.querySelector(pngOptions.targetSelector) as HTMLElement;
    } else {
      // Default to capturing the closest container
      const button = document.activeElement as HTMLElement;
      const container = button?.closest('[data-export-container]') as HTMLElement ||
                       button?.closest('[role="main"]') as HTMLElement ||
                       button?.closest('.card') as HTMLElement ||
                       document.body;
      targetElement = container;
    }

    if (!targetElement) {
      throw new Error('No target element found for PDF export');
    }

    // For table data, use the report generation feature
    if (data && data.length > 0) {
      return pdfExporter.generateReport({
        title: 'Data Export Report',
        subtitle: 'Generated from Scout Dashboard',
        sections: [
          {
            title: 'Data Summary',
            type: 'table',
            content: data.slice(0, 50), // Limit to 50 rows for PDF
            tableOptions: {
              headers: Object.keys(data[0] || {}),
              maxRows: 50
            }
          }
        ],
        metadata: {
          generatedAt: new Date(),
          totalRecords: data.length,
          exportedRecords: Math.min(data.length, 50)
        }
      });
    } else {
      // For visual elements, use element export
      return pdfExporter.exportElement(targetElement, {
        filename: 'dashboard_export.pdf',
        includeTimestamp: true
      });
    }
  };

  const exportOptions: ExportOption[] = [
    {
      type: 'csv',
      label: 'Export as CSV',
      icon: <FileSpreadsheet className="h-4 w-4" />,
      handler: handleCSVExport,
      disabled: !data || data.length === 0
    },
    {
      type: 'png',
      label: 'Export as PNG',
      icon: <FileImage className="h-4 w-4" />,
      handler: handlePNGExport,
      disabled: false
    },
    {
      type: 'pdf',
      label: 'Export as PDF',
      icon: <FileText className="h-4 w-4" />,
      handler: handlePDFExport,
      disabled: false
    }
  ];

  const getButtonIcon = () => {
    if (exportStatus.status === 'loading') {
      return <Loader2 className="h-4 w-4 animate-spin" />;
    }
    if (exportStatus.status === 'success') {
      return <Check className="h-4 w-4 text-green-600" />;
    }
    if (exportStatus.status === 'error') {
      return <AlertCircle className="h-4 w-4 text-red-600" />;
    }
    return <Download className="h-4 w-4" />;
  };

  const getButtonText = () => {
    if (exportStatus.status === 'loading') {
      return 'Exporting...';
    }
    if (exportStatus.status === 'success') {
      return 'Exported!';
    }
    if (exportStatus.status === 'error') {
      return 'Export Failed';
    }
    return 'Export';
  };

  if (!showDropdown) {
    // Simple CSV export button
    return (
      <>
        <Button
          variant={variant}
          size={size}
          className={cn(
            'gap-2',
            exportStatus.status === 'success' && 'border-green-500 text-green-700',
            exportStatus.status === 'error' && 'border-red-500 text-red-700',
            className
          )}
          disabled={isExporting || !data || data.length === 0}
          onClick={() => handleExport('csv', handleCSVExport)}
          title={exportStatus.message}
        >
          {getButtonIcon()}
          {getButtonText()}
        </Button>

        {/* Progress Overlay */}
        {modalProgress && (
          <ExportProgressOverlay
            isVisible={true}
            exportType={modalProgress.type}
            fileName={modalProgress.fileName}
            progress={modalProgress.overallProgress}
            currentStep={modalProgress.steps.find(s => s.status === 'running')?.label || 'Processing...'}
            onCancel={allowCancel ? () => cancelProgress(modalProgress.jobId) : undefined}
            onClose={closeModal}
          />
        )}
      </>
    );
  }

  // Dropdown with multiple export options
  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            variant={variant}
            size={size}
            className={cn(
              'gap-2',
              exportStatus.status === 'success' && 'border-green-500 text-green-700',
              exportStatus.status === 'error' && 'border-red-500 text-red-700',
              className
            )}
            disabled={isExporting}
            title={exportStatus.message}
          >
            {getButtonIcon()}
            {getButtonText()}
          </Button>
        </DropdownMenuTrigger>
        
        <DropdownMenuContent align="end" className="w-48">
          {exportOptions.map((option) => (
            <DropdownMenuItem
              key={option.type}
              className="gap-2 cursor-pointer"
              disabled={option.disabled || isExporting}
              onClick={() => handleExport(option.type, option.handler)}
            >
              {option.icon}
              <span>{option.label}</span>
              {option.disabled && option.type !== 'csv' && option.type !== 'png' && option.type !== 'pdf' && (
                <span className="text-xs text-gray-500 ml-auto">Coming Soon</span>
              )}
            </DropdownMenuItem>
          ))}
          
          {data && data.length > 0 && (
            <>
              <DropdownMenuSeparator />
              <div className="px-2 py-1.5 text-xs text-gray-500">
                {data.length} records available
              </div>
            </>
          )}
        </DropdownMenuContent>
      </DropdownMenu>

      {/* Progress Overlay */}
      {modalProgress && (
        <ExportProgressOverlay
          isVisible={true}
          exportType={modalProgress.type}
          fileName={modalProgress.fileName}
          progress={modalProgress.overallProgress}
          currentStep={modalProgress.steps.find(s => s.status === 'running')?.label || 'Processing...'}
          onCancel={allowCancel ? () => cancelProgress(modalProgress.jobId) : undefined}
          onClose={closeModal}
        />
      )}
    </>
  );
};

// Specialized export button for recommendations
interface RecommendationExportButtonProps {
  recommendations: Array<{
    id: string;
    type: string;
    title: string;
    description: string;
    confidence: number;
    priority: string;
    category: string;
    impact: any;
    metadata?: any;
  }>;
  className?: string;
  enablePNGExport?: boolean;
  enablePDFExport?: boolean;
  pngTargetSelector?: string;
  showProgressModal?: boolean;
  allowCancel?: boolean;
}

export const RecommendationExportButton: React.FC<RecommendationExportButtonProps> = ({
  recommendations,
  className,
  enablePNGExport = false,
  enablePDFExport = false,
  pngTargetSelector = '.recommendation-panel',
  showProgressModal = false,
  allowCancel = true
}) => {
  const [isExporting, setIsExporting] = useState(false);
  const [exportType, setExportType] = useState<'csv' | 'png' | 'pdf'>('csv');

  // Initialize progress tracking
  const {
    executeExport,
    modalProgress,
    closeModal,
    cancelProgress
  } = useExportWithProgress({
    showModal: showProgressModal,
    allowCancel
  });

  const handleCSVExport = async () => {
    const { csvExporter } = await import('@/lib/exports/csvExporter');
    return csvExporter.exportRecommendations(recommendations);
  };

  const handlePNGExport = async () => {
    const { pngExporter } = await import('@/lib/exports/pngExporter');
    
    const targetElement = document.querySelector(pngTargetSelector) as HTMLElement;
    if (!targetElement) {
      throw new Error('Recommendation panel not found for PNG export');
    }
    
    return pngExporter.exportRecommendationPanel(targetElement);
  };

  const handlePDFExport = async () => {
    const { pdfExporter } = await import('@/lib/exports/pdfExporter');
    return pdfExporter.exportRecommendations(recommendations);
  };

  if (!enablePNGExport && !enablePDFExport) {
    // Simple CSV export button (original behavior)
    return (
      <>
        <Button
          variant="outline"
          size="sm"
          className={cn('gap-2', className)}
          disabled={isExporting || !recommendations || recommendations.length === 0}
          onClick={() => executeExport('csv', handleCSVExport, `recommendations_${Date.now()}`)}
        >
          {isExporting ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <FileSpreadsheet className="h-4 w-4" />
          )}
          {isExporting ? 'Exporting...' : 'Export CSV'}
        </Button>

        {/* Progress Overlay */}
        {modalProgress && (
          <ExportProgressOverlay
            isVisible={true}
            exportType={modalProgress.type}
            fileName={modalProgress.fileName}
            progress={modalProgress.overallProgress}
            currentStep={modalProgress.steps.find(s => s.status === 'running')?.label || 'Processing...'}
            onCancel={allowCancel ? () => cancelProgress(modalProgress.jobId) : undefined}
            onClose={closeModal}
          />
        )}
      </>
    );
  }

  // Dropdown with CSV, PNG, and PDF options
  return (
    <>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            variant="outline"
            size="sm"
            className={cn('gap-2', className)}
            disabled={isExporting || !recommendations || recommendations.length === 0}
          >
            {isExporting ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Download className="h-4 w-4" />
            )}
            {isExporting ? `Exporting ${exportType.toUpperCase()}...` : 'Export'}
          </Button>
        </DropdownMenuTrigger>
        
        <DropdownMenuContent align="end" className="w-40">
          <DropdownMenuItem
            className="gap-2 cursor-pointer"
            disabled={isExporting}
            onClick={() => executeExport('csv', handleCSVExport, `recommendations_${Date.now()}`)}
          >
            <FileSpreadsheet className="h-4 w-4" />
            <span>Export CSV</span>
          </DropdownMenuItem>
          
          {enablePNGExport && (
            <DropdownMenuItem
              className="gap-2 cursor-pointer"
              disabled={isExporting}
              onClick={() => executeExport('png', handlePNGExport, `recommendations_${Date.now()}`)}
            >
              <FileImage className="h-4 w-4" />
              <span>Export PNG</span>
            </DropdownMenuItem>
          )}
          
          {enablePDFExport && (
            <DropdownMenuItem
              className="gap-2 cursor-pointer"
              disabled={isExporting}
              onClick={() => executeExport('pdf', handlePDFExport, `recommendations_${Date.now()}`)}
            >
              <FileText className="h-4 w-4" />
              <span>Export PDF</span>
            </DropdownMenuItem>
          )}
          
          <DropdownMenuSeparator />
          <div className="px-2 py-1.5 text-xs text-gray-500">
            {recommendations.length} recommendations
          </div>
        </DropdownMenuContent>
      </DropdownMenu>

      {/* Progress Overlay */}
      {modalProgress && (
        <ExportProgressOverlay
          isVisible={true}
          exportType={modalProgress.type}
          fileName={modalProgress.fileName}
          progress={modalProgress.overallProgress}
          currentStep={modalProgress.steps.find(s => s.status === 'running')?.label || 'Processing...'}
          onCancel={allowCancel ? () => cancelProgress(modalProgress.jobId) : undefined}
          onClose={closeModal}
        />
      )}
    </>
  );
};

export default ExportButton;