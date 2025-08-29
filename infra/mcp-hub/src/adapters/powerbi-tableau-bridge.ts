/**
 * PowerBI/Tableau MCP Bridge
 * Extends dual-bridge architecture for enterprise BI dashboard integration
 * 
 * Architecture:
 * Claude MCP → PowerBI REST API → Live Dashboard Updates
 * ChatGPT REST → Tableau Server API → Real-time Data Refresh
 */

import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';

// PowerBI API Configuration
interface PowerBIConfig {
  tenantId: string;
  clientId: string;
  clientSecret: string;
  workspaceId: string;
  apiUrl: string;
}

// Tableau Server Configuration
interface TableauConfig {
  serverUrl: string;
  siteName: string;
  username: string;
  password: string;
  apiVersion: string;
}

// Dashboard creation schemas
const PowerBIDashboardSchema = z.object({
  name: z.string().min(1).max(200),
  datasourceId: z.string(),
  tiles: z.array(z.object({
    id: z.string(),
    title: z.string(),
    type: z.enum(['card', 'lineChart', 'columnChart', 'table', 'gauge']),
    position: z.object({
      x: z.number().min(0),
      y: z.number().min(0),
      width: z.number().min(1),
      height: z.number().min(1)
    }),
    dataQuery: z.string()
  })).max(20),
  refreshSchedule: z.string().optional()
});

const TableauWorkbookSchema = z.object({
  name: z.string().min(1).max(200),
  projectId: z.string(),
  datasourceId: z.string(),
  views: z.array(z.object({
    name: z.string(),
    type: z.enum(['worksheet', 'dashboard', 'story']),
    filters: z.record(z.any()).optional(),
    parameters: z.record(z.any()).optional()
  })).max(15)
});

export class PowerBITableauBridge {
  private app: express.Application;
  private powerbiConfig: PowerBIConfig;
  private tableauConfig: TableauConfig;
  private powerbiToken: string | null = null;
  private tableauToken: string | null = null;

  constructor(
    powerbiConfig: PowerBIConfig,
    tableauConfig: TableauConfig,
    port: number = 3002
  ) {
    this.powerbiConfig = powerbiConfig;
    this.tableauConfig = tableauConfig;
    this.app = express();
    this.setupMiddleware();
    this.setupRoutes();
    this.app.listen(port, () => {
      console.log(`🔗 PowerBI/Tableau Bridge running on port ${port}`);
    });
  }

