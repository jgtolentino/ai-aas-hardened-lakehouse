/**
 * PDF Export Utility
 * Handles generation of PDF reports from data and DOM elements
 */

import jsPDF from 'jspdf';
import html2canvas from 'html2canvas';

export interface PDFExportOptions {
  filename?: string;
  format?: 'a4' | 'letter' | 'legal';
  orientation?: 'portrait' | 'landscape';
  quality?: number;
  margin?: {
    top: number;
    right: number;
    bottom: number;
    left: number;
  };
  includeTimestamp?: boolean;
  includeHeader?: boolean;
  includeFooter?: boolean;
  headerText?: string;
  footerText?: string;
  pageNumbering?: boolean;
  watermark?: {
    text: string;
    opacity?: number;
    color?: string;
  };
  scale?: number;
}

export interface PDFExportResult {
  success: boolean;
  filename: string;
  pageCount: number;
  fileSize?: number;
  error?: string;
}

export interface PDFReportSection {
  title: string;
  content: any[];
  type: 'table' | 'chart' | 'text' | 'html' | 'image';
  options?: {
    columns?: Array<{
      key: string;
      header: string;
      width?: number;
    }>;
    chartElement?: HTMLElement;
    htmlContent?: string;
    imageUrl?: string;
    textContent?: string;
  };
}

export interface PDFReportConfig {
  title: string;
  subtitle?: string;
  author?: string;
  sections: PDFReportSection[];
  options?: PDFExportOptions;
}

export class PDFExporter {
  private options: Required<Omit<PDFExportOptions, 'watermark' | 'headerText' | 'footerText'>> & { 
    watermark?: PDFExportOptions['watermark'];
    headerText?: string;
    footerText?: string;
  };

  constructor(options: PDFExportOptions = {}) {
    this.options = {
      filename: options.filename || `report_${new Date().toISOString().split('T')[0]}.pdf`,
      format: options.format || 'a4',
      orientation: options.orientation || 'portrait',
      quality: options.quality || 1.0,
      margin: options.margin || { top: 20, right: 20, bottom: 20, left: 20 },
      includeTimestamp: options.includeTimestamp ?? true,
      includeHeader: options.includeHeader ?? false,
      includeFooter: options.includeFooter ?? false,
      pageNumbering: options.pageNumbering ?? true,
      scale: options.scale || 2,
      watermark: options.watermark,
      headerText: options.headerText,
      footerText: options.footerText
    };
  }

  /**
   * Export DOM element to PDF
   */
  async exportElement(
    element: HTMLElement,
    customOptions: Partial<PDFExportOptions> = {}
  ): Promise<PDFExportResult> {
    try {
      if (!element) {
        throw new Error('No element provided for PDF export');
      }

      const options = { ...this.options, ...customOptions };
      const filename = options.includeTimestamp && !customOptions.filename
        ? this.addTimestampToFilename(options.filename)
        : options.filename;

      // Prepare element for capture
      await this.prepareElementForCapture(element);

      // Capture element as canvas
      const canvas = await html2canvas(element, {
        quality: options.quality,
        scale: options.scale,
        useCORS: true,
        allowTaint: true,
        logging: false
      });

      // Create PDF
      const pdf = new jsPDF({
        orientation: options.orientation,
        unit: 'mm',
        format: options.format
      });

      const pageWidth = pdf.internal.pageSize.getWidth();
      const pageHeight = pdf.internal.pageSize.getHeight();
      const margin = options.margin;

      // Add header if enabled
      if (options.includeHeader) {
        this.addHeader(pdf, options.headerText || 'Scout Dashboard Report', margin);
      }

      // Add watermark if specified
      if (options.watermark) {
        this.addWatermark(pdf, options.watermark, pageWidth, pageHeight);
      }

      // Calculate content area
      const contentWidth = pageWidth - margin.left - margin.right;
      const contentHeight = pageHeight - margin.top - margin.bottom - 
        (options.includeHeader ? 15 : 0) - (options.includeFooter ? 15 : 0);

      // Add canvas image to PDF
      const imgData = canvas.toDataURL('image/png');
      const imgWidth = canvas.width;
      const imgHeight = canvas.height;

      // Calculate scaling to fit page
      const scaleX = contentWidth / (imgWidth * 0.75); // 0.75 for mm to px conversion
      const scaleY = contentHeight / (imgHeight * 0.75);
      const scale = Math.min(scaleX, scaleY, 1); // Don't upscale

      const finalWidth = (imgWidth * 0.75) * scale;
      const finalHeight = (imgHeight * 0.75) * scale;

      // Center the image
      const xPos = margin.left + (contentWidth - finalWidth) / 2;
      const yPos = margin.top + (options.includeHeader ? 15 : 0) + (contentHeight - finalHeight) / 2;

      pdf.addImage(imgData, 'PNG', xPos, yPos, finalWidth, finalHeight);

      // Add footer if enabled
      if (options.includeFooter) {
        this.addFooter(pdf, options.footerText, margin, pageWidth, pageHeight, options.pageNumbering);
      }

      // Save PDF
      pdf.save(filename);

      return {
        success: true,
        filename,
        pageCount: 1,
        fileSize: pdf.output('blob').size
      };

    } catch (error) {
      return {
        success: false,
        filename: '',
        pageCount: 0,
        error: error instanceof Error ? error.message : 'PDF export failed'
      };
    }
  }

