# AI AAS Hardened Lakehouse - Complete Documentation

## 📋 Overview

This monorepo provides a fully integrated MCP (Model Context Protocol) suite with enterprise-grade security, designed for seamless development workflows across Figma, Supabase, Mapbox, and Vercel.

## 🎯 Core Objectives

1. **MCP Integration**: Unified interface for design, data, geospatial, and deployment services
2. **Security First**: Multi-layer protection against secret leakage and unauthorized access
3. **Operational Excellence**: Streamlined workflows with comprehensive health monitoring
4. **Quality Assurance**: Automated testing and validation at every stage
5. **Future-Proof**: Extensible architecture for additional MCP services

## 🏗️ Architecture

### Monorepo Structure
```
ai-aas-hardened-lakehouse/
├── apps/                          # Application layer
│   ├── scout-dashboard/           # Next.js production application
│   └── scout-ui/                  # Vite + Storybook for UI development
├── mcp/                           # MCP server configurations
│   ├── figma/                     # Design-to-code integration (port 3845)
│   ├── supabase/                  # Database operations (port 3846)
│   ├── mapbox/                    # Geospatial services (port 3847)
│   ├── vercel/                    # Deployment management (port 3848)
│   └── _meta/                     # Centralized MCP configuration
├── scripts/                       # Automation and validation
│   ├── mcp/                       # MCP health checks
│   ├── security/                  # Secret scanning and audits
│   └── qa/                        # Quality assurance tests
├── infra/                         # Infrastructure definitions
│   └── superclaude/               # SuperClaude command templates
├── docs/                          # Documentation
│   └── runbooks/                  # Operational procedures
└── .github/workflows/             # CI/CD pipelines
```

## 🔄 Workflow Integration

### Design → Code → Data → Deployment

1. **Figma MCP**: Extract design system, components, and variables
2. **Supabase MCP**: Connect to database schema and real-time data
3. **Mapbox MCP**: Add geospatial visualization and analysis
4. **Vercel MCP**: Configure deployment and infrastructure
5. **Generate**: Production-ready React + Tailwind components

### SuperClaude Commands
```bash
sc:figma-connect       # Connect to Figma design system
sc:supabase-connect    # Connect to Supabase database  
sc:mapbox-connect      # Connect to Mapbox geospatial services
sc:vercel-connect      # Connect to Vercel deployment
sc:mcp-full-stack      # Connect all MCP servers
```

## 🛡️ Security Implementation

### Multi-Layer Protection

1. **Prevention**: Git hooks and pre-commit checks
2. **Detection**: Gitleaks scanning with custom rules
3. **Enforcement**: CI/CD pipeline blocking
4. **Validation**: Pre-deploy security audits
5. **Monitoring**: Regular health checks

### Security Commands
```bash
make sec           # Secret scanning
make audit         # Pre-deploy security audit  
make rls           # Supabase RLS validation
make mcp-check     # MCP server health check
```

### Secret Management Rules
- GitHub PATs (`ghp_`)
- Supabase keys (`sbp_`, JWT tokens)
- Mapbox tokens (`pk.`, `sk.`)
- Vercel tokens (`vercel.`)
- Generic bearer tokens

## 🧪 Quality Assurance

### Automated Testing
- **RLS Validation**: Ensures proper data access controls
- **MCP Health**: Verifies all MCP servers are operational
- **Security Audits**: Pre-deploy secret scanning
- **Component Review**: Storybook integration for MCP-generated UI

### Testing Commands
```bash
# Run all validation tests
make sec && make audit && make rls && make mcp-check

# Individual test suites
node scripts/qa/supabase_rls_smoke.mjs
scripts/security/pre_deploy_audit.sh
scripts/mcp/full_stack_check.sh
```

## 🚀 Deployment

### Vercel Integration
- Automatic environment variable management
- Pre-deploy security validation
- Monorepo-aware build configuration
- Preview deployments for PRs

### Deployment Commands
```bash
make deploy-next    # Deploy Next.js application
```

### Build Process
1. **Prebuild**: Security audit and validation
2. **Build**: Application compilation
3. **Deploy**: Vercel deployment with proper environment

## 📚 Documentation Structure

### Key Documents
- `README.md` - Main project overview and quick start
- `DOCUMENTATION.md` - This comprehensive guide
- `mcp/README.md` - MCP server integration details
- `docs/runbooks/mcp-suite.md` - Operational procedures
- `mcp/_meta/clients.jsonc` - Canonical MCP configuration

### API References
- [Figma Dev Mode](https://help.figma.com/hc/en-us/articles/32132100833559)
- [Supabase API](https://supabase.com/docs)
- [Mapbox API](https://docs.mapbox.com/)
- [Vercel API](https://vercel.com/docs)
- [MCP Protocol](https://modelcontextprotocol.io/)

## 🔧 Operational Procedures

### Daily Operations
```bash
# Start development
make dev-next
make dev-vite
make story

# Run health checks
make mcp-check
make sec

# Deploy to production
make deploy-next
```

### Incident Response
1. **MCP Connection Issues**: Check ports 3845-3848, restart services
2. **Secret Detection**: Rotate compromised keys immediately
3. **RLS Violations**: Review and update database policies
4. **Build Failures**: Check pre-deploy audit results

### Maintenance
- Quarterly key rotation
- Regular dependency updates
- Security rule reviews
- Documentation updates

## 🤝 Development Guidelines

### Code Standards
- Follow existing patterns in generated components
- Maintain consistent security practices
- Document all MCP integrations
- Update runbooks for operational changes

### Contribution Workflow
1. Use MCP servers for code generation
2. Review components in Storybook (`make story`)
3. Run security audits before committing
4. Submit PR with passing CI checks
5. Update documentation for new features

## 📞 Support & Troubleshooting

### Common Issues
- **MCP Connection Refused**: Verify servers are running on correct ports
- **Secret Detection False Positives**: Review `.gitleaks.toml` allowlist
- **RLS Test Failures**: Check database permissions and test data
- **Build Failures**: Examine prebuild audit output

### Health Check Procedures
```bash
# Comprehensive system verification
scripts/mcp/full_stack_check.sh
scripts/security/scan_secrets.sh
scripts/security/pre_deploy_audit.sh
node scripts/qa/supabase_rls_smoke.mjs
```

### Support Resources
- MCP server documentation in `/mcp/` directories
- Operational runbooks in `/docs/runbooks/`
- Security configuration in `/scripts/security/`
- Makefile targets for common operations

## 🔮 Future Enhancements

### Planned Integrations
- Additional MCP servers (GitHub, Slack, etc.)
- Enhanced Storybook integration
- Advanced security scanning
- Performance monitoring
- Extended testing coverage

### Extension Points
- New MCP server configurations in `/mcp/`
- Additional SuperClaude commands in `/infra/superclaude/`
- Extended QA tests in `/scripts/qa/`
- Enhanced security rules in `.gitleaks.toml`

## 📋 License & Compliance

This project follows enterprise security standards and includes:
- Regular security audits
- Compliance documentation
- Access control policies
- Audit trail maintenance

For specific licensing details, refer to individual package licenses and organizational policies.
