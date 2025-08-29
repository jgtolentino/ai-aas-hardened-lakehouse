#!/usr/bin/env tsx
// Convert DashboardML to Figma Bridge commands
import fs from 'fs';
import { DashboardML, FigmaCreateDashboardCommand } from './types';

async function sendToFigmaBridge(commands: any[]): Promise<void> {
  const MCP_HUB_URL = process.env.MCP_HUB_URL || 'http://localhost:8787';
  
  for (const command of commands) {
    try {
      const response = await fetch(`${MCP_HUB_URL}/tools/figma/apply`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': process.env.HUB_API_KEY || 'development'
        },
        body: JSON.stringify(command)
      });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      const result = await response.json();
      console.log(`✅ Command ${command.type} sent successfully`);
      
      // Wait a bit between commands to avoid overwhelming Figma
      await new Promise(resolve => setTimeout(resolve, 500));
      
    } catch (error) {
      console.error(`❌ Failed to send command ${command.type}:`, error);
    }
  }
}

function generateFigmaCommands(dashboardML: DashboardML): any[] {
  const commands: any[] = [];
  
  // Get the main page
  const mainPage = dashboardML.pages[0];
  if (!mainPage) {
    throw new Error('No pages found in DashboardML');
  }
  
  // 1. Create main dashboard layout
  const dashboardCommand: FigmaCreateDashboardCommand = {
    type: 'create-dashboard-layout',
    title: dashboardML.title,
    grid: {
      cols: dashboardML.grid.type === '12-col' ? 12 : 24,
      gutter: dashboardML.grid.gutter
    },
    tiles: mainPage.tiles,
    theme: dashboardML.theme
  };
  
  commands.push(dashboardCommand);
  
  // 2. Apply brand tokens if available
  if (dashboardML.theme) {
    commands.push({
      type: 'apply-brand-tokens',
      tokens: dashboardML.theme
    });
  }
  
  // 3. Create individual components for complex tiles
  mainPage.tiles.forEach(tile => {
    if (tile.type === 'choropleth' || tile.type === 'funnel') {
      // These require custom components
      commands.push({
        type: 'create-component',
        name: `${tile.title || tile.id} Component`,
        width: (1440 / (dashboardML.grid.type === '12-col' ? 12 : 24)) * tile.w,
        height: tile.h * 120
      });
    }
  });
  
  // 4. Add Code Connect metadata as comments/descriptions
  const codeConnectData = generateCodeConnectMetadata(dashboardML);
  commands.push({
    type: 'add-metadata',
    metadata: codeConnectData
  });
  
  return commands;
}

function generateCodeConnectMetadata(dashboardML: DashboardML) {
  const metadata = {
    source: dashboardML.source,
    version: dashboardML.version,
    brand: dashboardML.brand,
    components: dashboardML.pages[0].tiles.map(tile => ({
      id: tile.id,
      type: tile.type,
      dataRef: tile.dataRef,
      config: tile.config,
      figmaProps: generateFigmaProps(tile)
    }))
  };
  
  return metadata;
}

function generateFigmaProps(tile: any) {
  // Generate props that would map to React components
  const baseProps = {
    title: tile.title,
    loading: false,
    error: null
  };
  
  switch (tile.type) {
    case 'metric':
      return {
        ...baseProps,
        value: '₱1.23M', // Placeholder
        delta: 4.2,
        format: tile.config?.format || 'currency',
        compare: tile.config?.compare || []
      };
      
    case 'line':
    case 'bar':
    case 'area':
      return {
        ...baseProps,
        chartType: tile.type,
        data: [], // Would be populated from dataRef
        xField: tile.config?.xField,
        yField: tile.config?.yField,
        series: tile.config?.series,
        showLegend: tile.config?.showLegend
      };
      
    case 'table':
      return {
        ...baseProps,
        columns: tile.config?.columns || [],
        data: [], // Would be populated from dataRef
        searchable: true,
        pagination: true
      };
      
    case 'choropleth':
      return {
        ...baseProps,
        geoData: [], // Would be populated
        valueField: tile.config?.valueField,
        colorScale: 'blue'
      };
      
    default:
      return baseProps;
  }
}

async function generateCodeConnectFiles(dashboardML: DashboardML): Promise<void> {
  const outputDir = 'apps/scout-ui/src/components/Dashboard';
  
  // Ensure output directory exists
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  
  // Generate a dashboard container component
  const containerComponent = generateDashboardContainer(dashboardML);
  fs.writeFileSync(`${outputDir}/DashboardContainer.tsx`, containerComponent);
  
  // Generate Code Connect mapping
  const codeConnectMapping = generateDashboardCodeConnect(dashboardML);
  fs.writeFileSync(`${outputDir}/DashboardContainer.figma.tsx`, codeConnectMapping);
  
  console.log(`📝 Generated Code Connect files in ${outputDir}/`);
}

