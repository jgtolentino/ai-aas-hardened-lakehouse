import React, { useState, useMemo } from 'react';
import { 
  Search, Filter, Download, MoreVertical, 
  ChevronUp, ChevronDown, Eye, Edit3, Trash2
} from 'lucide-react';
import styles from './AdvancedDataGrid.module.css';

const AdvancedDataGrid = ({ 
  data = [], 
  columns = [], 
  title = 'Data Table',
  searchable = true,
  sortable = true,
  filterable = true,
  exportable = true,
  editable = false,
  pagination = true,
  pageSize = 10,
  onRowClick,
  onEdit,
  onDelete
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [sortConfig, setSortConfig] = useState({ key: null, direction: null });
  const [currentPage, setCurrentPage] = useState(1);
  const [selectedRows, setSelectedRows] = useState(new Set());
  const [filters, setFilters] = useState({});

  // Memoized filtered and sorted data
  const processedData = useMemo(() => {
    let filtered = data;

    // Apply search filter
    if (searchTerm) {
      filtered = filtered.filter(row =>
        Object.values(row).some(value =>
          String(value).toLowerCase().includes(searchTerm.toLowerCase())
        )
      );
    }

    // Apply column filters
    Object.entries(filters).forEach(([key, value]) => {
      if (value) {
        filtered = filtered.filter(row =>
          String(row[key]).toLowerCase().includes(value.toLowerCase())
        );
      }
    });

    // Apply sorting
    if (sortConfig.key) {
      filtered.sort((a, b) => {
        const aValue = a[sortConfig.key];
        const bValue = b[sortConfig.key];
        
        if (aValue < bValue) {
          return sortConfig.direction === 'asc' ? -1 : 1;
        }
        if (aValue > bValue) {
          return sortConfig.direction === 'asc' ? 1 : -1;
        }
        return 0;
      });
    }

    return filtered;
  }, [data, searchTerm, sortConfig, filters]);

  // Pagination
  const totalPages = Math.ceil(processedData.length / pageSize);
  const startIndex = (currentPage - 1) * pageSize;
  const paginatedData = pagination 
    ? processedData.slice(startIndex, startIndex + pageSize)
    : processedData;

  const handleSort = (key) => {
    if (!sortable) return;
    
    setSortConfig(prev => ({
      key,
      direction: prev.key === key && prev.direction === 'asc' ? 'desc' : 'asc'
    }));
  };

  const handleSelectRow = (rowIndex) => {
    const newSelected = new Set(selectedRows);
    if (newSelected.has(rowIndex)) {
      newSelected.delete(rowIndex);
    } else {
      newSelected.add(rowIndex);
    }
    setSelectedRows(newSelected);
  };

  const handleSelectAll = () => {
    if (selectedRows.size === paginatedData.length) {
      setSelectedRows(new Set());
    } else {
      setSelectedRows(new Set(paginatedData.map((_, index) => index)));
    }
  };

  const exportData = () => {
    const csvContent = [
      columns.map(col => col.headerName).join(','),
      ...processedData.map(row => 
        columns.map(col => row[col.field]).join(',')
      )
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `${title.replace(/\s+/g, '_')}.csv`;
    link.click();
    window.URL.revokeObjectURL(url);
  };

  const getSortIcon = (key) => {
    if (sortConfig.key !== key) return null;
    return sortConfig.direction === 'asc' ? <ChevronUp size={16} /> : <ChevronDown size={16} />;
  };

  return (
    <div className={styles.dataGrid}>
      {/* Header */}
      <div className={styles.gridHeader}>
        <div className={styles.gridTitle}>
          <h3>{title}</h3>
          <span className={styles.recordCount}>
            {processedData.length} record{processedData.length !== 1 ? 's' : ''}
          </span>
        </div>

        <div className={styles.gridActions}>
          {searchable && (
            <div className={styles.searchBox}>
              <Search size={16} />
              <input
                type="text"
                placeholder="Search..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
          )}

          {filterable && (
            <button className={styles.actionBtn}>
              <Filter size={16} />
            </button>
          )}

          {exportable && (
            <button className={styles.actionBtn} onClick={exportData}>
              <Download size={16} />
            </button>
          )}

          <button className={styles.actionBtn}>
            <MoreVertical size={16} />
          </button>
        </div>
      </div>

      {/* Column Filters */}
      {filterable && (
        <div className={styles.columnFilters}>
          {columns.map(column => (
            <div key={column.field} className={styles.filterInput}>
              <input
                type="text"
                placeholder={`Filter ${column.headerName}...`}
                value={filters[column.field] || ''}
                onChange={(e) => setFilters(prev => ({
                  ...prev,
                  [column.field]: e.target.value
                }))}
              />
            </div>
          ))}
        </div>
      )}

      {/* Table */}
      <div className={styles.tableContainer}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th className={styles.checkboxCell}>
                <input
                  type="checkbox"
                  checked={selectedRows.size === paginatedData.length && paginatedData.length > 0}
                  onChange={handleSelectAll}
                />
              </th>
              {columns.map(column => (
                <th
                  key={column.field}
                  className={`${styles.headerCell} ${sortable ? styles.sortable : ''}`}
                  onClick={() => handleSort(column.field)}
                  style={{ width: column.width }}
                >
                  <div className={styles.headerContent}>
                    <span>{column.headerName}</span>
                    {sortable && getSortIcon(column.field)}
                  </div>
                </th>
              ))}
              {(editable || onEdit || onDelete) && (
                <th className={styles.actionsCell}>Actions</th>
              )}
            </tr>
          </thead>
          <tbody>
            {paginatedData.map((row, index) => (
              <tr
                key={index}
                className={`${styles.dataRow} ${selectedRows.has(index) ? styles.selected : ''}`}
                onClick={() => onRowClick && onRowClick(row)}
              >
                <td className={styles.checkboxCell}>
                  <input
                    type="checkbox"
                    checked={selectedRows.has(index)}
                    onChange={(e) => {
                      e.stopPropagation();
                      handleSelectRow(index);
                    }}
                  />
                </td>
                {columns.map(column => (
                  <td key={column.field} className={styles.dataCell}>
                    {column.renderCell 
                      ? column.renderCell(row[column.field], row) 
                      : row[column.field]
                    }
                  </td>
                ))}
                {(editable || onEdit || onDelete) && (
                  <td className={styles.actionsCell}>
                    <div className={styles.rowActions}>
                      <button
                        className={styles.actionBtn}
                        onClick={(e) => {
                          e.stopPropagation();
                          // View action
                        }}
                      >
                        <Eye size={14} />
                      </button>
                      {onEdit && (
                        <button
                          className={styles.actionBtn}
                          onClick={(e) => {
                            e.stopPropagation();
                            onEdit(row);
                          }}
                        >
                          <Edit3 size={14} />
                        </button>
                      )}
                      {onDelete && (
                        <button
                          className={`${styles.actionBtn} ${styles.danger}`}
                          onClick={(e) => {
                            e.stopPropagation();
                            onDelete(row);
                          }}
                        >
                          <Trash2 size={14} />
                        </button>
                      )}
                    </div>
                  </td>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {pagination && totalPages > 1 && (
        <div className={styles.pagination}>
          <div className={styles.paginationInfo}>
            Showing {startIndex + 1}-{Math.min(startIndex + pageSize, processedData.length)} of {processedData.length}
          </div>
          
          <div className={styles.paginationControls}>
            <button
              className={styles.pageBtn}
              disabled={currentPage === 1}
              onClick={() => setCurrentPage(1)}
            >
              First
            </button>
            <button
              className={styles.pageBtn}
              disabled={currentPage === 1}
              onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
            >
              Previous
            </button>
            
            <div className={styles.pageNumbers}>
              {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                const page = Math.max(1, Math.min(totalPages, currentPage - 2 + i));
                return (
                  <button
                    key={page}
                    className={`${styles.pageBtn} ${currentPage === page ? styles.active : ''}`}
                    onClick={() => setCurrentPage(page)}
                  >
                    {page}
                  </button>
                );
              })}
            </div>
            
            <button
              className={styles.pageBtn}
              disabled={currentPage === totalPages}
              onClick={() => setCurrentPage(prev => Math.min(totalPages, prev + 1))}
            >
              Next
            </button>
            <button
              className={styles.pageBtn}
              disabled={currentPage === totalPages}
              onClick={() => setCurrentPage(totalPages)}
            >
              Last
            </button>
          </div>
        </div>
      )}

      {/* Selection Summary */}
      {selectedRows.size > 0 && (
        <div className={styles.selectionSummary}>
          <span>{selectedRows.size} row{selectedRows.size !== 1 ? 's' : ''} selected</span>
          <button className={styles.actionBtn}>Bulk Actions</button>
        </div>
      )}
    </div>
  );
};

export default AdvancedDataGrid;