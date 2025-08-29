#!/usr/bin/env tsx
// Extract Superset dashboard to DashboardML format
import fs from 'fs';
import { DashboardML, SupersetDashboard, DashboardTile, FilterConfig } from './types';

interface SupersetPosition {
  [key: string]: {
    type: 'CHART' | 'FILTER_BOX' | 'MARKDOWN' | 'HEADER';
    meta: {
      chartId?: number;
      sliceName?: string;
      width: number;
      height: number;
    };
    x: number;
    y: number;
    w: number;
    h: number;
  };
}

function extractDashboardML(supersetData: SupersetDashboard): DashboardML {
  const positionData: SupersetPosition = JSON.parse(supersetData.position_json || '{}');
  const metadata = JSON.parse(supersetData.json_metadata || '{}');
  
  // Extract tiles from position data
  const tiles: DashboardTile[] = [];
  const filters: FilterConfig[] = [];
  
  Object.entries(positionData).forEach(([key, item]) => {
    if (item.type === 'CHART' && item.meta.chartId) {
      // Find corresponding chart data
      const chart = supersetData.slices?.find(s => s.id === item.meta.chartId);
      
      if (chart) {
        const chartParams = JSON.parse(chart.params || '{}');
        const queryContext = JSON.parse(chart.query_context || '{}');
        
        // Map Superset viz types to our tile types
        const vizTypeMap: Record<string, string> = {
          'line': 'line',
          'bar': 'bar',
          'pie': 'pie',
          'area': 'area',
          'table': 'table',
          'big_number': 'metric',
          'big_number_total': 'metric',
          'world_map': 'choropleth',
          'country_map': 'choropleth'
        };
        
        const tile: DashboardTile = {
          id: `chart_${item.meta.chartId}`,
          type: (vizTypeMap[chart.viz_type] || 'bar') as any,
          w: item.w,
          h: item.h,
          x: item.x,
          y: item.y,
          title: chart.slice_name,
          dataRef: {
            source: 'superset',
            dataset: `datasource_${chart.datasource_id}`,
            query: extractQuery(queryContext),
            fields: extractFields(chartParams, queryContext)
          },
          config: extractTileConfig(chart.viz_type, chartParams)
        };
        
        tiles.push(tile);
      }
    }
    
    if (item.type === 'FILTER_BOX') {
      // Extract filter configuration
      const filter: FilterConfig = {
        id: `filter_${key}`,
        type: 'select', // Default, could be refined
        label: item.meta.sliceName || 'Filter',
        defaultValue: null
      };
      filters.push(filter);
    }
  });
  
  // Extract datasource information
  const datasources = extractDatasources(supersetData);
  
  const dashboardML: DashboardML = {
    title: supersetData.dashboard_title,
    brand: 'InsightPulseAI', // Default brand
    version: '1.0.0',
    source: 'superset',
    grid: {
      type: '12-col',
      gutter: 16,
      margin: 24
    },
    pages: [{
      name: 'Main',
      filters,
      tiles
    }],
    datasources,
    theme: getDefaultTheme()
  };
  
  return dashboardML;
}

function extractQuery(queryContext: any): string {
  if (!queryContext?.queries?.length) return '';
  
  const query = queryContext.queries[0];
  if (query.custom_sql) return query.custom_sql;
  
  // Build basic SELECT from query context
  const columns = query.columns || [];
  const metrics = query.metrics || [];
  const table = query.datasource?.table_name || 'unknown_table';
  
  const selectClause = [
    ...columns.map((col: any) => col.column_name || col),
    ...metrics.map((metric: any) => {
      if (typeof metric === 'string') return metric;
      return metric.label || `${metric.aggregate}(${metric.column?.column_name || metric.column})`;
    })
  ].join(', ');
  
  let sql = `SELECT ${selectClause} FROM ${table}`;
  
  // Add WHERE clause if filters exist
  if (query.filters?.length) {
    const whereConditions = query.filters.map((filter: any) => {
      return `${filter.col} ${filter.op} '${filter.val}'`;
    }).join(' AND ');
    sql += ` WHERE ${whereConditions}`;
  }
  
  // Add GROUP BY for metrics
  if (metrics.length && columns.length) {
    sql += ` GROUP BY ${columns.map((col: any) => col.column_name || col).join(', ')}`;
  }
  
  return sql;
}

