// DashboardML - Neutral schema for dashboard extraction
export interface DashboardML {
  title: string;
  brand: string;
  version: string;
  source: 'superset' | 'tableau' | 'powerbi' | 'custom';
  grid: {
    type: '12-col' | '24-col' | 'free';
    gutter: number;
    margin: number;
  };
  pages: DashboardPage[];
  datasources: DataSource[];
  theme?: BrandTheme;
}

export interface DashboardPage {
  name: string;
  filters: FilterConfig[];
  tiles: DashboardTile[];
  layout?: LayoutConfig;
}

export interface FilterConfig {
  id: string;
  type: 'date_range' | 'select' | 'multi_select' | 'text' | 'number';
  label: string;
  options?: Array<{ value: string; label: string }>;
  defaultValue?: any;
}

export interface DashboardTile {
  id: string;
  type: 'metric' | 'line' | 'bar' | 'pie' | 'area' | 'table' | 'choropleth' | 'scatter' | 'funnel';
  w: number; // grid width
  h: number; // grid height
  x: number; // grid x position
  y: number; // grid y position
  
  // Data binding
  dataRef: DataReference;
  
  // Visual properties
  title?: string;
  subtitle?: string;
  showLegend?: boolean;
  showAxes?: boolean;
  
  // Type-specific config
  config?: {
    // Metric tiles
    metric?: string;
    format?: 'currency' | 'percentage' | 'number';
    compare?: Array<'WoW' | 'MoM' | 'YoY'>;
    
    // Chart tiles
    xField?: string;
    yField?: string;
    series?: string;
    colorField?: string;
    
    // Geographic tiles
    geoField?: string;
    valueField?: string;
    mapType?: 'world' | 'usa' | 'custom';
    
    // Table tiles
    columns?: Array<{
      key: string;
      label: string;
      format?: string;
      sortable?: boolean;
    }>;
  };
}

export interface DataReference {
  source: string;
  dataset: string;
  query?: string;
  fields: DataField[];
  filters?: Record<string, any>;
}

export interface DataField {
  name: string;
  type: 'dimension' | 'measure' | 'time';
  dataType: 'string' | 'number' | 'date' | 'boolean';
  aggregation?: 'sum' | 'avg' | 'count' | 'min' | 'max';
}

export interface DataSource {
  id: string;
  type: 'sql' | 'api' | 'file';
  dialect?: 'postgres' | 'mysql' | 'mssql' | 'bigquery';
  connection: string;
  tables: DataTable[];
}

export interface DataTable {
  name: string;
  schema?: string;
  columns: DataColumn[];
}

export interface DataColumn {
  name: string;
  type: string;
  nullable: boolean;
  primaryKey?: boolean;
}

export interface BrandTheme {
  colors: {
    primary: string;
    secondary: string;
    accent: string;
    success: string;
    warning: string;
    error: string;
    background: string;
    surface: string;
    text: string;
    textSecondary: string;
  };
  typography: {
    fontFamily: string;
    heading: {
      fontSize: string;
      fontWeight: string;
      lineHeight: string;
    };
    body: {
      fontSize: string;
      fontWeight: string;
      lineHeight: string;
    };
    caption: {
      fontSize: string;
      fontWeight: string;
      lineHeight: string;
    };
  };
  spacing: {
    xs: number;
    sm: number;
    md: number;
    lg: number;
    xl: number;
  };
  borderRadius: {
    sm: number;
    md: number;
    lg: number;
  };
}

export interface LayoutConfig {
  padding: number;
  gap: number;
  maxWidth?: number;
}

// Figma Bridge Commands
export interface FigmaBridgeCommand {
  type: string;
  [key: string]: any;
}

export interface FigmaCreateDashboardCommand extends FigmaBridgeCommand {
  type: 'create-dashboard-layout';
  title: string;
  grid: { cols: number; gutter: number };
  tiles: DashboardTile[];
  theme?: BrandTheme;
}

// Superset Export Types
export interface SupersetDashboard {
  id: number;
  dashboard_title: string;
  slug: string;
  position_json: string;
  json_metadata: string;
  css: string;
  slices: SupersetChart[];
}

export interface SupersetChart {
  id: number;
  slice_name: string;
  viz_type: string;
  params: string;
  query_context: string;
  datasource_id: number;
  datasource_type: string;
}

// Usage Analytics Types
export interface DesignUsageLog {
  id?: string;
  team_id: string;
  component_id: string;
  action: 'insert' | 'detach' | 'override' | 'create' | 'rename' | 'place';
  platform: 'web' | 'mobile' | 'figma' | 'figjam';
  context: Record<string, any>;
  created_at: string;
}

export interface ComponentUsageStats {
  component_id: string;
  component_name: string;
  total_usage: number;
  detachment_rate: number;
  teams_using: number;
  files_using: number;
  last_used: string;
  trend: 'up' | 'down' | 'stable';
}