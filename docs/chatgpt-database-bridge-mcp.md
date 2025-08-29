# ChatGPT Database Bridge MCP

Complete guide to TBWA's ChatGPT Database Bridge enabling secure database access via REST API through the MCP Hub architecture.

## Overview

The ChatGPT Database Bridge solves the limitation that ChatGPT cannot directly use the Model Context Protocol (MCP) like Claude. This architecture enables ChatGPT to perform database operations by:

1. **REST API Bridge**: HTTP endpoints compatible with ChatGPT's function calling
2. **MCP Hub Integration**: Leverages existing MCP Hub infrastructure
3. **Supabase RPC Functions**: Secure database operations with validation
4. **Enterprise Schema Access**: TBWA's unified data platform access

## Architecture

```mermaid
graph TB
    ChatGPT[ChatGPT] --> REST[REST API Bridge<br/>localhost:3001]
    REST --> Supabase[(Supabase Database<br/>TBWA Enterprise)]
    REST --> RPC[RPC Functions<br/>Validation Layer]
    RPC --> Schemas[Enterprise Schemas<br/>hr_admin, financial_ops, operations,<br/>corporate, creative_insights, scout_dash]
    
    subgraph "Security Boundary"
        REST
        RPC
    end
    
    style ChatGPT fill:#10a37f
    style REST fill:#ff6b35
    style Supabase fill:#3ecf8e
```

## Installation & Setup

### 1. Apply Database Migration

Run the Supabase migration to create secure RPC functions:

```bash
# Apply the ChatGPT bridge functions
supabase db push

# Or apply manually in Supabase SQL Editor
# Copy contents of: supabase/migrations/20250128_chatgpt_bridge_functions.sql
```

### 2. Start the Bridge Server

```bash
# Navigate to MCP Hub directory
cd infra/mcp-hub

# Install dependencies
npm install

# Build TypeScript
npm run build

# Start ChatGPT Database Bridge
node -e "
const { ChatGPTDatabaseBridge } = require('./dist/adapters/chatgpt-database-bridge.js');

const bridge = new ChatGPTDatabaseBridge({
  port: 3001,
  supabaseUrl: 'https://cxzllzyxwpyptfretryc.supabase.co',
  supabaseKey: process.env.SUPABASE_SERVICE_ROLE_KEY
});

console.log('🤖 ChatGPT Database Bridge running on http://localhost:3001');
"
```

### 3. Configure Environment Variables

```bash
# Set Supabase credentials
export SUPABASE_URL="https://cxzllzyxwpyptfretryc.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
export SUPABASE_ANON_KEY="your-anon-key"
```

## API Endpoints

### Base URL
```
http://localhost:3001/api
```

### Authentication

All requests require the Supabase service role key in the Authorization header:

```bash
Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>
```

### Available Endpoints

#### 1. Get Enterprise Overview
```http
GET /api/overview
```

**Response**:
```json
{
  "success": true,
  "data": {
    "total_tables": 42,
    "schemas": [
      {
        "name": "hr_admin",
        "table_count": 8
      },
      {
        "name": "financial_ops", 
        "table_count": 6
      }
    ],
    "last_updated": "2025-01-28T10:30:00Z"
  }
}
```

#### 2. List Enterprise Schemas
```http
GET /api/schemas
```

**Response**:
```json
{
  "success": true,
  "data": [
    "hr_admin",
    "financial_ops", 
    "operations",
    "corporate",
    "creative_insights",
    "scout_dash",
    "public"
  ]
}
```

#### 3. List Tables in Schema
```http
GET /api/schema/{schema_name}/tables
```

**Example**:
```bash
curl http://localhost:3001/api/schema/hr_admin/tables \
  -H "Authorization: Bearer your-service-role-key"
```

**Response**:
```json
{
  "success": true,
  "data": [
    {
      "table_name": "employees",
      "table_type": "BASE TABLE",
      "row_count": 245,
      "table_comment": "Employee master data"
    },
    {
      "table_name": "departments",
      "table_type": "BASE TABLE", 
      "row_count": 12,
      "table_comment": "Organizational departments"
    }
  ]
}
```

#### 4. Get Table Schema
```http
GET /api/schema/{schema_name}/table/{table_name}
```