  /**
   * Generate structured PDF report
   */
  async generateReport(config: PDFReportConfig): Promise<PDFExportResult> {
    try {
      const options = { ...this.options, ...config.options };
      const filename = options.includeTimestamp && !config.options?.filename
        ? this.addTimestampToFilename(options.filename)
        : options.filename;

      const pdf = new jsPDF({
        orientation: options.orientation,
        unit: 'mm',
        format: options.format
      });

      const pageWidth = pdf.internal.pageSize.getWidth();
      const pageHeight = pdf.internal.pageSize.getHeight();
      const margin = options.margin;
      let currentY = margin.top;

      // Add watermark if specified
      if (options.watermark) {
        this.addWatermark(pdf, options.watermark, pageWidth, pageHeight);
      }

      // Add title page
      currentY = this.addTitlePage(pdf, config, margin, pageWidth, currentY);

      // Add sections
      for (const section of config.sections) {
        // Check if we need a new page
        if (currentY > pageHeight - margin.bottom - 40) {
          pdf.addPage();
          currentY = margin.top;
          if (options.watermark) {
            this.addWatermark(pdf, options.watermark, pageWidth, pageHeight);
          }
        }

        currentY = await this.addSection(pdf, section, margin, pageWidth, pageHeight, currentY);
      }

      // Add page numbers if enabled
      if (options.pageNumbering) {
        this.addPageNumbers(pdf, margin, pageWidth, pageHeight);
      }

      // Save PDF
      pdf.save(filename);

      return {
        success: true,
        filename,
        pageCount: pdf.getNumberOfPages(),
        fileSize: pdf.output('blob').size
      };

    } catch (error) {
      return {
        success: false,
        filename: '',
        pageCount: 0,
        error: error instanceof Error ? error.message : 'PDF report generation failed'
      };
    }
  }

