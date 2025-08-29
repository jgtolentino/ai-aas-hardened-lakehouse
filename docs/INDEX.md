# TBWA Enterprise Data Platform - Documentation Hub

## 🚀 Quick Start

### For Developers
- **[Design → Code → PR](./runbooks/DESIGN_TO_CODE.md)** - Complete Figma to React workflow
- **[MCP Integration Guide](./claude/mcp-integration.md)** - Token-free Claude Desktop setup
- **[SuperClaude Overview](./superclaude/OVERVIEW.md)** - AI agent orchestration framework

### For Platform Teams
- **[Agent Orchestration](./agents/ORCHESTRATION.md)** - Multi-agent workflow patterns
- **[Capability Matrix](./agents/CAPABILITY_MATRIX.md)** - Task routing and validation
- **[MCP Server Registry](./mcp/REGISTRY.md)** - All configured MCP servers

## 📖 Documentation Categories

### 🎨 **Frontend & Design**
| Document | Description | Updated |
|----------|-------------|---------|
| [Design → Code → PR Runbook](./runbooks/DESIGN_TO_CODE.md) | Step-by-step Figma to React component process | Aug 28, 2025 |
| [MCP Integration Guide](./claude/mcp-integration.md) | Token-free Claude Desktop + Figma Dev Mode setup | - |

### 🤖 **AI Agent Framework (SuperClaude)**
| Document | Description | Updated |
|----------|-------------|---------|
| [Framework Overview](./superclaude/OVERVIEW.md) | Agent personas, command grammar, task cards | Aug 28, 2025 |
| [Agent Orchestration](./agents/ORCHESTRATION.md) | Contracts, handoffs, quality gates | Aug 28, 2025 |
| [Capability Matrix](./agents/CAPABILITY_MATRIX.md) | Task → Agent → Tools → Validation mapping | Aug 28, 2025 |

### ⚙️ **Model Context Protocol (MCP)**
| Document | Description | Updated |
|----------|-------------|---------|
| [MCP Server Registry](./mcp/REGISTRY.md) | All MCP servers, tools, authentication modes | Aug 28, 2025 |
| [MCP Quick Reference](./claude/mcp-quick-reference.md) | Common commands and troubleshooting | - |

### 📋 **Runbooks & Workflows**
| Document | Description | Updated |
|----------|-------------|---------|  
| [Design → Code → PR](./runbooks/DESIGN_TO_CODE.md) | Figma integration workflow | Aug 28, 2025 |
| [Financial Dashboard PRD](./PRD/FINANCIAL_DASHBOARD_PRD.md) | Complete product requirements for Scout dashboard | Aug 28, 2025 |
| Additional runbooks coming soon... | | |

## 🏗️ **Architecture Overview**

### SuperClaude Agent System
```
Claude Desktop → SuperClaude Hub → Agent Registry
     ↓               ↓                    ↓
MCP Protocol    Route Commands      Specialized Agents
     ↓               ↓                    ↓
Tool Access     Task Cards         Artifacts + PRs
```

### Agent Personas
- **🎨 Frontend Architect** - Design-to-code, UI components, Code Connect
- **🗄️ Data Engineer** - Database schemas, ETL pipelines, migrations  
- **⚙️ CI Guardian** - Build systems, deployment, workflow fixes
- **🔒 SecOps** - Security scanning, secret management, compliance

### MCP Server Stack
- **Figma Dev Mode** - Token-free design integration
- **Supabase Primary** - Main database operations  
- **Supabase Alternate** - Agent registry and experiments
- **GitHub** - Repository operations and CI/CD
- **Filesystem** - Local file operations
- **Postgres Local** - Development database access

## 🛠️ **Common Workflows**

### Design → Production Pipeline
1. **Designer**: Creates component in Figma
2. **Frontend Architect**: Generates Code Connect mapping
3. **CI Guardian**: Validates and deploys
4. **Result**: Live component with Figma preview

### Schema Change Pipeline  
1. **Data Engineer**: Detects schema drift
2. **Agent**: Generates migration and RLS policies
3. **CI Guardian**: Validates safety and deploys
4. **Frontend Architect**: Updates component types
5. **Result**: End-to-end schema synchronization

### CI Failure Recovery
1. **CI Guardian**: Detects workflow failures
2. **Agent**: Fixes dependencies and configurations
3. **Agent**: Re-runs validation checks
4. **Result**: Working CI pipeline

## 🔧 **Getting Started**

### 1. Verify MCP Setup
```bash
# Check Claude Desktop MCP configuration
curl http://127.0.0.1:3845/health

# Validate Code Connect setup  
pnpm run figma:connect:validate
```

### 2. Run First Agent Command
```bash
# Generate component stub via script
./scripts/agents/superclaude.sh figma:stub MyComponent

# Or via Claude Desktop natural language:
"Use SuperClaude Frontend Architect to create a Code Connect mapping for MyComponent"
```

### 3. Verify Integration
- Generated files in correct locations
- Valid Code Connect parsing
- CI checks passing
- Documentation updates

## 🎯 **Agent Task Examples**

### Frontend Architect
```
"Create a responsive KPI tile component with loading states and Code Connect mapping"
"Generate Storybook stories for all component variants"  
"Wire Figma selection to React props with TypeScript types"
```

### Data Engineer
```
"Generate Supabase migration from detected schema drift"
"Create RLS policies for multi-tenant data access"
"Set up ETL pipeline with data validation and monitoring"
```

### CI Guardian
```
"Fix failing GitHub Actions workflow with dependency conflicts"
"Optimize build caching to reduce CI time under 5 minutes"
"Deploy to staging with environment configuration"
```

### SecOps
```
"Scan repository for leaked credentials and clean git history"
"Generate compliance audit report for Q4 review"
"Rotate API keys and update GitHub secrets"
```

## 📊 **Success Metrics**

### Agent Performance KPIs
| Agent | Success Rate Target | Avg Response Time | Error Recovery |
|-------|-------------------|------------------|----------------|
| Frontend Architect | >95% | <15 minutes | Auto-retry with fallback |
| Data Engineer | >98% | <10 minutes | Manual review required |
| CI Guardian | >99% | <5 minutes | Immediate escalation |
| SecOps | >90% | <30 minutes | Manual intervention |

### Workflow KPIs
| Workflow | End-to-End Time Target | Success Rate Target |
|----------|----------------------|-------------------|
| Figma → Production | <2 hours | >90% |
| Schema Evolution | <1 hour | >95% |
| Security Incident Response | <15 minutes | >99% |

## 🔍 **Troubleshooting**

### Common Issues
- **MCP Server Not Responding**: Check Claude Desktop configuration and server health
- **Code Connect Validation Fails**: Verify Figma file keys and node IDs
- **Agent Task Failures**: Review task cards and dependency requirements
- **CI Pipeline Issues**: Check workflow files and environment variables

### Debug Commands
```bash
# MCP health check
./scripts/check-mcp-health.sh

# Validate specific configurations
pnpm run figma:connect:validate
pnpm run type-check
pnpm run lint

# Agent-specific debugging
./scripts/agents/superclaude.sh debug
```

## 📞 **Support & Contact**

- **Platform Team**: TBWA Data Platform Team
- **Framework Version**: SuperClaude 1.0.0
- **Last Updated**: August 28, 2025
- **Repository**: `/Users/tbwa/ai-aas-hardened-lakehouse`

---

**🎯 Key Principle**: Token-free where possible, secure by default, traceable operations, standardized interfaces.