**Example**:
```bash
curl http://localhost:3001/api/schema/hr_admin/table/employees \
  -H "Authorization: Bearer your-service-role-key"
```

**Response**:
```json
{
  "success": true,
  "data": {
    "columns": [
      {
        "column_name": "id",
        "data_type": "uuid",
        "is_nullable": "NO",
        "column_default": "gen_random_uuid()",
        "description": "Primary key"
      },
      {
        "column_name": "employee_id",
        "data_type": "text",
        "is_nullable": "NO",
        "column_default": null,
        "description": "Unique employee identifier"
      }
    ],
    "statistics": {
      "row_count": 245,
      "size_bytes": 32768,
      "primary_keys": ["id"],
      "foreign_keys": [
        {
          "column": "department_id",
          "referenced_table": "departments",
          "referenced_column": "id",
          "referenced_schema": "hr_admin"
        }
      ]
    }
  }
}
```

#### 5. Execute Safe Query (SELECT only)
```http
POST /api/query/safe
```

**Request Body**:
```json
{
  "query": "SELECT employee_id, full_name, department FROM hr_admin.employees WHERE status = 'active' LIMIT 10"
}
```

**Response**:
```json
{
  "success": true,
  "data": [
    {
      "employee_id": "EMP001",
      "full_name": "John Smith",
      "department": "Engineering"
    }
  ],
  "execution_time_ms": 23,
  "row_count": 10
}
```

#### 6. Execute Enterprise Query (With Parameters)
```http
POST /api/query
```

**Request Body**:
```json
{
  "query": "SELECT * FROM hr_admin.employees WHERE department_id = $1 AND hire_date >= $2",
  "parameters": ["dept-123", "2024-01-01"],
  "target_schema": "hr_admin"
}
```

#### 7. Get Enterprise KPIs
```http
GET /api/kpis
```

**Response**:
```json
{
  "success": true,
  "data": {
    "employee_count": 245,
    "active_projects": 18,
    "total_budget": 2450000.00,
    "active_campaigns": 7,
    "compliance_score": 98.5,
    "last_calculated": "2025-01-28T10:30:00Z"
  }
}
```

## ChatGPT Function Definitions

Configure these functions in ChatGPT to enable database access:

### 1. Get Database Overview

```json
{
  "name": "get_enterprise_overview",
  "description": "Get overview of TBWA enterprise database with schema and table statistics",
  "parameters": {
    "type": "object",
    "properties": {},
    "required": []
  }
}
```

### 2. List Database Schemas

```json
{
  "name": "list_enterprise_schemas", 
  "description": "List all available enterprise schemas in TBWA database",
  "parameters": {
    "type": "object",
    "properties": {},
    "required": []
  }
}
```

### 3. Get Schema Tables

```json
{
  "name": "get_schema_tables",
  "description": "Get all tables in a specific enterprise schema",
  "parameters": {
    "type": "object",
    "properties": {
      "schema_name": {
        "type": "string",
        "description": "Schema name (hr_admin, financial_ops, operations, corporate, creative_insights, scout_dash, public)",
        "enum": ["hr_admin", "financial_ops", "operations", "corporate", "creative_insights", "scout_dash", "public"]
      }
    },
    "required": ["schema_name"]
  }
}
```

### 4. Get Table Details

```json
{
  "name": "get_table_details",
  "description": "Get detailed information about a specific table including columns and statistics",
  "parameters": {
    "type": "object", 
    "properties": {
      "schema_name": {
        "type": "string",
        "description": "Schema name",
        "enum": ["hr_admin", "financial_ops", "operations", "corporate", "creative_insights", "scout_dash", "public"]
      },
      "table_name": {
        "type": "string",
        "description": "Table name"
      }
    },
    "required": ["schema_name", "table_name"]
  }
}
```

### 5. Execute Safe Query

```json
{
  "name": "execute_safe_query",
  "description": "Execute a SELECT-only query safely (no modifications allowed)",
  "parameters": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "SELECT query to execute (INSERT, UPDATE, DELETE not allowed)"
      }
    },
    "required": ["query"]
  }
}
```

### 6. Execute Enterprise Query

