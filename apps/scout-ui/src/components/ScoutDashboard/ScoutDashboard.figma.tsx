import { connect, figma } from "@figma/code-connect";
import { ScoutDashboard } from "./ScoutDashboard";

// Scout Dashboard Code Connect Bridge
// Maps Scout Dashboard React component to Figma design system
const FILE_KEY = "Rjh4xxbrZr8otmfpPqiVPC"; // Financial Dashboard UI Kit
const NODE_ID = "56-1396"; // Dashboard node from Figma URL

export default connect(ScoutDashboard, figma.component(FILE_KEY, NODE_ID), {
  props: {
    // Time range filter mapping
    timeRange: figma.enum("Time Range", {
      "7 days": "7d",
      "30 days": "30d", 
      "90 days": "90d",
      "1 year": "1y"
    }),

    // Department filter mapping
    department: figma.enum("Department", {
      "All": "all",
      "Creative": "creative",
      "Account Management": "account", 
      "Strategy": "strategy"
    }),

    // Theme and styling
    className: figma.string("CSS Classes", "w-full min-h-screen bg-gray-50"),

    // Data loading state
    loading: figma.boolean("Loading State", false)
  },

  example: {
    timeRange: "30d",
    department: "all", 
    className: "scout-dashboard-container",
    loading: false
  },

  variants: [
    {
      props: { loading: true },
      title: "Loading State",
      description: "Dashboard with loading indicators"
    },
    {
      props: { timeRange: "7d", department: "creative" },
      title: "Creative Department - Weekly",
      description: "Creative department view with 7-day time range"
    },
    {
      props: { timeRange: "1y", department: "all" },
      title: "Annual Overview",
      description: "Complete annual performance overview"
    }
  ],

  // Nested component mappings for Figma Bridge Plugin
  nestedComponents: {
    // KPI Tiles mapping to financial cards
    kpiTiles: figma.children("KPI Cards", {
      totalRevenue: {
        figma: "Balance Card/Primary",
        react: "KpiTile",
        props: {
          label: "Total Revenue",
          value: "₱2,847,350",
          trend: { value: 12.5, direction: "up" },
          currency: "₱"
        }
      },
      activeCampaigns: {
        figma: "Balance Card/Secondary", 
        react: "KpiTile",
        props: {
          label: "Active Campaigns",
          value: "24",
          trend: { value: 8.3, direction: "up" }
        }
      },
      clientSatisfaction: {
        figma: "Performance Card/Success",
        react: "KpiTile", 
        props: {
          label: "Client Satisfaction",
          value: "94.2%",
          trend: { value: 2.1, direction: "up" }
        }
      },
      avgCampaignROI: {
        figma: "Performance Card/Warning",
        react: "KpiTile",
        props: {
          label: "Avg Campaign ROI", 
          value: "385%",
          trend: { value: -5.2, direction: "down" }
        }
      }
    }),

    // Chart components mapping
    charts: figma.children("Chart Components", {
      revenueTrend: {
        figma: "Revenue Chart/Line",
        react: "ChartCard",
        props: {
          title: "Revenue Trend",
          subtitle: "Monthly revenue and campaign count",
          chartType: "line",
          height: 300
        }
      },
      campaignPerformance: {
        figma: "Revenue Chart/Bar", 
        react: "ChartCard",
        props: {
          title: "Campaign Performance",
          subtitle: "Performance scores by campaign", 
          chartType: "bar",
          height: 300
        }
      }
    }),

    // Data table mapping
    campaignTable: {
      figma: "Transaction List/Extended",
      react: "DataTable",
      props: {
        searchable: true,
        pagination: true,
        pageSize: 10
      }
    },

    // Filter panel mapping
    filterPanel: {
      figma: "Filter Panel/Multi-Select",
      react: "FilterPanel", 
      props: {
        title: "Dashboard Filters"
      }
    }
  },

  // Figma Bridge Plugin automation
  bridgeConfig: {
    // Auto-sync design tokens
    designTokens: {
      colors: {
        primary: "#3B82F6",    // Blue primary from Scout theme
        success: "#10B981",    // Green for positive metrics
        warning: "#F59E0B",    // Amber for alerts  
        danger: "#EF4444"      // Red for negative trends
      },
      
      spacing: {
        cardPadding: 24,       // Standard card padding
        gridGap: 24,           // Gap between dashboard sections
        kpiSpacing: 16         // Spacing within KPI tiles
      },

      typography: {
        dashboardTitle: "text-3xl font-bold text-gray-900",
        sectionTitle: "text-lg font-semibold text-gray-900", 
        metricValue: "text-2xl font-bold text-gray-900",
        metricLabel: "text-sm font-medium text-gray-600"
      }
    },

    // Layout automation
    layoutRules: {
      kpiGrid: "grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6",
      chartGrid: "grid-cols-1 lg:grid-cols-2 gap-6", 
      tableContainer: "bg-white rounded-lg shadow",
      insightPanel: "bg-gradient-to-br from-blue-50 to-indigo-50"
    },

    // Responsive breakpoints
    breakpoints: {
      mobile: { maxWidth: 768, kpiCols: 1, chartCols: 1 },
      tablet: { maxWidth: 1024, kpiCols: 2, chartCols: 1 },
      desktop: { minWidth: 1025, kpiCols: 4, chartCols: 2 }
    }
  }
});

// Export for Figma Bridge Plugin integration
export const ScoutDashboardFigmaConfig = {
  component: "ScoutDashboard",
  fileKey: FILE_KEY,
  nodeId: NODE_ID,
  bridge: true,
  autoSync: true,
  
  // Data binding configuration
  dataBinding: {
    // Live data from Supabase
    supabaseQueries: {
      metrics: "SELECT * FROM scout_dash.dashboard_kpis WHERE active = true",
      campaigns: "SELECT * FROM scout_dash.campaigns WHERE status IN ('active', 'paused')",  
      regionalData: "SELECT * FROM scout_dash.regional_performance ORDER BY total_sales DESC",
      revenueData: "SELECT * FROM scout_dash.revenue_trends WHERE date >= NOW() - INTERVAL '12 months'"
    },
    
    // Refresh intervals
    refreshRate: {
      metrics: 30000,        // 30 seconds
      campaigns: 60000,      // 1 minute  
      regionalData: 300000,  // 5 minutes
      revenueData: 600000    // 10 minutes
    }
  }
};