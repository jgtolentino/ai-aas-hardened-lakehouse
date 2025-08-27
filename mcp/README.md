# MCP Server Integrations

This directory contains configurations and documentation for integrating various MCP (Model Context Protocol) servers with your development workflow.

## Available Integrations

### 1. Figma Dev Mode MCP
- **Location**: `./figma/`
- **Purpose**: Connect Figma designs to code generation
- **Port**: 3845
- **Tools**: Design inspection, code generation, component mapping

### 2. Supabase MCP  
- **Location**: `./supabase/`
- **Purpose**: Database operations and real-time data
- **Port**: 3846
- **Tools**: Schema inspection, CRUD operations, RLS management

### 3. Mapbox MCP
- **Location**: `./mapbox/`
- **Purpose**: Geospatial operations and map rendering
- **Port**: 3847
- **Tools**: Map rendering, geocoding, spatial analysis

### 4. Vercel MCP
- **Location**: `./vercel/`
- **Purpose**: Deployment and infrastructure management
- **Port**: 3848
- **Tools**: Deployment management, environment variables, monitoring

## Quick Start

### 1. Enable Figma Integration
```bash
sc:figma-connect
```

### 2. Connect Supabase
```bash
sc:supabase-connect
```

### 3. Add Mapbox
```bash
sc:mapbox-connect
```

### 4. Connect Vercel
```bash
sc:vercel-connect
```

### 5. Full Stack Integration
```bash
sc:mcp-full-stack
```

## Security Best Practices

### 🔐 Key Rotation
**IMMEDIATE ACTION REQUIRED**: Rotate all exposed keys:
- Supabase service role keys
- Mapbox access tokens
- Any other credentials that were committed or exposed

### 🛡️ Environment Variables
Store all secrets in environment variables:
- Never commit secrets to version control
- Use Vercel environment variables for deployment
- Use `.env.local` for development (gitignored)

### 🔒 Port Security
- MCP servers run on localhost ports 3845-3848
- Ensure proper firewall configuration
- Use HTTPS for production deployments

## Integration Workflow

### Design → Code → Data → Deployment Flow
1. **Figma**: Extract design system and components
2. **Supabase**: Connect to database schema and real-time data
3. **Mapbox**: Add geospatial visualization capabilities
4. **Vercel**: Configure deployment and infrastructure
5. **Generate**: Production React + Tailwind components with deployment ready

### Example Use Case
```prompt
"Create a user dashboard from this Figma frame that:
- Connects to the `users` table in Supabase
- Includes a Mapbox visualization of user locations
- Implements real-time updates
- Configures Vercel deployment with proper environment variables
- Follows our 12-col grid and accessibility standards"
```

## Troubleshooting

### Common Issues
1. **Port conflicts**: Ensure ports 3845-3848 are available
2. **Connection refused**: Verify MCP servers are running
3. **Authentication errors**: Check environment variables
4. **Design sync issues**: Ensure Figma frame is selected

### Health Checks
Test connectivity with the provided healthcheck files:
```bash
# Test Figma
http :3845

# Test Supabase  
http :3846

# Test Mapbox
http :3847

# Test Vercel
http :3848
```

## Resources

- [Figma Dev Mode Documentation](https://help.figma.com/hc/en-us/articles/32132100833559)
- [Supabase API Documentation](https://supabase.com/docs)
- [Mapbox API Documentation](https://docs.mapbox.com/)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)

## Support

For issues with MCP server integration, check:
1. Server logs for connection errors
2. Environment variable configuration
3. Port availability and firewall settings
4. Client MCP configuration files
