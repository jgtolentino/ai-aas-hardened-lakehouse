/**
 * ChatGPT Database Bridge Adapter
 * Provides REST API endpoints for ChatGPT to access Supabase database
 * with full project context and enterprise schema awareness
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { EventEmitter } from 'events';
import express, { Express, Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

interface DatabaseConfig {
  supabaseUrl: string;
  supabaseKey: string;
  port?: number;
  enableCors?: boolean;
  rateLimitWindow?: number;
  rateLimitRequests?: number;
}

interface QueryRequest {
  query: string;
  schema?: string;
  params?: any[];
  operation?: 'select' | 'insert' | 'update' | 'delete' | 'raw';
}

interface SchemaInfo {
  schemas: string[];
  tables: Record<string, TableInfo>;
  views: Record<string, ViewInfo>;
  functions: Record<string, FunctionInfo>;
}

interface TableInfo {
  schema: string;
  name: string;
  columns: ColumnInfo[];
  primaryKey: string[];
  foreignKeys: ForeignKeyInfo[];
  indexes: IndexInfo[];
  rowCount: number;
}

interface ColumnInfo {
  name: string;
  type: string;
  nullable: boolean;
  default: any;
  description?: string;
}

interface ViewInfo {
  schema: string;
  name: string;
  definition: string;
  columns: ColumnInfo[];
}

interface FunctionInfo {
  schema: string;
  name: string;
  parameters: ParameterInfo[];
  returnType: string;
  description?: string;
}

interface ParameterInfo {
  name: string;
  type: string;
  required: boolean;
}

interface ForeignKeyInfo {
  column: string;
  referencedTable: string;
  referencedColumn: string;
  referencedSchema: string;
}

interface IndexInfo {
  name: string;
  columns: string[];
  unique: boolean;
}

export class ChatGPTDatabaseBridge extends EventEmitter {
  private supabase: SupabaseClient;
  private app: Express;
  private config: DatabaseConfig;
  private server: any;

  // Enterprise schemas for TBWA
  private readonly ENTERPRISE_SCHEMAS = [
    'hr_admin',
    'financial_ops', 
    'operations',
    'corporate',
    'creative_insights',
    'scout_dash',
    'public'
  ];

  constructor(config: DatabaseConfig) {
    super();
    this.config = {
      port: 3001,
      enableCors: true,
      rateLimitWindow: 15 * 60 * 1000, // 15 minutes
      rateLimitRequests: 100, // requests per window
      ...config
    };

    // Initialize Supabase client
    this.supabase = createClient(this.config.supabaseUrl, this.config.supabaseKey);
    
    // Initialize Express app
    this.app = express();
    this.setupMiddleware();
    this.setupRoutes();
  }

  private setupMiddleware(): void {
    // Security middleware
    this.app.use(helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          scriptSrc: ["'self'"]
        }
      }
    }));

    // CORS for ChatGPT
    if (this.config.enableCors) {
      this.app.use(cors({
        origin: [
          'https://chat.openai.com',
          'https://chatgpt.com',
          'http://localhost:3000',
          'http://localhost:3001'
        ],
        credentials: true
      }));
    }

    // Rate limiting
    const limiter = rateLimit({
      windowMs: this.config.rateLimitWindow!,
      max: this.config.rateLimitRequests!,
      message: { 
        error: 'Too many requests from this IP, please try again later.',
        retryAfter: this.config.rateLimitWindow! / 1000
      }
    });
    this.app.use('/api/', limiter);

    // Body parsing
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true }));
  }

  private setupRoutes(): void {
    // Health check
    this.app.get('/health', (req: Request, res: Response) => {
      res.json({ 
        status: 'healthy',
        timestamp: new Date().toISOString(),
        service: 'ChatGPT Database Bridge',
        version: '1.0.0'
      });
    });

    // Database schema introspection
    this.app.get('/api/schema', this.handleGetSchema.bind(this));
    this.app.get('/api/schema/:schemaName', this.handleGetSchemaDetails.bind(this));

    // Query execution
    this.app.post('/api/query', this.handleQuery.bind(this));
    this.app.post('/api/query/safe', this.handleSafeQuery.bind(this));

    // Table operations
    this.app.get('/api/tables', this.handleGetTables.bind(this));
    this.app.get('/api/tables/:schema/:table', this.handleGetTableDetails.bind(this));
    this.app.get('/api/tables/:schema/:table/data', this.handleGetTableData.bind(this));

    // Enterprise-specific endpoints
    this.app.get('/api/enterprise/overview', this.handleEnterpriseOverview.bind(this));
    this.app.get('/api/enterprise/kpis', this.handleEnterpriseKPIs.bind(this));

    // Error handling
    this.app.use(this.handleError.bind(this));
  }

  private async handleGetSchema(req: Request, res: Response): Promise<void> {
    try {
      const schemaInfo = await this.getFullSchemaInfo();
      res.json({
        success: true,
        data: schemaInfo,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      this.handleError(error, req, res, () => {});
    }
  }

  private async handleGetSchemaDetails(req: Request, res: Response): Promise<void> {
    try {
      const { schemaName } = req.params;
      
      if (!this.ENTERPRISE_SCHEMAS.includes(schemaName)) {
        res.status(400).json({
          success: false,
          error: `Invalid schema. Available schemas: ${this.ENTERPRISE_SCHEMAS.join(', ')}`
        });
        return;
      }

      const tables = await this.getSchemaDetails(schemaName);
      res.json({
        success: true,
        data: { schema: schemaName, tables },
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      this.handleError(error, req, res, () => {});
    }
  }

  private async handleQuery(req: Request, res: Response): Promise<void> {
    try {
      const queryRequest: QueryRequest = req.body;
      
      // Validate query
      const validation = this.validateQuery(queryRequest);
      if (!validation.valid) {
        res.status(400).json({
          success: false,
          error: validation.error,
          suggestions: validation.suggestions
        });
        return;
      }

      // Execute query
      const result = await this.executeQuery(queryRequest);
      
      res.json({
        success: true,
        data: result.data,
        metadata: {
          rowCount: result.count,
          executionTime: result.executionTime,
          query: queryRequest.query,
          schema: queryRequest.schema
        },
        timestamp: new Date().toISOString()
      });

      // Log usage
      this.emit('query_executed', {
        query: queryRequest.query,
        schema: queryRequest.schema,
        rowCount: result.count,
        executionTime: result.executionTime
      });

    } catch (error) {
      this.handleError(error, req, res, () => {});
    }
  }

  private async handleSafeQuery(req: Request, res: Response): Promise<void> {
    try {
      const { query } = req.body;
      
      // Only allow SELECT queries
      if (!query.trim().toUpperCase().startsWith('SELECT')) {
        res.status(400).json({
          success: false,
          error: 'Only SELECT queries are allowed in safe mode'
        });
        return;
      }

      const result = await this.supabase.rpc('execute_safe_query', { 
        query_text: query 
      });

      if (result.error) {
        throw result.error;
      }

      res.json({
        success: true,
        data: result.data,
        mode: 'safe',
        timestamp: new Date().toISOString()
      });

    } catch (error) {
      this.handleError(error, req, res, () => {});
    }
  }

  private async handleGetTables(req: Request, res: Response): Promise<void> {
    try {
      const tables = await this.getAllTables();
      res.json({
        success: true,
        data: tables,
        count: tables.length,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      this.handleError(error, req, res, () => {});
    }
  }

  private async handleGetTableDetails(req: Request, res: Response): Promise<void> {
    try {
      const { schema, table } = req.params;
      const tableInfo = await this.getTableInfo(schema, table);
      
      res.json({
        success: true,
        data: tableInfo,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      this.handleError(error, req, res, () => {});
    }
  }

  private async handleGetTableData(req: Request, res: Response): Promise<void> {
    try {
      const { schema, table } = req.params;
      const { limit = 100, offset = 0 } = req.query;
      
      const { data, error, count } = await this.supabase
        .from(`${schema}.${table}`)
        .select('*', { count: 'exact' })
        .range(Number(offset), Number(offset) + Number(limit) - 1);

      if (error) throw error;

      res.json({
        success: true,
        data: data,
        metadata: {
          total: count,
          limit: Number(limit),
          offset: Number(offset),
          schema,
          table
        },
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      this.handleError(error, req, res, () => {});
    }
  }

  private async handleEnterpriseOverview(req: Request, res: Response): Promise<void> {
    try {
      const overview = await this.getEnterpriseOverview();
      res.json({
        success: true,
        data: overview,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      this.handleError(error, req, res, () => {});
    }
  }

  private async handleEnterpriseKPIs(req: Request, res: Response): Promise<void> {
    try {
      const kpis = await this.getEnterpriseKPIs();
      res.json({
        success: true,
        data: kpis,
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      this.handleError(error, req, res, () => {});
    }
  }

  private async getFullSchemaInfo(): Promise<SchemaInfo> {
    const { data: schemas, error: schemaError } = await this.supabase
      .rpc('get_enterprise_schemas');

    if (schemaError) throw schemaError;

    const schemaInfo: SchemaInfo = {
      schemas: this.ENTERPRISE_SCHEMAS,
      tables: {},
      views: {},
      functions: {}
    };

    // Get tables for each schema
    for (const schema of this.ENTERPRISE_SCHEMAS) {
      const tables = await this.getSchemaDetails(schema);
      Object.assign(schemaInfo.tables, tables);
    }

    return schemaInfo;
  }

  private async getSchemaDetails(schemaName: string): Promise<Record<string, TableInfo>> {
    const { data: tables, error } = await this.supabase
      .rpc('get_schema_tables', { schema_name: schemaName });

    if (error) throw error;

    const tableInfo: Record<string, TableInfo> = {};

    for (const table of tables || []) {
      const columns = await this.getTableColumns(schemaName, table.table_name);
      tableInfo[`${schemaName}.${table.table_name}`] = {
        schema: schemaName,
        name: table.table_name,
        columns,
        primaryKey: [],
        foreignKeys: [],
        indexes: [],
        rowCount: table.row_count || 0
      };
    }

    return tableInfo;
  }

  private async getTableColumns(schema: string, table: string): Promise<ColumnInfo[]> {
    const { data: columns, error } = await this.supabase
      .rpc('get_table_columns', { 
        schema_name: schema, 
        table_name: table 
      });

    if (error) throw error;

    return columns?.map((col: any) => ({
      name: col.column_name,
      type: col.data_type,
      nullable: col.is_nullable === 'YES',
      default: col.column_default,
      description: col.description
    })) || [];
  }

  private async getAllTables(): Promise<any[]> {
    const { data: tables, error } = await this.supabase
      .rpc('get_all_enterprise_tables');

    if (error) throw error;
    return tables || [];
  }

  private async getTableInfo(schema: string, table: string): Promise<TableInfo> {
    const columns = await this.getTableColumns(schema, table);
    
    const { data: tableStats, error } = await this.supabase
      .rpc('get_table_stats', { 
        schema_name: schema, 
        table_name: table 
      });

    if (error) throw error;

    return {
      schema,
      name: table,
      columns,
      primaryKey: tableStats?.primary_keys || [],
      foreignKeys: tableStats?.foreign_keys || [],
      indexes: tableStats?.indexes || [],
      rowCount: tableStats?.row_count || 0
    };
  }

  private async getEnterpriseOverview(): Promise<any> {
    const { data: overview, error } = await this.supabase
      .rpc('get_enterprise_overview');

    if (error) throw error;
    return overview;
  }

  private async getEnterpriseKPIs(): Promise<any> {
    const { data: kpis, error } = await this.supabase
      .rpc('get_enterprise_kpis');

    if (error) throw error;
    return kpis;
  }

  private validateQuery(request: QueryRequest): { valid: boolean; error?: string; suggestions?: string[] } {
    if (!request.query || typeof request.query !== 'string') {
      return { 
        valid: false, 
        error: 'Query is required and must be a string',
        suggestions: ['Provide a valid SQL query string']
      };
    }

    const query = request.query.trim().toUpperCase();
    
    // Block dangerous operations
    const dangerousOperations = ['DROP', 'TRUNCATE', 'DELETE', 'ALTER'];
    for (const op of dangerousOperations) {
      if (query.includes(op)) {
        return { 
          valid: false, 
          error: `Dangerous operation '${op}' is not allowed`,
          suggestions: ['Use SELECT, INSERT, or UPDATE operations only']
        };
      }
    }

    // Validate schema if provided
    if (request.schema && !this.ENTERPRISE_SCHEMAS.includes(request.schema)) {
      return { 
        valid: false, 
        error: `Invalid schema '${request.schema}'`,
        suggestions: [`Available schemas: ${this.ENTERPRISE_SCHEMAS.join(', ')}`]
      };
    }

    return { valid: true };
  }

  private async executeQuery(request: QueryRequest): Promise<{ data: any; count: number; executionTime: number }> {
    const startTime = Date.now();
    
    const { data, error, count } = await this.supabase
      .rpc('execute_enterprise_query', {
        query_text: request.query,
        query_params: request.params || [],
        target_schema: request.schema
      });

    if (error) throw error;

    const executionTime = Date.now() - startTime;
    
    return {
      data: data || [],
      count: count || 0,
      executionTime
    };
  }

  private handleError(error: any, req: Request, res: Response, next: Function): void {
    console.error('ChatGPT Database Bridge Error:', error);

    const errorResponse = {
      success: false,
      error: error.message || 'Internal server error',
      timestamp: new Date().toISOString(),
      requestId: req.headers['x-request-id'] || 'unknown'
    };

    // Log error for monitoring
    this.emit('error', {
      error: error.message,
      stack: error.stack,
      url: req.url,
      method: req.method,
      timestamp: new Date().toISOString()
    });

    res.status(error.status || 500).json(errorResponse);
  }

  public async start(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.server = this.app.listen(this.config.port, () => {
        console.log(`🤖 ChatGPT Database Bridge running on port ${this.config.port}`);
        console.log(`📊 Enterprise schemas available: ${this.ENTERPRISE_SCHEMAS.join(', ')}`);
        console.log(`🔗 Health check: http://localhost:${this.config.port}/health`);
        console.log(`📋 Schema info: http://localhost:${this.config.port}/api/schema`);
        
        this.emit('server_started', {
          port: this.config.port,
          timestamp: new Date().toISOString()
        });
        
        resolve();
      });

      this.server.on('error', (error: Error) => {
        console.error('Server error:', error);
        this.emit('server_error', error);
        reject(error);
      });
    });
  }

  public async stop(): Promise<void> {
    if (this.server) {
      return new Promise((resolve) => {
        this.server.close(() => {
          console.log('🛑 ChatGPT Database Bridge stopped');
          this.emit('server_stopped', {
            timestamp: new Date().toIsoString()
          });
          resolve();
        });
      });
    }
  }

  public getConnectionInfo(): any {
    return {
      port: this.config.port,
      baseUrl: `http://localhost:${this.config.port}`,
      schemas: this.ENTERPRISE_SCHEMAS,
      endpoints: {
        health: '/health',
        schema: '/api/schema',
        query: '/api/query',
        tables: '/api/tables',
        enterprise: '/api/enterprise/overview'
      }
    };
  }
}

// Factory function for easy instantiation
export function createChatGPTDatabaseBridge(config: DatabaseConfig): ChatGPTDatabaseBridge {
  return new ChatGPTDatabaseBridge(config);
}

// Export types for external use
export type {
  DatabaseConfig,
  QueryRequest,
  SchemaInfo,
  TableInfo,
  ColumnInfo
};