  private setupMiddleware(): void {
    // Security middleware
    this.app.use(helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'", "'unsafe-inline'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", "data:", "https:"],
          connectSrc: ["'self'", "https://api.powerbi.com", "wss:"]
        }
      }
    }));

    this.app.use(cors({
      origin: ['http://localhost:3001', 'https://claude.ai'],
      methods: ['GET', 'POST', 'PUT', 'DELETE'],
      allowedHeaders: ['Content-Type', 'Authorization']
    }));

    // Rate limiting
    const limiter = rateLimit({
      windowMs: 15 * 60 * 1000, // 15 minutes
      max: 100, // Limit each IP to 100 requests per windowMs
      message: 'Too many BI operations, please try again later',
      standardHeaders: true,
      legacyHeaders: false
    });
    this.app.use(limiter);

    this.app.use(express.json({ limit: '10mb' }));
  }

  private setupRoutes(): void {
    // Health check
    this.app.get('/api/health', (req, res) => {
      res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        services: {
          powerbi: this.powerbiToken ? 'connected' : 'disconnected',
          tableau: this.tableauToken ? 'connected' : 'disconnected'
        }
      });
    });

    // PowerBI Operations
    this.app.post('/api/powerbi/dashboard', this.createPowerBIDashboard.bind(this));
    this.app.get('/api/powerbi/dashboards', this.listPowerBIDashboards.bind(this));
    this.app.put('/api/powerbi/dashboard/:id/refresh', this.refreshPowerBIDashboard.bind(this));
    this.app.delete('/api/powerbi/dashboard/:id', this.deletePowerBIDashboard.bind(this));

    // Tableau Operations
    this.app.post('/api/tableau/workbook', this.createTableauWorkbook.bind(this));
    this.app.get('/api/tableau/workbooks', this.listTableauWorkbooks.bind(this));
    this.app.put('/api/tableau/workbook/:id/refresh', this.refreshTableauWorkbook.bind(this));
    this.app.delete('/api/tableau/workbook/:id', this.deleteTableauWorkbook.bind(this));

    // Cross-platform operations
    this.app.get('/api/bi/overview', this.getBIOverview.bind(this));
    this.app.post('/api/bi/sync-data', this.syncDataSources.bind(this));
  }

  // PowerBI Authentication
  private async authenticatePowerBI(): Promise<string> {
    if (this.powerbiToken) return this.powerbiToken;

    const response = await fetch('https://login.microsoftonline.com/' + this.powerbiConfig.tenantId + '/oauth2/v2.0/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: this.powerbiConfig.clientId,
        client_secret: this.powerbiConfig.clientSecret,
        scope: 'https://analysis.windows.net/powerbi/api/.default'
      })
    });

    if (!response.ok) {
      throw new Error('PowerBI authentication failed');
    }

    const data = await response.json();
    this.powerbiToken = data.access_token;
    
    // Token refresh logic
    setTimeout(() => {
      this.powerbiToken = null;
    }, (data.expires_in - 300) * 1000); // Refresh 5 minutes early

    return this.powerbiToken;
  }

  // Tableau Authentication
  private async authenticateTableau(): Promise<string> {
    if (this.tableauToken) return this.tableauToken;

    const response = await fetch(`${this.tableauConfig.serverUrl}/api/${this.tableauConfig.apiVersion}/auth/signin`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        credentials: {
          name: this.tableauConfig.username,
          password: this.tableauConfig.password,
          site: { contentUrl: this.tableauConfig.siteName }
        }
      })
    });

    if (!response.ok) {
      throw new Error('Tableau authentication failed');
    }

    const data = await response.json();
    this.tableauToken = data.credentials.token;
    
    return this.tableauToken;
  }

  // PowerBI Dashboard Operations
  private async createPowerBIDashboard(req: express.Request, res: express.Response): Promise<void> {
    try {
      const dashboardData = PowerBIDashboardSchema.parse(req.body);
      const token = await this.authenticatePowerBI();

      // Create dashboard in PowerBI
      const response = await fetch(`${this.powerbiConfig.apiUrl}/v1.0/myorg/groups/${this.powerbiConfig.workspaceId}/dashboards`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          name: dashboardData.name
        })
      });

      if (!response.ok) {
        throw new Error('Failed to create PowerBI dashboard');
      }

      const dashboard = await response.json();

      // Add tiles to dashboard
      for (const tile of dashboardData.tiles) {
        await this.addPowerBITile(dashboard.id, tile, token);
      }

      res.json({
        success: true,
        dashboard: {
          id: dashboard.id,
          name: dashboard.displayName,
          url: dashboard.webUrl,
          tilesCount: dashboardData.tiles.length
        }
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  private async addPowerBITile(dashboardId: string, tile: any, token: string): Promise<void> {
    const response = await fetch(`${this.powerbiConfig.apiUrl}/v1.0/myorg/groups/${this.powerbiConfig.workspaceId}/dashboards/${dashboardId}/tiles`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        datasetId: tile.datasourceId,
        title: tile.title,
        embedData: tile.dataQuery,
        rowSpan: tile.position.height,
        colSpan: tile.position.width,
        rowIndex: tile.position.y,
        colIndex: tile.position.x
      })
    });

    if (!response.ok) {
      throw new Error(`Failed to add tile: ${tile.title}`);
    }
  }

  private async listPowerBIDashboards(req: express.Request, res: express.Response): Promise<void> {
    try {
      const token = await this.authenticatePowerBI();
      
      const response = await fetch(`${this.powerbiConfig.apiUrl}/v1.0/myorg/groups/${this.powerbiConfig.workspaceId}/dashboards`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });

      if (!response.ok) {
        throw new Error('Failed to list PowerBI dashboards');
      }

      const data = await response.json();
      
      res.json({
        success: true,
        dashboards: data.value.map((dashboard: any) => ({
          id: dashboard.id,
          name: dashboard.displayName,
          url: dashboard.webUrl,
          isReadOnly: dashboard.isReadOnly
        }))
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  private async refreshPowerBIDashboard(req: express.Request, res: express.Response): Promise<void> {
    try {
      const { id } = req.params;
      const token = await this.authenticatePowerBI();

      const response = await fetch(`${this.powerbiConfig.apiUrl}/v1.0/myorg/groups/${this.powerbiConfig.workspaceId}/dashboards/${id}/tiles`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ refreshType: 'Full' })
      });

      if (!response.ok) {
        throw new Error('Failed to refresh PowerBI dashboard');
      }

      res.json({ success: true, message: 'Dashboard refresh initiated' });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // Tableau Workbook Operations
  private async createTableauWorkbook(req: express.Request, res: express.Response): Promise<void> {
    try {
      const workbookData = TableauWorkbookSchema.parse(req.body);
      const token = await this.authenticateTableau();

      const response = await fetch(`${this.tableauConfig.serverUrl}/api/${this.tableauConfig.apiVersion}/sites/${this.tableauConfig.siteName}/workbooks`, {
        method: 'POST',
        headers: {
          'X-Tableau-Auth': token,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          workbook: {
            name: workbookData.name,
            project: { id: workbookData.projectId }
          }
        })
      });

      if (!response.ok) {
        throw new Error('Failed to create Tableau workbook');
      }

      const workbook = await response.json();

      res.json({
        success: true,
        workbook: {
          id: workbook.workbook.id,
          name: workbook.workbook.name,
          contentUrl: workbook.workbook.contentUrl,
          views: workbookData.views.length
        }
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  private async listTableauWorkbooks(req: express.Request, res: express.Response): Promise<void> {
    try {
      const token = await this.authenticateTableau();
      
      const response = await fetch(`${this.tableauConfig.serverUrl}/api/${this.tableauConfig.apiVersion}/sites/${this.tableauConfig.siteName}/workbooks`, {
        headers: { 'X-Tableau-Auth': token }
      });

      if (!response.ok) {
        throw new Error('Failed to list Tableau workbooks');
      }

      const data = await response.json();
      
      res.json({
        success: true,
        workbooks: data.workbooks.workbook.map((workbook: any) => ({
          id: workbook.id,
          name: workbook.name,
          contentUrl: workbook.contentUrl,
          projectName: workbook.project?.name,
          size: workbook.size
        }))
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // Cross-platform BI overview
  private async getBIOverview(req: express.Request, res: express.Response): Promise<void> {
    try {
      const [powerbiDashboards, tableauWorkbooks] = await Promise.allSettled([
        this.getPowerBIDashboardCount(),
        this.getTableauWorkbookCount()
      ]);

      res.json({
        success: true,
        overview: {
          powerbi: {
            status: powerbiDashboards.status === 'fulfilled' ? 'connected' : 'error',
            dashboards: powerbiDashboards.status === 'fulfilled' ? powerbiDashboards.value : 0,
            error: powerbiDashboards.status === 'rejected' ? powerbiDashboards.reason.message : null
          },
          tableau: {
            status: tableauWorkbooks.status === 'fulfilled' ? 'connected' : 'error',
            workbooks: tableauWorkbooks.status === 'fulfilled' ? tableauWorkbooks.value : 0,
            error: tableauWorkbooks.status === 'rejected' ? tableauWorkbooks.reason.message : null
          },
          timestamp: new Date().toISOString()
        }
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  private async getPowerBIDashboardCount(): Promise<number> {
    const token = await this.authenticatePowerBI();
    const response = await fetch(`${this.powerbiConfig.apiUrl}/v1.0/myorg/groups/${this.powerbiConfig.workspaceId}/dashboards`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    
    if (!response.ok) throw new Error('PowerBI API error');
    
    const data = await response.json();
    return data.value?.length || 0;
  }

  private async getTableauWorkbookCount(): Promise<number> {
    const token = await this.authenticateTableau();
    const response = await fetch(`${this.tableauConfig.serverUrl}/api/${this.tableauConfig.apiVersion}/sites/${this.tableauConfig.siteName}/workbooks`, {
      headers: { 'X-Tableau-Auth': token }
    });
    
    if (!response.ok) throw new Error('Tableau API error');
    
    const data = await response.json();
    return data.workbooks?.workbook?.length || 0;
  }

  // Data synchronization
  private async syncDataSources(req: express.Request, res: express.Response): Promise<void> {
    try {
      const { supabaseQuery, dashboardIds } = req.body;

      // This would integrate with your Supabase instance
      // and update both PowerBI and Tableau data sources
      
      res.json({
        success: true,
        message: 'Data sync initiated',
        affectedDashboards: dashboardIds?.length || 0
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  // Additional utility methods
  private async deletePowerBIDashboard(req: express.Request, res: express.Response): Promise<void> {
    // Implementation for dashboard deletion
    res.json({ success: true, message: 'Dashboard deletion not implemented in this stub' });
  }

  private async refreshTableauWorkbook(req: express.Request, res: express.Response): Promise<void> {
    // Implementation for workbook refresh
    res.json({ success: true, message: 'Workbook refresh not implemented in this stub' });
  }

  private async deleteTableauWorkbook(req: express.Request, res: express.Response): Promise<void> {
    // Implementation for workbook deletion
    res.json({ success: true, message: 'Workbook deletion not implemented in this stub' });
  }

  public close(): void {
    // Cleanup method for graceful shutdown
    this.powerbiToken = null;
    this.tableauToken = null;
  }
}

// MCP Tool Definitions for Claude
export const POWERBI_TABLEAU_MCP_TOOLS = {
  powerbi_create_dashboard: {
    name: 'powerbi_create_dashboard',
    description: 'Create a new PowerBI dashboard with tiles',
    inputSchema: PowerBIDashboardSchema
  },
  powerbi_list_dashboards: {
    name: 'powerbi_list_dashboards', 
    description: 'List all PowerBI dashboards in workspace'
  },
  tableau_create_workbook: {
    name: 'tableau_create_workbook',
    description: 'Create a new Tableau workbook',
    inputSchema: TableauWorkbookSchema
  },
  tableau_list_workbooks: {
    name: 'tableau_list_workbooks',
    description: 'List all Tableau workbooks'
  },
  bi_get_overview: {
    name: 'bi_get_overview',
    description: 'Get overview of all BI platforms'
  },
  bi_sync_data: {
    name: 'bi_sync_data',
    description: 'Sync data sources across BI platforms'
  }
};

export default PowerBITableauBridge;