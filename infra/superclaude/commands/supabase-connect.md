# sc:supabase-connect

**Goal**: Connect to Supabase MCP server for database operations and real-time data.

**Steps**
1. Ensure Supabase MCP server is running on port 3846
2. Configure environment variables:
   - `SUPABASE_URL`: Your project URL (https://your-project-ref.supabase.co)
   - `SUPABASE_SERVICE_ROLE_KEY`: Your service role key
3. Add MCP server to your client:
   - Name: Supabase MCP
   - URL: http://127.0.0.1:3846/sse

**Tools Available**
- Database schema inspection
- Real-time subscriptions
- Row-level security management
- CRUD operations
- Storage management

**Security**: Use service role keys only in secure environments. Never commit keys to version control.
