# 🛠️ MCP Developer Setup - AI-as-a-Service Hardened Lakehouse

## Why Full Developer Access?

MCP is configured for **full developer capabilities** because it's a **development tool** that needs to:

- 🗃️ **Create and modify database schemas** for development
- ⚡ **Deploy and test edge functions** 
- 📊 **Run data transformations and ETL processes**
- 🧪 **Execute migrations and seed data**
- 🔧 **Generate TypeScript types and test configurations**

## 🚀 Quick Setup

### 1. Environment Configuration
```bash
# Copy the example file
cp .env.mcp.example .env.mcp

# Edit with your actual credentials
nano .env.mcp
```

### 2. Set Environment Variables
```bash
export SUPABASE_PROJECT_REF="cxzllzyxwpyptfretryc"  
export SUPABASE_ACCESS_TOKEN="your_pat_token"
export MCP_DB_PASSWORD="Dbpassword_26"
```

### 3. Verify MCP Setup
```bash
# The .mcp.json will automatically use these environment variables
claude mcp list
```

## 🎯 MCP Capabilities Enabled

### Supabase MCP Server
- **Database Operations**: Full CRUD access for development
- **Schema Management**: Create tables, views, functions
- **Migration Deployment**: Apply and test migrations
- **Edge Functions**: Deploy and test serverless functions
- **Storage Management**: Manage buckets and file operations
- **Secrets Management**: Environment variable operations

### PostgreSQL Direct Access  
- **Raw SQL Execution**: Run complex queries and procedures
- **Performance Analysis**: EXPLAIN plans and optimization
- **Data Pipeline Testing**: ETL and transformation workflows
- **Backup/Restore Operations**: Data management tasks

### Filesystem Operations
- **Code Generation**: Create migrations, types, configurations
- **File Management**: Read/write project files
- **Documentation Updates**: Auto-update docs and schemas

## 🛡️ Security Best Practices

### Environment-Based Security
```bash
# Development (full access)
LAKEHOUSE_ENV=development
MCP_ROLE=developer

# Staging (limited write)  
LAKEHOUSE_ENV=staging
MCP_ROLE=tester

# Production (read-only for analysis)
LAKEHOUSE_ENV=production  
MCP_ROLE=analyst
```

### Access Patterns
- **Development**: Full database access for schema changes
- **CI/CD**: Automated migrations and deployments
- **Analytics**: Read access with write permissions for temp tables
- **Emergency**: Full access with audit logging

## 🔧 Developer Workflows

### Schema Development
```bash
# Ask Claude to create new tables
"Create a new customer_personas table with AI reasoning fields"

# Deploy migrations
"Apply the latest Supabase migrations to development"

# Generate types
"Update TypeScript types after schema changes"
```

### Data Pipeline Development  
```bash
# ETL operations
"Process the latest Scout data and update gold layer tables"

# Performance optimization
"Analyze query performance for the choropleth dashboard"

# Data quality checks
"Run DQ validation on the latest ingested data"
```

### Edge Function Development
```bash
# Function development
"Create an edge function for real-time brand detection"

# Testing and deployment  
"Deploy and test the AI reasoning tracker function"

# Monitoring setup
"Set up logging and alerts for the new edge functions"
```

## 📊 Environment-Specific Configurations

### Development Environment
```json
{
  "mcpServers": {
    "supabase_dev": {
      "env": {
        "SUPABASE_ROLE": "service_role",
        "MCP_MODE": "development"
      }
    }
  }
}
```

### Production Environment  
```json
{
  "mcpServers": {
    "supabase_prod": {
      "env": {
        "SUPABASE_ROLE": "authenticated", 
        "MCP_MODE": "analytics_only"
      }
    }
  }
}
```

## 🚨 Emergency Procedures

### Rollback Capabilities
```bash
# Schema rollback
"Revert the last migration if there are issues"

# Function rollback  
"Rollback the edge function to the previous version"

# Data rollback
"Restore data from the pre-deployment backup"
```

### Access Control Override
```bash
# Temporary read-only mode
export MCP_EMERGENCY_READONLY=true

# Re-enable full access
unset MCP_EMERGENCY_READONLY
```

## 🎯 Why This Approach?

### Developer Productivity
- **No friction**: Full access for rapid development
- **Real environment**: Work with actual data and schemas  
- **Complete tooling**: All Supabase features available

### Controlled Risk
- **Environment variables**: Secrets not hardcoded in repo
- **Audit logging**: All operations tracked
- **Backup procedures**: Easy rollback capabilities
- **Branch-based access**: Production requires approval

### Enterprise Ready
- **Role-based permissions**: Different access per environment
- **Compliance tracking**: Full audit trail of changes
- **Change management**: PR-based deployment workflow
- **Monitoring integration**: Real-time alerting and logging

---

**MCP is configured as a powerful development tool while maintaining enterprise security standards.**

The AI-as-a-Service Hardened Lakehouse needs full developer access to MCP for effective data platform development and operations.