```json
{
  "name": "execute_enterprise_query",
  "description": "Execute a parameterized query with full validation",
  "parameters": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "SQL query to execute"
      },
      "parameters": {
        "type": "array", 
        "description": "Query parameters for prepared statement",
        "items": {
          "type": "string"
        }
      },
      "target_schema": {
        "type": "string",
        "description": "Target schema for query execution",
        "enum": ["hr_admin", "financial_ops", "operations", "corporate", "creative_insights", "scout_dash", "public"]
      }
    },
    "required": ["query"]
  }
}
```

### 7. Get Enterprise KPIs

```json
{
  "name": "get_enterprise_kpis",
  "description": "Get key performance indicators across all enterprise domains",
  "parameters": {
    "type": "object",
    "properties": {},
    "required": []
  }
}
```

## Example ChatGPT Function Calls

### Python Implementation

```python
import requests
import json

class TBWADatabaseAccess:
    def __init__(self, base_url="http://localhost:3001/api", service_role_key=""):
        self.base_url = base_url
        self.headers = {
            "Authorization": f"Bearer {service_role_key}",
            "Content-Type": "application/json"
        }
    
    def get_enterprise_overview(self):
        """Get database overview with schema statistics"""
        response = requests.get(f"{self.base_url}/overview", headers=self.headers)
        return response.json()
    
    def list_enterprise_schemas(self):
        """List all available enterprise schemas"""
        response = requests.get(f"{self.base_url}/schemas", headers=self.headers)
        return response.json()
    
    def get_schema_tables(self, schema_name):
        """Get tables in specified schema"""
        response = requests.get(f"{self.base_url}/schema/{schema_name}/tables", headers=self.headers)
        return response.json()
    
    def get_table_details(self, schema_name, table_name):
        """Get detailed table information"""
        response = requests.get(f"{self.base_url}/schema/{schema_name}/table/{table_name}", headers=self.headers)
        return response.json()
    
    def execute_safe_query(self, query):
        """Execute SELECT-only query"""
        data = {"query": query}
        response = requests.post(f"{self.base_url}/query/safe", headers=self.headers, json=data)
        return response.json()
    
    def execute_enterprise_query(self, query, parameters=None, target_schema=None):
        """Execute parameterized query with validation"""
        data = {
            "query": query,
            "parameters": parameters or [],
            "target_schema": target_schema
        }
        response = requests.post(f"{self.base_url}/query", headers=self.headers, json=data)
        return response.json()
    
    def get_enterprise_kpis(self):
        """Get enterprise KPIs"""
        response = requests.get(f"{self.base_url}/kpis", headers=self.headers)
        return response.json()

# Usage example
db = TBWADatabaseAccess(service_role_key="your-service-role-key")

# Get overview
overview = db.get_enterprise_overview()
print(f"Total tables: {overview['data']['total_tables']}")

# List HR employees
employees = db.execute_safe_query(
    "SELECT employee_id, full_name, department FROM hr_admin.employees WHERE status = 'active' LIMIT 5"
)
print("Active employees:", employees['data'])

# Get financial KPIs  
kpis = db.get_enterprise_kpis()
print(f"Total budget: ${kpis['data']['total_budget']:,.2f}")
```

## Security Features

### Query Validation

The bridge implements multiple security layers:

1. **SQL Injection Protection**: Parameterized queries and input sanitization
2. **Operation Restrictions**: Blocks dangerous operations (DROP, DELETE, TRUNCATE, ALTER)
3. **Schema Validation**: Only allows access to approved enterprise schemas
4. **Rate Limiting**: Prevents DoS attacks with configurable limits
5. **Authentication**: Requires valid Supabase service role key

### Safe Mode vs Full Mode

#### Safe Mode (`/api/query/safe`)
- **Allows**: SELECT statements only
- **Blocks**: INSERT, UPDATE, DELETE, DROP, CREATE, ALTER, TRUNCATE
- **Use Case**: Read-only analytics and reporting

#### Full Mode (`/api/query`)
- **Allows**: All SQL operations (with validation)
- **Requires**: Parameterized queries for dynamic values
- **Security**: Advanced SQL injection detection
- **Use Case**: Administrative operations and data modifications

