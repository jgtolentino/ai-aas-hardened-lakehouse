/**
 * PNG Export Utility
 * Handles conversion of DOM elements (charts, components) to PNG images
 */

import html2canvas from 'html2canvas';

export interface PNGExportOptions {
  filename?: string;
  backgroundColor?: string;
  quality?: number;
  scale?: number;
  width?: number;
  height?: number;
  includeTimestamp?: boolean;
  padding?: number;
  watermark?: {
    text: string;
    position: 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right';
    opacity?: number;
  };
}

export interface PNGExportResult {
  success: boolean;
  filename: string;
  width: number;
  height: number;
  error?: string;
}

export class PNGExporter {
  private options: Required<Omit<PNGExportOptions, 'watermark'>> & { watermark?: PNGExportOptions['watermark'] };

  constructor(options: PNGExportOptions = {}) {
    this.options = {
      filename: options.filename || `chart_export_${new Date().toISOString().split('T')[0]}.png`,
      backgroundColor: options.backgroundColor || '#ffffff',
      quality: options.quality || 1.0,
      scale: options.scale || 2, // 2x for better quality
      width: options.width || 0, // 0 means use natural width
      height: options.height || 0, // 0 means use natural height
      includeTimestamp: options.includeTimestamp ?? true,
      padding: options.padding || 20,
      watermark: options.watermark
    };
  }

  /**
   * Export a DOM element to PNG
   */
  async exportElement(
    element: HTMLElement,
    customOptions: Partial<PNGExportOptions> = {}
  ): Promise<PNGExportResult> {
    try {
      if (!element) {
        throw new Error('No element provided for export');
      }

      // Merge options
      const options = { ...this.options, ...customOptions };
      
      // Add timestamp to filename if requested
      const filename = options.includeTimestamp && !customOptions.filename
        ? this.addTimestampToFilename(options.filename)
        : options.filename;

      // Prepare element for capture
      await this.prepareElementForCapture(element);

      // Configure html2canvas options
      const html2canvasOptions = {
        backgroundColor: options.backgroundColor,
        quality: options.quality,
        scale: options.scale,
        useCORS: true,
        allowTaint: true,
        logging: false,
        width: options.width || undefined,
        height: options.height || undefined,
        scrollX: 0,
        scrollY: 0,
        // Ignore certain elements that might cause issues
        ignoreElements: (el: Element) => {
          return el.classList.contains('export-ignore') ||
                 el.tagName === 'SCRIPT' ||
                 el.tagName === 'NOSCRIPT';
        }
      };

      // Capture the element
      const canvas = await html2canvas(element, html2canvasOptions);

      // Add padding if specified
      const finalCanvas = options.padding > 0 
        ? this.addPaddingToCanvas(canvas, options.padding, options.backgroundColor)
        : canvas;

      // Add watermark if specified
      const watermarkedCanvas = options.watermark 
        ? this.addWatermarkToCanvas(finalCanvas, options.watermark)
        : finalCanvas;

      // Download the image
      this.downloadCanvas(watermarkedCanvas, filename);

      return {
        success: true,
        filename,
        width: watermarkedCanvas.width,
        height: watermarkedCanvas.height
      };

    } catch (error) {
      return {
        success: false,
        filename: '',
        width: 0,
        height: 0,
        error: error instanceof Error ? error.message : 'PNG export failed'
      };
    }
  }

  /**
   * Export element by selector
   */
  async exportBySelector(
    selector: string,
    customOptions: Partial<PNGExportOptions> = {}
  ): Promise<PNGExportResult> {
    const element = document.querySelector(selector) as HTMLElement;
    
    if (!element) {
      return {
        success: false,
        filename: '',
        width: 0,
        height: 0,
        error: `Element with selector "${selector}" not found`
      };
    }

    return this.exportElement(element, customOptions);
  }

  /**
   * Export chart component (specialized for chart libraries)
   */
  async exportChart(
    chartContainer: HTMLElement,
    chartTitle?: string
  ): Promise<PNGExportResult> {
    const filename = chartTitle 
      ? `${chartTitle.toLowerCase().replace(/\s+/g, '_')}_chart.png`
      : 'chart_export.png';

    return this.exportElement(chartContainer, {
      filename,
      backgroundColor: '#ffffff',
      padding: 30,
      watermark: {
        text: 'Scout Analytics',
        position: 'bottom-right',
        opacity: 0.3
      }
    });
  }

