# sc:vercel-connect

**Goal**: Connect to Vercel MCP server for deployment and infrastructure management.

**Steps**
1. Ensure Vercel MCP server is running on port 3848
2. Configure environment variables:
   - `VERCEL_ACCESS_TOKEN`: Your Vercel API access token
   - `VERCEL_TEAM_ID`: Your team/organization ID
   - `VERCEL_PROJECT_ID`: Target project ID
3. Add MCP server to your client:
   - Name: Vercel MCP
   - URL: http://127.0.0.1:3848/sse

**Tools Available**
- Project deployment management
- Environment variable configuration
- Domain and routing management
- Build and deployment status monitoring
- Log access and analytics

**Integration with Development Workflow**
- Automate deployment processes from code generation
- Manage environment configurations
- Monitor deployment health
- Sync with CI/CD pipelines

**Security**: Use Vercel tokens with minimal required permissions. Never commit tokens to version control.