### Error Handling

```json
{
  "success": false,
  "error": "Invalid schema name: unauthorized_schema",
  "code": "INVALID_SCHEMA",
  "timestamp": "2025-01-28T10:30:00Z"
}
```

Common error codes:
- `INVALID_SCHEMA`: Schema not in approved list
- `DANGEROUS_SQL`: Blocked dangerous SQL operation
- `VALIDATION_FAILED`: Query validation failed
- `AUTHENTICATION_FAILED`: Invalid service role key
- `RATE_LIMITED`: Too many requests

## Advanced Usage Patterns

### 1. Cross-Schema Analytics

```python
# Get employee performance across departments
query = """
SELECT 
    d.department_name,
    COUNT(e.id) as employee_count,
    AVG(pr.performance_score) as avg_performance
FROM hr_admin.employees e
JOIN hr_admin.departments d ON e.department_id = d.id
LEFT JOIN hr_admin.performance_reviews pr ON e.id = pr.employee_id
WHERE e.status = 'active' 
    AND pr.review_period >= '2024-01-01'
GROUP BY d.department_name
ORDER BY avg_performance DESC
"""

result = db.execute_safe_query(query)
```

### 2. Financial Reporting

```python
# Budget variance analysis
query = """
SELECT 
    acc.account_name,
    b.budget_amount,
    b.actual_amount,
    b.variance_amount,
    ROUND((b.variance_amount / b.budget_amount * 100), 2) as variance_percentage
FROM financial_ops.budgets b
JOIN financial_ops.accounts acc ON b.account_id = acc.id
WHERE b.fiscal_year = 2024
    AND ABS(b.variance_amount) > 10000
ORDER BY ABS(variance_percentage) DESC
"""

result = db.execute_safe_query(query)
```

### 3. Project Operations Dashboard

```python
# Active project status with resource allocation
query = """
SELECT 
    p.project_name,
    p.status,
    e.full_name as project_manager,
    p.budget,
    COUNT(r.id) as allocated_resources,
    p.end_date
FROM operations.projects p
JOIN hr_admin.employees e ON p.project_manager_id = e.id
LEFT JOIN operations.resources r ON r.project_id = p.id
WHERE p.status IN ('active', 'in_progress')
GROUP BY p.id, p.project_name, p.status, e.full_name, p.budget, p.end_date
ORDER BY p.end_date ASC
"""

result = db.execute_safe_query(query)
```

### 4. Creative Campaign Performance

```python
# Campaign performance with asset metrics
query = """
SELECT 
    c.campaign_name,
    c.budget,
    COUNT(a.id) as total_assets,
    AVG(a.brand_compliance_score) as avg_compliance,
    AVG(a.sentiment_score) as avg_sentiment,
    c.campaign_status
FROM creative_insights.campaigns c
LEFT JOIN creative_insights.assets a ON c.id = a.campaign_id
WHERE c.start_date >= '2024-01-01'
GROUP BY c.id, c.campaign_name, c.budget, c.campaign_status
HAVING COUNT(a.id) > 0
ORDER BY avg_compliance DESC, avg_sentiment DESC
"""

result = db.execute_safe_query(query)
```

## Deployment

### Production Deployment

1. **Environment Setup**:
```bash
# Production environment variables
export NODE_ENV=production
export SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=your-production-key
export PORT=3001
export RATE_LIMIT_MAX=100
export RATE_LIMIT_WINDOW_MS=60000
```

2. **Process Management**:
```bash
# Using PM2 for process management
npm install -g pm2

# Start production server
pm2 start ecosystem.config.js

# Monitor
pm2 monit

# Logs
pm2 logs chatgpt-database-bridge
```

3. **PM2 Configuration** (`ecosystem.config.js`):
```javascript
module.exports = {
  apps: [{
    name: 'chatgpt-database-bridge',
    script: './dist/adapters/chatgpt-database-bridge.js',
    instances: 2,
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3001
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log'
  }]
};
```

### Docker Deployment

```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY dist/ ./dist/
COPY src/ ./src/

EXPOSE 3001

CMD ["node", "dist/adapters/chatgpt-database-bridge.js"]
```

