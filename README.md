# AI AAS Hardened Lakehouse - MCP Integration Suite

A comprehensive monorepo for integrating Figma, Supabase, Mapbox, and Vercel MCP servers with enterprise-grade security and operational workflows.

## 🏗️ Architecture Overview

```
ai-aas-hardened-lakehouse/
├── apps/
│   ├── scout-dashboard/     # Next.js application
│   └── scout-ui/           # Vite/Storybook application
├── mcp/                    # MCP server configurations
│   ├── figma/              # Figma Dev Mode integration
│   ├── supabase/           # Supabase database operations
│   ├── mapbox/             # Mapbox geospatial services
│   ├── vercel/             # Vercel deployment management
│   └── _meta/              # Canonical MCP client configuration
├── scripts/
│   ├── mcp/                # MCP health checks
│   ├── security/           # Secret scanning & audits
│   └── qa/                 # Quality assurance tests
├── infra/
│   └── superclaude/        # SuperClaude command templates
├── docs/
│   └── runbooks/           # Operational procedures
└── .github/workflows/      # CI/CD pipelines
```

## CI/CD
[![CI](https://github.com/jgtolentino/ai-aas-hardened-lakehouse/actions/workflows/ci.yml/badge.svg)](https://github.com/jgtolentino/ai-aas-hardened-lakehouse/actions/workflows/ci.yml)
[![Security](https://github.com/jgtolentino/ai-aas-hardened-lakehouse/actions/workflows/security.yml/badge.svg)](https://github.com/jgtolentino/ai-aas-hardened-lakehouse/actions/workflows/security.yml)
<!-- If using YAML deploys, uncomment:
[![Deploy](https://github.com/jgtolentino/ai-aas-hardened-lakehouse/actions/workflows/deploy-vercel.yml/badge.svg)](https://github.com/jgtolentino/ai-aas-hardened-lakehouse/actions/workflows/deploy-vercel.yml)
-->

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ and pnpm
- Figma Desktop with Dev Mode enabled
- Supabase project with service role key
- Mapbox account with access token
- Vercel account with API access

### Installation & Setup

1. **Clone and install dependencies:**
```bash
git clone <repository>
cd ai-aas-hardened-lakehouse
pnpm install
```

2. **Configure environment variables:**
```bash
# Copy example files
cp apps/scout-dashboard/.env.example apps/scout-dashboard/.env.local
cp apps/scout-ui/.env.example apps/scout-ui/.env.local

# Add your actual credentials (never commit these!)
```

3. **Enable MCP servers:**
- Figma: Preferences → Enable Dev Mode MCP Server
- Start Supabase, Mapbox, and Vercel MCP servers on ports 3846-3848

### Development

**Start development servers:**
```bash
make dev-next      # Start Next.js app
make dev-vite      # Start Vite app
make story         # Start Storybook
```

**Run MCP health check:**
```bash
make mcp-check     # Verify all MCP servers
```

## 🔐 Security & Compliance

### Secret Management
- **Never commit secrets** - Use environment variables only
- **Pre-push hooks** - Automatic secret scanning before git push
- **CI/CD enforcement** - GitHub Actions blocks secrets in PRs
- **Quarterly rotation** - Regular key rotation policy

### Security Commands
```bash
make sec           # Run secret scan
make audit         # Pre-deploy security audit
make rls           # Supabase RLS validation
```

## 🛠️ MCP Integration

### Available MCP Servers
- **Figma (3845)**: Design-to-code generation, component inspection
- **Supabase (3846)**: Database operations, real-time subscriptions, RLS management
- **Mapbox (3847)**: Geospatial operations, map rendering, routing
- **Vercel (3848)**: Deployment management, environment configuration

### SuperClaude Commands
Use these commands in your MCP client (Claude Code, Cursor, etc.):

```bash
sc:figma-connect       # Connect to Figma MCP
sc:supabase-connect    # Connect to Supabase MCP  
sc:mapbox-connect      # Connect to Mapbox MCP
sc:vercel-connect      # Connect to Vercel MCP
sc:mcp-full-stack      # Connect all MCP servers
```

## 📊 Quality Assurance

### Testing
```bash
# Run RLS validation
make rls

# Test MCP connectivity
make mcp-check

# Full security audit
make audit
```

### Storybook Integration
MCP-generated components are automatically loaded into Storybook for review:
- Components from `apps/scout-dashboard/src/components/generated/`
- Access via `make story`
- Visual validation before deployment

## 🚀 Deployment

### Vercel Deployment
```bash
make deploy-next    # Deploy Next.js app to Vercel
```

### Pre-deploy Checks
The build process automatically runs:
1. Secret scanning (gitleaks)
2. Security audit
3. Environment validation
4. RLS policy verification

## 📚 Documentation

### 📖 Documentation Index

#### 🚀 Getting Started & Operations
- **[Team Onboarding Quick Start](docs/TEAM_ONBOARDING_QUICK_START.md)** - Complete team setup guide with MCP configuration
- **[CI/CD Secrets Playbook](docs/CICD_SECRETS_PLAYBOOK.md)** - Comprehensive security and deployment guide

#### 🎯 Product Requirements & Specifications  
- **[PRD: Scout UI v6.0](docs/prd/PRD-SCOUT-UI-v6.0.md)** - Complete product specification for Scout Analytics Dashboard

#### 🎨 Design Integration
- **[Finebank Integration Guide](apps/scout-dashboard/FINEBANK_INTEGRATION.md)** - Figma Code Connect setup with Finebank Financial UI Kit

#### 🛠️ Technical Documentation
- **[MCP Suite Runbook](docs/runbooks/mcp-suite.md)** - Operational procedures for MCP servers
- **[MCP Server Documentation](mcp/README.md)** - MCP server implementation details
- **[MCP Client Configuration](mcp/_meta/clients.jsonc)** - Canonical MCP configuration

### 🌐 API References
- [Figma Dev Mode](https://help.figma.com/hc/en-us/articles/32132100833559)
- [Supabase API](https://supabase.com/docs)
- [Mapbox API](https://docs.mapbox.com/)
- [Vercel API](https://vercel.com/docs)

## 🔧 Troubleshooting

### Common Issues
1. **MCP connection failures**: Run `make mcp-check` to verify ports
2. **Secret detection**: Use `make sec` to identify leaked credentials
3. **RLS violations**: Run `make rls` to validate database permissions
4. **Build failures**: Check prebuild audit results

### Health Checks
```bash
# Full system verification
make sec
make audit  
make rls
make mcp-check
```

## 🤝 Contributing

### Workflow
1. Use MCP servers for code generation
2. Review components in Storybook
3. Run security audits before committing
4. Submit PR with passing CI checks

### Code Standards
- Follow existing patterns in generated components
- Maintain security practices
- Document new MCP integrations
- Update runbooks for operational changes

## 📞 Support

For issues with:
- MCP server connectivity: Check `docs/runbooks/mcp-suite.md`
- Security configuration: Review `.gitleaks.toml` and audit scripts
- Deployment problems: Check Vercel project settings
- Database access: Validate RLS policies and service roles

## 📋 License

This project is part of the AI AAS Hardened Lakehouse platform. See individual package licenses for specific details.