function generateDashboardContainer(dashboardML: DashboardML): string {
  const mainPage = dashboardML.pages[0];
  
  return `import React from 'react';
import { KpiTile, DataTable, ChartCard, FilterPanel } from '../';

export interface DashboardContainerProps {
  title: string;
  loading?: boolean;
  data?: Record<string, any[]>;
  filters?: Record<string, any>;
  onFilterChange?: (key: string, value: any) => void;
}

export const DashboardContainer: React.FC<DashboardContainerProps> = ({
  title,
  loading = false,
  data = {},
  filters = {},
  onFilterChange
}) => {
  return (
    <div className="dashboard-container">
      <header className="dashboard-header">
        <h1 className="text-2xl font-semibold text-gray-900">{title}</h1>
        <div className="dashboard-filters">
          {/* Filters would go here */}
        </div>
      </header>
      
      <div className="dashboard-grid grid grid-cols-12 gap-4 p-6">
        ${mainPage.tiles.map(tile => {
          const colSpan = `col-span-${tile.w}`;
          const component = getTileComponent(tile);
          return `
        <div className="${colSpan}" style={{gridRow: '${tile.y + 1} / span ${tile.h}'}}>
          ${component}
        </div>`;
        }).join('')}
      </div>
    </div>
  );
};

export default DashboardContainer;`;
}

function getTileComponent(tile: any): string {
  switch (tile.type) {
    case 'metric':
      return `<KpiTile
            label="${tile.title}"
            value={data['${tile.id}']?.[0]?.value || '₱0'}
            delta={data['${tile.id}']?.[0]?.delta || 0}
            state={loading ? 'loading' : 'default'}
          />`;
          
    case 'line':
    case 'bar':
    case 'area':
      return `<ChartCard
            title="${tile.title}"
            chartType="${tile.type}"
            data={data['${tile.id}'] || []}
            loading={loading}
          />`;
          
    case 'table':
      return `<DataTable
            data={data['${tile.id}'] || []}
            columns={${JSON.stringify(tile.config?.columns || [])}}
            loading={loading}
          />`;
          
    default:
      return `<div className="p-4 border rounded-lg bg-gray-50">
            <h3 className="font-medium">${tile.title}</h3>
            <p className="text-sm text-gray-500">Component: ${tile.type}</p>
          </div>`;
  }
}

function generateDashboardCodeConnect(dashboardML: DashboardML): string {
  return `import { connect, figma } from "@figma/code-connect";
import { DashboardContainer } from "./DashboardContainer";

// Generated from ${dashboardML.source} dashboard: ${dashboardML.title}
const FILE_KEY = "dashboard-${dashboardML.source}-key";
const NODE_ID = "dashboard-container-node";

export default connect(DashboardContainer, figma.component(FILE_KEY, NODE_ID), {
  props: {
    title: figma.string("Dashboard Title", "${dashboardML.title}"),
    loading: figma.boolean("Loading State", false),
    data: figma.children("Dashboard Data"),
    filters: figma.children("Filter Values")
  },

  example: {
    title: "${dashboardML.title}",
    loading: false,
    data: {
      ${dashboardML.pages[0].tiles.map(tile => `
      "${tile.id}": [{ 
        value: "Sample Value", 
        label: "${tile.title}" 
      }]`).join(',')}
    },
    filters: {},
    onFilterChange: (key, value) => console.log("Filter changed:", key, value)
  },

  variants: [
    { props: { loading: true }, title: "Loading State" },
    { props: { title: "Custom Dashboard" }, title: "Custom Title" }
  ],
});`;
}

// CLI usage
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: tsx ml-to-figma.ts <dashboard.ml.json> [--generate-code-connect]');
    process.exit(1);
  }
  
  const inputFile = args[0];
  const generateCodeConnect = args.includes('--generate-code-connect');
  
  try {
    const dashboardML: DashboardML = JSON.parse(fs.readFileSync(inputFile, 'utf8'));
    
    console.log(`🚀 Converting ${dashboardML.title} to Figma...`);
    
    // Generate Figma commands
    const commands = generateFigmaCommands(dashboardML);
    
    console.log(`📤 Sending ${commands.length} commands to Figma Bridge...`);
    await sendToFigmaBridge(commands);
    
    // Generate Code Connect files if requested
    if (generateCodeConnect) {
      console.log('📝 Generating Code Connect files...');
      await generateCodeConnectFiles(dashboardML);
    }
    
    console.log('✅ Dashboard conversion complete!');
    
  } catch (error) {
    console.error('❌ Error converting dashboard:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}