```yaml
# docker-compose.yml
version: '3.8'
services:
  chatgpt-bridge:
    build: .
    ports:
      - "3001:3001"
    environment:
      - NODE_ENV=production
      - SUPABASE_URL=${SUPABASE_URL}
      - SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### Load Balancing

For high-availability deployment:

```nginx
# nginx.conf
upstream chatgpt_bridge {
    server localhost:3001;
    server localhost:3002;
    server localhost:3003;
}

server {
    listen 80;
    server_name chatgpt-bridge.tbwa.internal;
    
    location /api/ {
        proxy_pass http://chatgpt_bridge;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Security headers
        proxy_set_header Authorization $http_authorization;
        proxy_hide_header X-Powered-By;
    }
}
```

## Monitoring & Observability

### Health Check Endpoint

```http
GET /api/health
```

**Response**:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "uptime": 3600,
  "database_connection": "ok",
  "memory_usage": "45.2MB",
  "timestamp": "2025-01-28T10:30:00Z"
}
```

### Metrics Collection

The bridge automatically collects metrics:

- Request count by endpoint
- Query execution time
- Error rates by type
- Database connection health
- Memory and CPU usage

### Logging

```javascript
// Structured logging format
{
  "timestamp": "2025-01-28T10:30:00Z",
  "level": "info",
  "operation": "execute_safe_query",
  "query": "SELECT * FROM hr_admin.employees LIMIT 10",
  "execution_time_ms": 23,
  "row_count": 10,
  "user_id": "chatgpt-user",
  "success": true
}
```

## Troubleshooting

### Common Issues

#### 1. Connection Failed
```bash
# Check if bridge is running
curl http://localhost:3001/api/health

# Check Supabase connectivity
curl -H "Authorization: Bearer your-key" \
     https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/
```

#### 2. Query Validation Errors
- Ensure queries use approved schemas only
- Check for dangerous SQL operations (DROP, TRUNCATE)
- Verify parameterized queries are properly formatted

#### 3. Authentication Errors
- Verify Supabase service role key is valid
- Check Authorization header format
- Ensure key has necessary permissions

### Debug Mode

```bash
# Start bridge with debug logging
DEBUG=chatgpt-bridge:* node dist/adapters/chatgpt-database-bridge.js

# Or set environment variable
export DEBUG=chatgpt-bridge:*
```

### Performance Optimization

1. **Connection Pooling**: Configure Supabase client pool size
2. **Query Caching**: Implement Redis caching for frequent queries
3. **Request Batching**: Combine multiple queries when possible
4. **Index Optimization**: Ensure database indexes support common queries

## Limitations

### Current Limitations
- **Single Database**: Currently supports one Supabase project
- **No Real-time**: No WebSocket support for real-time updates
- **Query Size**: Limited to 1MB query size
- **Rate Limits**: 100 requests per minute per IP
- **No Transactions**: No multi-query transaction support

### Platform Constraints
- **Schema Restrictions**: Only approved TBWA enterprise schemas
- **Read Preference**: Optimized for read operations
- **Network Dependency**: Requires reliable network connection to Supabase
- **Memory Usage**: Query results cached temporarily in memory

## Roadmap

### Near Term (Q1 2025)
- [ ] **Query Caching**: Redis-based result caching
- [ ] **Batch Operations**: Multiple queries in single request
- [ ] **Real-time Subscriptions**: WebSocket support for live data
- [ ] **Query Builder**: Visual query construction API

### Medium Term (Q2 2025)
- [ ] **Multi-Database**: Support multiple Supabase projects
- [ ] **Advanced Analytics**: Built-in analytics functions
- [ ] **Export Capabilities**: CSV, Excel, JSON export
- [ ] **Scheduled Queries**: Cron-based query execution

### Long Term (Q3+ 2025)
- [ ] **AI Query Generation**: Natural language to SQL
- [ ] **Data Visualization**: Chart generation API
- [ ] **Audit Trail**: Complete query history and tracking
- [ ] **Enterprise SSO**: Integration with TBWA identity systems

---

**Last Updated**: 2025-01-28  
**Version**: 1.0.0  
**Maintainer**: TBWA Enterprise Data Platform Team