function extractFields(chartParams: any, queryContext: any): any[] {
  const fields: any[] = [];
  
  // Extract from query context
  if (queryContext?.queries?.length) {
    const query = queryContext.queries[0];
    
    // Add columns as dimensions
    (query.columns || []).forEach((col: any) => {
      fields.push({
        name: col.column_name || col,
        type: 'dimension',
        dataType: col.type_generic || 'string'
      });
    });
    
    // Add metrics as measures
    (query.metrics || []).forEach((metric: any) => {
      fields.push({
        name: metric.label || metric.metric_name || metric,
        type: 'measure',
        dataType: 'number',
        aggregation: metric.aggregate || 'sum'
      });
    });
  }
  
  return fields;
}

function extractTileConfig(vizType: string, params: any): any {
  const config: any = {};
  
  switch (vizType) {
    case 'big_number':
    case 'big_number_total':
      config.metric = params.metric;
      config.format = params.y_axis_format === 'CURRENCY' ? 'currency' : 'number';
      if (params.compare_lag) {
        config.compare = ['WoW']; // Simplified
      }
      break;
      
    case 'line':
    case 'bar':
    case 'area':
      config.xField = params.x_axis_label || 'x';
      config.yField = params.y_axis_label || 'y';
      config.series = params.groupby?.[0];
      config.showLegend = params.show_legend !== false;
      config.showAxes = true;
      break;
      
    case 'pie':
      config.valueField = params.metric;
      config.colorField = params.groupby?.[0];
      config.showLegend = params.show_legend !== false;
      break;
      
    case 'table':
      config.columns = (params.all_columns || []).map((col: string) => ({
        key: col,
        label: col,
        sortable: true
      }));
      break;
      
    case 'world_map':
    case 'country_map':
      config.geoField = params.entity;
      config.valueField = params.metric;
      config.mapType = vizType === 'world_map' ? 'world' : 'custom';
      break;
  }
  
  return config;
}

function extractDatasources(supersetData: SupersetDashboard): any[] {
  // This would need to be enhanced with actual datasource metadata
  // For now, create placeholder datasources based on chart references
  const datasourceIds = new Set(
    supersetData.slices?.map(s => s.datasource_id) || []
  );
  
  return Array.from(datasourceIds).map(id => ({
    id: `datasource_${id}`,
    type: 'sql',
    dialect: 'postgres', // Default assumption
    connection: 'default',
    tables: [{
      name: 'unknown_table',
      columns: []
    }]
  }));
}

function getDefaultTheme() {
  return {
    colors: {
      primary: '#3B82F6',
      secondary: '#6B7280',
      accent: '#8B5CF6',
      success: '#10B981',
      warning: '#F59E0B',
      error: '#EF4444',
      background: '#FFFFFF',
      surface: '#F9FAFB',
      text: '#111827',
      textSecondary: '#6B7280'
    },
    typography: {
      fontFamily: 'Inter, system-ui, sans-serif',
      heading: {
        fontSize: '1.5rem',
        fontWeight: '600',
        lineHeight: '1.25'
      },
      body: {
        fontSize: '0.875rem',
        fontWeight: '400',
        lineHeight: '1.5'
      },
      caption: {
        fontSize: '0.75rem',
        fontWeight: '400',
        lineHeight: '1.4'
      }
    },
    spacing: {
      xs: 4,
      sm: 8,
      md: 16,
      lg: 24,
      xl: 32
    },
    borderRadius: {
      sm: 4,
      md: 8,
      lg: 16
    }
  };
}

// CLI usage
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: tsx superset-to-ml.ts <superset-export.json>');
    process.exit(1);
  }
  
  const inputFile = args[0];
  
  try {
    const supersetData: SupersetDashboard = JSON.parse(fs.readFileSync(inputFile, 'utf8'));
    const dashboardML = extractDashboardML(supersetData);
    
    console.log(JSON.stringify(dashboardML, null, 2));
  } catch (error) {
    console.error('Error processing Superset export:', error);
    process.exit(1);
  }
}