  /**
   * Export KPI dashboard section
   */
  async exportKPIDashboard(
    dashboardElement: HTMLElement
  ): Promise<PNGExportResult> {
    return this.exportElement(dashboardElement, {
      filename: 'kpi_dashboard.png',
      backgroundColor: '#f8fafc',
      padding: 40,
      scale: 2,
      watermark: {
        text: 'TBWA Scout Dashboard',
        position: 'top-right',
        opacity: 0.2
      }
    });
  }

  /**
   * Export recommendation panel
   */
  async exportRecommendationPanel(
    panelElement: HTMLElement
  ): Promise<PNGExportResult> {
    return this.exportElement(panelElement, {
      filename: 'ai_recommendations.png',
      backgroundColor: '#ffffff',
      padding: 25,
      scale: 2
    });
  }

  private async prepareElementForCapture(element: HTMLElement): Promise<void> {
    // Ensure all images are loaded
    const images = element.querySelectorAll('img');
    const imagePromises = Array.from(images).map(img => {
      return new Promise<void>((resolve) => {
        if (img.complete) {
          resolve();
        } else {
          img.addEventListener('load', () => resolve());
          img.addEventListener('error', () => resolve()); // Continue even if image fails
        }
      });
    });

    await Promise.all(imagePromises);

    // Small delay to ensure all dynamic content is rendered
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  private addPaddingToCanvas(
    canvas: HTMLCanvasElement, 
    padding: number, 
    backgroundColor: string
  ): HTMLCanvasElement {
    const paddedCanvas = document.createElement('canvas');
    const ctx = paddedCanvas.getContext('2d');
    
    if (!ctx) return canvas;

    paddedCanvas.width = canvas.width + (padding * 2);
    paddedCanvas.height = canvas.height + (padding * 2);

    // Fill background
    ctx.fillStyle = backgroundColor;
    ctx.fillRect(0, 0, paddedCanvas.width, paddedCanvas.height);

    // Draw original canvas with padding
    ctx.drawImage(canvas, padding, padding);

    return paddedCanvas;
  }

  private addWatermarkToCanvas(
    canvas: HTMLCanvasElement, 
    watermark: NonNullable<PNGExportOptions['watermark']>
  ): HTMLCanvasElement {
    const ctx = canvas.getContext('2d');
    if (!ctx) return canvas;

    // Configure watermark text
    ctx.save();
    ctx.globalAlpha = watermark.opacity || 0.3;
    ctx.font = '12px Arial';
    ctx.fillStyle = '#666666';

    const metrics = ctx.measureText(watermark.text);
    const textWidth = metrics.width;
    const textHeight = 12; // Approximate font height

    // Position watermark
    let x: number, y: number;
    
    switch (watermark.position) {
      case 'top-left':
        x = 10;
        y = textHeight + 10;
        break;
      case 'top-right':
        x = canvas.width - textWidth - 10;
        y = textHeight + 10;
        break;
      case 'bottom-left':
        x = 10;
        y = canvas.height - 10;
        break;
      case 'bottom-right':
        x = canvas.width - textWidth - 10;
        y = canvas.height - 10;
        break;
      default:
        x = canvas.width - textWidth - 10;
        y = canvas.height - 10;
    }

    ctx.fillText(watermark.text, x, y);
    ctx.restore();

    return canvas;
  }

  private downloadCanvas(canvas: HTMLCanvasElement, filename: string): void {
    // Convert canvas to blob
    canvas.toBlob((blob) => {
      if (!blob) return;

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
    }, 'image/png', this.options.quality);
  }

  private addTimestampToFilename(filename: string): string {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').split('T')[0];
    const ext = filename.split('.').pop();
    const name = filename.replace(`.${ext}`, '');
    return `${name}_${timestamp}.${ext}`;
  }
}

// Default instance
export const pngExporter = new PNGExporter();

// Utility functions
export const exportElementToPNG = (
  element: HTMLElement,
  options?: PNGExportOptions
): Promise<PNGExportResult> => {
  return pngExporter.exportElement(element, options);
};

export const exportChartToPNG = (
  chartContainer: HTMLElement,
  chartTitle?: string
): Promise<PNGExportResult> => {
  return pngExporter.exportChart(chartContainer, chartTitle);
};

export const exportKPIDashboardToPNG = (
  dashboardElement: HTMLElement
): Promise<PNGExportResult> => {
  return pngExporter.exportKPIDashboard(dashboardElement);
};

export const exportRecommendationPanelToPNG = (
  panelElement: HTMLElement
): Promise<PNGExportResult> => {
  return pngExporter.exportRecommendationPanel(panelElement);
};