  /**
   * Export recommendations as PDF report
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
      impact: any;
      metadata?: any;
    }>
  ): Promise<PDFExportResult> {
    const reportConfig: PDFReportConfig = {
      title: 'AI Recommendations Report',
      subtitle: `Generated on ${new Date().toLocaleDateString()}`,
      author: 'TBWA Scout Dashboard',
      sections: [
        {
          title: 'Executive Summary',
          type: 'text',
          content: [],
          options: {
            textContent: this.generateRecommendationsSummary(recommendations)
          }
        },
        {
          title: 'Detailed Recommendations',
          type: 'table',
          content: recommendations.map(rec => ({
            ID: rec.id,
            Type: rec.type,
            Title: rec.title,
            'Confidence %': rec.confidence,
            Priority: rec.priority,
            Category: rec.category,
            'Impact Type': rec.impact.type,
            'Estimated Value': rec.impact.estimated_value ? 
              `₱${rec.impact.estimated_value.toLocaleString()}` : 'N/A'
          })),
          options: {
            columns: [
              { key: 'Type', header: 'Type', width: 20 },
              { key: 'Title', header: 'Title', width: 40 },
              { key: 'Confidence %', header: 'Confidence', width: 15 },
              { key: 'Priority', header: 'Priority', width: 15 },
              { key: 'Impact Type', header: 'Impact', width: 25 }
            ]
          }
        }
      ],
      options: {
        includeHeader: true,
        includeFooter: true,
        headerText: 'TBWA Scout Dashboard - AI Recommendations',
        footerText: 'Confidential - Internal Use Only',
        watermark: {
          text: 'SCOUT ANALYTICS',
          opacity: 0.1,
          color: '#666666'
        }
      }
    };

    return this.generateReport(reportConfig);
  }

  /**
   * Export KPI dashboard as PDF
   */
  async exportKPIDashboard(
    kpiData: Array<{
      name: string;
      value: number | string;
      change: number;
      trend: 'up' | 'down' | 'stable';
      category: string;
    }>
  ): Promise<PDFExportResult> {
    const reportConfig: PDFReportConfig = {
      title: 'KPI Dashboard Report',
      subtitle: `Performance Metrics - ${new Date().toLocaleDateString()}`,
      author: 'TBWA Scout Dashboard',
      sections: [
        {
          title: 'Key Performance Indicators',
          type: 'table',
          content: kpiData.map(kpi => ({
            KPI: kpi.name,
            Value: kpi.value,
            Change: `${kpi.change > 0 ? '+' : ''}${kpi.change}%`,
            Trend: kpi.trend,
            Category: kpi.category
          })),
          options: {
            columns: [
              { key: 'KPI', header: 'KPI', width: 40 },
              { key: 'Value', header: 'Current Value', width: 25 },
              { key: 'Change', header: 'Change %', width: 20 },
              { key: 'Trend', header: 'Trend', width: 15 }
            ]
          }
        }
      ],
      options: {
        includeHeader: true,
        includeFooter: true,
        headerText: 'TBWA Scout Dashboard - KPI Report',
        footerText: 'Generated by Scout Analytics',
        watermark: {
          text: 'SCOUT DASHBOARD',
          opacity: 0.1
        }
      }
    };

    return this.generateReport(reportConfig);
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
          img.addEventListener('error', () => resolve());
        }
      });
    });

    await Promise.all(imagePromises);
    
    // Small delay for dynamic content
    await new Promise(resolve => setTimeout(resolve, 200));
  }

  private addHeader(pdf: jsPDF, headerText: string, margin: { top: number; left: number; right: number }): void {
    pdf.setFontSize(10);
    pdf.setTextColor(100, 100, 100);
    pdf.text(headerText, margin.left, margin.top - 5);
    
    // Add separator line
    const pageWidth = pdf.internal.pageSize.getWidth();
    pdf.setDrawColor(200, 200, 200);
    pdf.line(margin.left, margin.top, pageWidth - margin.right, margin.top);
  }

  private addFooter(
    pdf: jsPDF, 
    footerText: string | undefined, 
    margin: any, 
    pageWidth: number, 
    pageHeight: number, 
    includePageNumbers: boolean
  ): void {
    const footerY = pageHeight - margin.bottom + 10;
    
    pdf.setFontSize(8);
    pdf.setTextColor(100, 100, 100);
    
    // Add separator line
    pdf.setDrawColor(200, 200, 200);
    pdf.line(margin.left, footerY - 5, pageWidth - margin.right, footerY - 5);
    
    // Add footer text
    if (footerText) {
      pdf.text(footerText, margin.left, footerY);
    }
    
    // Add timestamp
    const timestamp = new Date().toLocaleString();
    pdf.text(`Generated: ${timestamp}`, margin.left, footerY + 8);
  }

  private addWatermark(
    pdf: jsPDF, 
    watermark: { text: string; opacity?: number; color?: string }, 
    pageWidth: number, 
    pageHeight: number
  ): void {
    pdf.saveGraphicsState();
    pdf.setGState({ opacity: watermark.opacity || 0.1 });
    pdf.setTextColor(watermark.color || '#666666');
    pdf.setFontSize(48);
    
    // Center the watermark diagonally
    const centerX = pageWidth / 2;
    const centerY = pageHeight / 2;
    
    pdf.text(watermark.text, centerX, centerY, { 
      align: 'center',
      angle: 45 
    });
    
    pdf.restoreGraphicsState();
  }

  private addTitlePage(
    pdf: jsPDF, 
    config: PDFReportConfig, 
    margin: any, 
    pageWidth: number, 
    startY: number
  ): number {
    let currentY = startY + 30;

    // Title
    pdf.setFontSize(24);
    pdf.setTextColor(0, 0, 0);
    pdf.text(config.title, pageWidth / 2, currentY, { align: 'center' });
    currentY += 20;

    // Subtitle
    if (config.subtitle) {
      pdf.setFontSize(14);
      pdf.setTextColor(100, 100, 100);
      pdf.text(config.subtitle, pageWidth / 2, currentY, { align: 'center' });
      currentY += 15;
    }

    // Author
    if (config.author) {
      pdf.setFontSize(10);
      pdf.text(`By: ${config.author}`, pageWidth / 2, currentY, { align: 'center' });
      currentY += 30;
    }

    return currentY;
  }

  private async addSection(
    pdf: jsPDF,
    section: PDFReportSection,
    margin: any,
    pageWidth: number,
    pageHeight: number,
    startY: number
  ): Promise<number> {
    let currentY = startY + 15;

    // Section title
    pdf.setFontSize(16);
    pdf.setTextColor(0, 0, 0);
    pdf.text(section.title, margin.left, currentY);
    currentY += 15;

    // Section content based on type
    switch (section.type) {
      case 'text':
        if (section.options?.textContent) {
          pdf.setFontSize(10);
          pdf.setTextColor(50, 50, 50);
          const lines = pdf.splitTextToSize(section.options.textContent, pageWidth - margin.left - margin.right);
          pdf.text(lines, margin.left, currentY);
          currentY += lines.length * 5;
        }
        break;

      case 'table':
        currentY = this.addTable(pdf, section.content, section.options?.columns || [], margin, pageWidth, currentY);
        break;

      case 'chart':
        if (section.options?.chartElement) {
          currentY = await this.addChartToSection(pdf, section.options.chartElement, margin, pageWidth, currentY);
        }
        break;
    }

    return currentY + 10;
  }

  private addTable(
    pdf: jsPDF,
    data: any[],
    columns: Array<{ key: string; header: string; width?: number }>,
    margin: any,
    pageWidth: number,
    startY: number
  ): number {
    if (data.length === 0) return startY;

    let currentY = startY;
    const cellHeight = 8;
    const headerHeight = 10;

    // Calculate column widths
    const totalContentWidth = pageWidth - margin.left - margin.right;
    const columnWidths = columns.map(col => 
      col.width ? (col.width / 100) * totalContentWidth : totalContentWidth / columns.length
    );

    // Draw table header
    pdf.setFillColor(240, 240, 240);
    pdf.setTextColor(0, 0, 0);
    pdf.setFontSize(10);

    let currentX = margin.left;
    columns.forEach((col, index) => {
      pdf.rect(currentX, currentY, columnWidths[index], headerHeight, 'F');
      pdf.text(col.header, currentX + 2, currentY + 7);
      currentX += columnWidths[index];
    });

    currentY += headerHeight;

    // Draw table rows
    pdf.setFontSize(9);
    data.slice(0, 50).forEach((row, rowIndex) => { // Limit to 50 rows to prevent overflow
      if (rowIndex % 2 === 0) {
        pdf.setFillColor(250, 250, 250);
        pdf.rect(margin.left, currentY, totalContentWidth, cellHeight, 'F');
      }

      currentX = margin.left;
      columns.forEach((col, colIndex) => {
        const cellValue = String(row[col.key] || '');
        const truncatedValue = cellValue.length > 30 ? cellValue.substring(0, 27) + '...' : cellValue;
        pdf.text(truncatedValue, currentX + 2, currentY + 6);
        currentX += columnWidths[colIndex];
      });

      currentY += cellHeight;
    });

    return currentY + 5;
  }

  private async addChartToSection(
    pdf: jsPDF,
    chartElement: HTMLElement,
    margin: any,
    pageWidth: number,
    startY: number
  ): Promise<number> {
    try {
      const canvas = await html2canvas(chartElement, {
        quality: 1.0,
        scale: 2,
        useCORS: true
      });

      const imgData = canvas.toDataURL('image/png');
      const imgWidth = pageWidth - margin.left - margin.right;
      const imgHeight = (canvas.height / canvas.width) * imgWidth;

      pdf.addImage(imgData, 'PNG', margin.left, startY, imgWidth, imgHeight);
      return startY + imgHeight + 10;
    } catch (error) {
      // Fallback: add error text
      pdf.setFontSize(10);
      pdf.setTextColor(200, 0, 0);
      pdf.text('Chart could not be rendered', margin.left, startY);
      return startY + 15;
    }
  }

  private addPageNumbers(pdf: jsPDF, margin: any, pageWidth: number, pageHeight: number): void {
    const totalPages = pdf.getNumberOfPages();
    
    for (let i = 1; i <= totalPages; i++) {
      pdf.setPage(i);
      pdf.setFontSize(8);
      pdf.setTextColor(100, 100, 100);
      pdf.text(`Page ${i} of ${totalPages}`, pageWidth - margin.right - 20, pageHeight - margin.bottom + 15);
    }
  }

  private generateRecommendationsSummary(recommendations: any[]): string {
    const totalRecs = recommendations.length;
    const highConfidence = recommendations.filter(r => r.confidence >= 80).length;
    const criticalPriority = recommendations.filter(r => r.priority === 'critical').length;
    const categories = [...new Set(recommendations.map(r => r.category))];

    return `This report contains ${totalRecs} AI-generated recommendations for business optimization. 
${highConfidence} recommendations have high confidence scores (≥80%), and ${criticalPriority} are marked as critical priority. 
The recommendations span ${categories.length} categories: ${categories.join(', ')}. 

Each recommendation includes confidence scoring, priority levels, and estimated business impact to help prioritize implementation efforts.`;
  }

  private addTimestampToFilename(filename: string): string {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').split('T')[0];
    const ext = filename.split('.').pop();
    const name = filename.replace(`.${ext}`, '');
    return `${name}_${timestamp}.${ext}`;
  }
}

// Default instance
export const pdfExporter = new PDFExporter();

// Utility functions
export const exportElementToPDF = (
  element: HTMLElement,
  options?: PDFExportOptions
): Promise<PDFExportResult> => {
  return pdfExporter.exportElement(element, options);
};

export const generatePDFReport = (
  config: PDFReportConfig
): Promise<PDFExportResult> => {
  return pdfExporter.generateReport(config);
};

export const exportRecommendationsToPDF = (
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
  }>
): Promise<PDFExportResult> => {
  return pdfExporter.exportRecommendations(recommendations);
};

export const exportKPIDashboardToPDF = (
  kpiData: Array<{
    name: string;
    value: number | string;
    change: number;
    trend: 'up' | 'down' | 'stable';
    category: string;
  }>
): Promise<PDFExportResult> => {
  return pdfExporter.exportKPIDashboard(kpiData);
};