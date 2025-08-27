# Supabase MCP Server — Integration

## Prereqs
1) Supabase project with API access
2) Service role key (for admin operations) or anon key (for client operations)
3) Project URL and API keys

## Configuration
- **Project URL**: https://your-project-ref.supabase.co
- **API Key**: Service role key (recommended for MCP) or anon key
- **Port**: Typically runs on localhost with SSE transport

## Tools Available
- Database schema inspection
- Real-time subscriptions
- Row-level security policy management
- Storage operations
- Authentication management

## Security Notes
- Use service role keys only in secure environments
- Never commit API keys to version control
- Rotate keys immediately if exposed
- Use environment variables for configuration

## Integration with Figma
- Map database schemas to UI components
- Generate CRUD interfaces from database tables
- Sync design system with database constraints
