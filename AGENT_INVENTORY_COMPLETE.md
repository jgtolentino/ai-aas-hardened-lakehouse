# 📋 Complete Agent Inventory - 17 Agents Total

## Summary
Successfully discovered and restored **17 agents** across the repository:
- **11 Pulser Agents** (including 6 restored)
- **2 MCP Agents** 
- **1 Config Agent** (suqi-agentic-intel)
- **1 QA Agent**
- **1 Task Definition**
- **1 duplicate** (agents-list in worktrees)

## Pulser Agents (11)

### Architecture & Design (4)
| Name | Codename | Version | Description |
|------|----------|---------|-------------|
| **backend-architect** | backend-architect-v1 | 1.0.0 | Backend architecture design, API development, and database optimization expert |
| **frontend-architect** | frontend-architect-v1 | 1.0.0 | Frontend architecture expert specializing in React, Vue, Angular, and modern UI frameworks |
| **devops-architect** | devops-architect | 1.0.0 | Automate infrastructure and deployment processes with focus on reliability and observability |
| **Devstral** | devstral-v1 | 1.0.0 | System architecture and PRD generation agent |

### Development & UI (2)
| Name | Codename | Version | Description |
|------|----------|---------|-------------|
| **Dash** | dash-v1 | 1.0.0 | TypeScript/React UI component generation agent |
| **quality-engineer** | quality-engineer | **2.0.0** | Expert CI/QA + Visualization engineer with React dashboard and Superset parity |

### Documentation (2)
| Name | Codename | Version | Description |
|------|----------|---------|-------------|
| **Maya** | maya-v1 | 1.0.0 | Documentation generation and maintenance agent |
| **technical-writer** | technical-writer | 1.0.0 | Create clear, comprehensive technical documentation tailored to specific audiences |

### Operations & Security (3)
| Name | Codename | Version | Description |
|------|----------|---------|-------------|
| **security-engineer** | security-engineer | 1.0.0 | Dependency scanning, vulnerability assessment, security compliance |
| **performance-engineer** | performance-engineer-v1 | 1.0.0 | Performance optimization expert for backend, frontend, and infrastructure |
| **superclaude-cicd-orchestrator** | superclaude-cicd-orchestrator | 1.0.0 | SuperClaude-powered CI/CD troubleshooting and PR cleanup |

## MCP Agents (2)
| Name | Codename | Version | Description |
|------|----------|---------|-------------|
| **DocsWriter** | DocsWriter | 1.0.0 | AI docs generator for Docusaurus + GitHub Wiki mirror |
| **scout-docs-writer** | scout-docs-writer | 1.0.0 | Scout-specific documentation generator with analytics focus |

## Config Agents (1)
| Name | Codename | Version | Description |
|------|----------|---------|-------------|
| **suqi-agentic-intel** | suqi-agentic-intel-v1 | 1.0.0 | Suqi Agentic Intelligence configuration for Scout analytics platform |

## QA Agents (1)
| Name | Codename | Version | Description |
|------|----------|---------|-------------|
| **QA-BrowserUse** | QA-BrowserUse | 1.0.0 | Browser automation for QA testing |

## Task Definitions (1)
| Name | Codename | Version | Description |
|------|----------|---------|-------------|
| **agents-list** | agents-list | 1.0.0 | List all registered agents in the repository |

## Usage

```bash
# List all agents
./scripts/list_agents.sh .

# Export formats
FORMAT=csv ./scripts/list_agents.sh . > agents.csv
FORMAT=json ./scripts/list_agents.sh . > agents.json

# Via Pulser
/pulser run agents-list
```

## Key Features

### Quality Engineer v2.0.0
The upgraded Quality Engineer is now a full-stack quality and visualization expert:
- **Testing**: CI/CD, unit, integration, e2e testing
- **Visualization**: React dashboards with pixel-perfect Superset parity
- **Design Systems**: Token synchronization, component libraries
- **Performance**: Visual regression testing, accessibility compliance

### SuperClaude Integration
Multiple agents are SuperClaude-powered:
- backend-architect
- frontend-architect  
- devops-architect
- performance-engineer
- security-engineer
- superclaude-cicd-orchestrator

### Specialized Agents
- **Dash**: UI component generation with chart creation
- **Maya**: Documentation with ADR support
- **Devstral**: PRD and architecture documents
- **suqi-agentic-intel**: Scout analytics intelligence