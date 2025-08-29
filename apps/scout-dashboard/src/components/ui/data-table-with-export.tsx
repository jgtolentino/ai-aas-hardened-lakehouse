import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from './card';
import { ExportButton } from './export-button';
import { CSVExportOptions } from '@/lib/exports/csvExporter';
import { cn } from '@/lib/utils';

interface Column<T = any> {
  key: string;
  header: string;
  render?: (value: any, row: T) => React.ReactNode;
  sortable?: boolean;
  exportFormatter?: (value: any, row: T) => string;
}

interface DataTableWithExportProps<T extends Record<string, any>> {
  title?: string;
  data: T[];
  columns: Column<T>[];
  className?: string;
  loading?: boolean;
  emptyMessage?: string;
  exportOptions?: CSVExportOptions;
  showExport?: boolean;
  maxRows?: number;
}

export function DataTableWithExport<T extends Record<string, any>>({
  title,
  data,
  columns,
  className,
  loading = false,
  emptyMessage = 'No data available',
  exportOptions,
  showExport = true,
  maxRows
}: DataTableWithExportProps<T>) {
  // Prepare data for export with custom formatters
  const prepareExportData = () => {
    return data.map(row => {
      const exportRow: Record<string, any> = {};
      columns.forEach(col => {
        const value = row[col.key];
        exportRow[col.header] = col.exportFormatter 
          ? col.exportFormatter(value, row)
          : value;
      });
      return exportRow;
    });
  };

  const exportData = prepareExportData();
  const displayData = maxRows ? data.slice(0, maxRows) : data;

  const csvExportOptions: CSVExportOptions = {
    filename: title ? `${title.toLowerCase().replace(/\s+/g, '_')}.csv` : 'data_export.csv',
    headers: columns.map(col => col.header),
    includeTimestamp: true,
    ...exportOptions
  };

  return (
    <Card className={cn('w-full', className)}>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-4">
        <div>
          {title && <CardTitle className="text-base font-medium">{title}</CardTitle>}
          <div className="text-sm text-gray-500 mt-1">
            {loading ? 'Loading...' : `${data.length} records`}
            {maxRows && data.length > maxRows && ` (showing first ${maxRows})`}
          </div>
        </div>
        {showExport && data.length > 0 && (
          <ExportButton
            data={exportData}
            csvOptions={csvExportOptions}
            showDropdown={false}
            className="text-xs"
          />
        )}
      </CardHeader>
      
      <CardContent>
        {loading ? (
          <div className="space-y-2">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-4 bg-gray-200 rounded animate-pulse" />
            ))}
          </div>
        ) : data.length === 0 ? (
          <div className="text-center py-8 text-gray-500">
            {emptyMessage}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b">
                  {columns.map((column) => (
                    <th
                      key={column.key}
                      className="text-left py-2 px-3 text-sm font-medium text-gray-500"
                    >
                      {column.header}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {displayData.map((row, index) => (
                  <tr key={index} className="border-b border-gray-100 hover:bg-gray-50">
                    {columns.map((column) => (
                      <td key={column.key} className="py-2 px-3 text-sm">
                        {column.render ? column.render(row[column.key], row) : row[column.key]}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
            {maxRows && data.length > maxRows && (
              <div className="text-center py-4 text-sm text-gray-500">
                ... and {data.length - maxRows} more records
              </div>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

export default DataTableWithExport;