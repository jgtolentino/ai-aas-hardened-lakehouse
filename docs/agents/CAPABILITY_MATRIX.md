# Capability Matrix

## Overview

This matrix maps specific tasks to agents, required MCP tools, affected file paths, and validation gates. Use this as a reference for understanding which agent handles what type of work and how to trigger the appropriate workflows.

## Task → Agent → Tools → Validation Matrix

| Task Category | Specific Task | Agent | MCP Tools | Paths | CI Gate | Success Criteria |
|---------------|---------------|-------|-----------|-------|---------|------------------|
| **Design Integration** | Create Code Connect mapping | Frontend Architect | `figma`, `filesystem`, `github` | `apps/scout-ui/.../*.figma.tsx` | `figma-code-connect` | Figma preview shows React props |
| | Update component props from design | Frontend Architect | `figma`, `filesystem` | `apps/scout-ui/src/components/**/*.tsx` | `type-check`, `lint` | TypeScript compilation succeeds |
| | Generate Storybook stories | Frontend Architect | `filesystem`, `github` | `apps/scout-ui/src/components/**/*.stories.tsx` | `storybook-build` | Stories render without errors |
| | Create responsive variants | Frontend Architect | `figma`, `filesystem` | `apps/scout-ui/src/components/**/` | `visual-regression` | Breakpoints work correctly |
| **Database Operations** | Generate migration from schema diff | Data Engineer | `supabase` | `supabase/migrations/**/*.sql` | `supabase-diff` | Migration applies cleanly |
| | Create RLS policies | Data Engineer | `supabase`, `filesystem` | `supabase/migrations/**/*.sql` | `security-scan` | Policies enforce access rules |
| | Update TypeScript types | Data Engineer | `supabase`, `filesystem` | `types/**/*.ts`, `apps/**/src/types/` | `type-check` | No type errors in codebase |
| | Seed test data | Data Engineer | `supabase`, `filesystem` | `supabase/seed.sql` | `data-validation` | Seed data matches schema |
| | Create database views | Data Engineer | `supabase` | `supabase/migrations/**/*.sql` | `performance-check` | Views execute under 100ms |
| **CI/CD Operations** | Fix failing workflows | CI Guardian | `github`, `filesystem` | `.github/workflows/**/*.yml` | `ci` | All checks pass |
| | Update dependency lockfiles | CI Guardian | `filesystem`, `github` | `package-lock.json`, `pnpm-lock.yaml` | `dependency-audit` | No security vulnerabilities |
| | Deploy to staging/production | CI Guardian | `github`, `vercel` | deployment configs | `deploy-check` | Application starts successfully |
| | Fix build caching issues | CI Guardian | `github`, `filesystem` | `.github/workflows/`, `package.json` | `build-speed` | Build time under 5 minutes |
| | Handle merge conflicts | CI Guardian | `github`, `filesystem` | conflict files | `merge-validation` | All conflicts resolved |
| **Security Operations** | Scan for leaked secrets | SecOps | `git-history`, `filesystem` | repo-wide | `security-scan` | No secrets in git history |
| | Generate compliance report | SecOps | `filesystem`, `github` | `docs/compliance/` | `audit-check` | Report covers all requirements |
| | Clean sensitive git history | SecOps | `git-history` | `.git/` directory | `history-validation` | Sensitive data removed |
| | Rotate API keys | SecOps | `github-secrets`, `filesystem` | config files | `key-validation` | New keys work, old ones revoked |
| | Set up RLS policies audit | SecOps | `supabase`, `filesystem` | `supabase/migrations/` | `rls-audit` | All tables have proper RLS |
| **Full-Stack Workflows** | Figma → Code → Deploy | Multiple | All tools | Multiple paths | All gates | End-to-end functionality |
| | Schema change → Type gen → UI update | Multiple | `supabase`, `filesystem`, `figma` | Database + Frontend | `integration-test` | UI reflects schema changes |
| | Design system update | Multiple | `figma`, `filesystem`, `github` | `apps/scout-ui/`, `docs/` | `design-system-check` | All components use new system |

## Agent Capability Breakdown

### 🎨 Frontend Architect

#### **Core Capabilities**
- **Component Generation**: React/TypeScript components with proper props
- **Code Connect Integration**: Bi-directional Figma ↔ React mapping  
- **Storybook Authoring**: Interactive documentation and testing
- **Responsive Design**: Multi-device and breakpoint handling
- **Accessibility**: ARIA labels, keyboard navigation, screen reader support

#### **MCP Tool Usage**
```yaml
figma:
  - component.inspect: "Extract component properties and states"
  - file.export: "Generate assets from Figma designs"
  - selection.read: "Get currently selected design elements"

filesystem:
  - file.write: "Generate React components and Code Connect mappings"
  - directory.create: "Set up component folder structure"
  - file.search: "Find existing components for updates"

github:
  - pr.create: "Submit component changes for review"
  - file.commit: "Save component and documentation changes"
```

#### **Quality Gates**
- `figma-code-connect`: Code Connect mapping parses successfully
- `type-check`: TypeScript compilation without errors
- `lint`: ESLint and Prettier formatting passes
- `storybook-build`: Stories render and interact correctly
- `visual-regression`: Screenshots match expected design
- `accessibility`: WCAG 2.1 compliance checks pass

---

### 🗄️ Data Engineer

#### **Core Capabilities**
- **Schema Management**: Database migrations and rollback strategies
- **Type Generation**: TypeScript definitions from database schema
- **RLS Policy Creation**: Row-level security for multi-tenant data
- **ETL Pipeline Setup**: Data ingestion and transformation workflows
- **Performance Optimization**: Query analysis and index management

#### **MCP Tool Usage**
```yaml
supabase:
  - sql.exec: "Run database queries and migrations"
  - schema.diff: "Compare database schema changes"
  - migration.generate: "Create migration files from schema diffs"  
  - functions.deploy: "Deploy database functions and triggers"
  - types.generate: "Generate TypeScript types from schema"

filesystem:
  - file.write: "Create migration files and seed data"
  - file.read: "Read existing schema and migration files"

postgres:
  - query.exec: "Test queries on local development database"
  - schema.inspect: "Analyze database structure and relationships"
```

#### **Quality Gates**
- `supabase-diff`: Migration applies without conflicts
- `security-scan`: No sensitive data exposed in migrations
- `type-check`: Generated types compile correctly
- `performance-check`: Queries execute within performance budgets
- `data-validation`: Seed data passes integrity constraints
- `rls-audit`: All tables have appropriate row-level security

---

### ⚙️ CI Guardian

#### **Core Capabilities**
- **Pipeline Maintenance**: GitHub Actions workflow optimization
- **Dependency Management**: Package updates and security patches
- **Build Optimization**: Caching, parallelization, and speed improvements
- **Deployment Automation**: Staging and production deployment processes
- **Environment Management**: Configuration and secret handling

#### **MCP Tool Usage**
```yaml
github:
  - workflow.read: "Analyze GitHub Actions workflow files"
  - pr.merge: "Merge approved changes"
  - checks.rerun: "Retry failed CI checks"
  - secrets.update: "Manage GitHub repository secrets"

filesystem:
  - file.write: "Update workflow files and configurations"
  - file.search: "Find configuration files across repository"

vercel:
  - deploy.create: "Deploy applications to staging and production"
  - env.set: "Configure environment variables"
```

#### **Quality Gates**
- `ci`: All GitHub Actions workflows pass
- `dependency-audit`: No known security vulnerabilities
- `build-speed`: Build completes within time budget
- `deploy-check`: Application starts and responds to health checks
- `merge-validation`: No conflicts when merging branches

---

### 🔒 SecOps

#### **Core Capabilities**
- **Secret Detection**: Scanning for leaked credentials and keys
- **Compliance Auditing**: Security policy validation and reporting
- **Access Control**: RLS policies and permission management
- **Incident Response**: Security breach detection and remediation
- **History Cleaning**: Removing sensitive data from git history

#### **MCP Tool Usage**
```yaml
git-history:
  - scan.secrets: "Detect leaked credentials in git history"
  - clean.history: "Remove sensitive data from git history"
  - analyze.commits: "Review commit history for security issues"

filesystem:
  - file.scan: "Search files for potential secrets"
  - report.generate: "Create security compliance reports"

github:
  - secrets.rotate: "Update repository and organization secrets"
  - audit.log: "Review access logs and security events"
```

#### **Quality Gates**
- `security-scan`: No secrets or vulnerabilities detected
- `audit-check`: Compliance requirements satisfied
- `history-validation`: No sensitive data in accessible git history
- `key-validation`: API keys and secrets properly rotated
- `rls-audit`: Database access controls properly configured

## Cross-Agent Workflows

### **Figma → Production Pipeline**

| Step | Agent | Tools | Output | Gate |
|------|-------|-------|--------|------|
| 1. Extract design | Frontend Architect | `figma` | Component spec | Manual review |
| 2. Generate component | Frontend Architect | `figma`, `filesystem` | React component | `type-check` |
| 3. Create Code Connect | Frontend Architect | `filesystem` | `.figma.tsx` mapping | `figma-code-connect` |
| 4. Validate CI | CI Guardian | `github` | Fixed workflows | `ci` |
| 5. Security scan | SecOps | `git-history` | Security report | `security-scan` |
| 6. Deploy | CI Guardian | `vercel`, `github` | Live application | `deploy-check` |

### **Schema Evolution Pipeline**

| Step | Agent | Tools | Output | Gate |
|------|-------|-------|--------|------|
| 1. Detect schema drift | Data Engineer | `supabase` | Schema diff | Automated |
| 2. Generate migration | Data Engineer | `supabase`, `filesystem` | Migration files | `supabase-diff` |
| 3. Update types | Data Engineer | `supabase`, `filesystem` | TypeScript types | `type-check` |
| 4. Update components | Frontend Architect | `filesystem` | Updated props | `type-check` |
| 5. Security review | SecOps | `supabase` | RLS validation | `rls-audit` |
| 6. Deploy schema | CI Guardian | `github`, `supabase` | Applied migration | `deploy-check` |

## Task Routing Guide

### **How to Trigger Agents**

#### **Via Claude Desktop**
```
"Use SuperClaude Frontend Architect to create a Code Connect mapping for the KpiTile component"

"Ask SuperClaude Data Engineer to generate a migration for the new user_profiles table"

"Have SuperClaude CI Guardian fix the failing build in the main branch"

"Get SuperClaude SecOps to scan for any leaked API keys in the repository"
```

#### **Via Command Scripts**
```bash
# Generate component stub
./scripts/agents/superclaude.sh figma:stub ComponentName

# Fix CI pipeline
./scripts/agents/superclaude.sh ci:fix-workflows

# Generate migration
./scripts/agents/superclaude.sh data:migrate-schema

# Security scan
./scripts/agents/superclaude.sh security:scan-secrets
```

#### **Via GitHub Issues/PRs**
```yaml
# Add agent labels to trigger workflows
labels: ["agent:frontend", "figma-connect", "priority:high"]
labels: ["agent:data", "schema-change", "migration-needed"]  
labels: ["agent:ci", "build-failure", "urgent"]
labels: ["agent:security", "compliance", "audit-required"]
```

## Success Metrics

### **Agent Performance KPIs**

| Agent | Success Rate Target | Avg Response Time | Error Recovery |
|-------|-------------------|------------------|----------------|
| Frontend Architect | >95% | <15 minutes | Auto-retry with fallback |
| Data Engineer | >98% | <10 minutes | Manual review required |
| CI Guardian | >99% | <5 minutes | Immediate escalation |
| SecOps | >90% | <30 minutes | Manual intervention |

### **Cross-Agent Workflow KPIs**

| Workflow | End-to-End Time Target | Success Rate Target | Failure Recovery |
|----------|----------------------|-------------------|------------------|
| Figma → Production | <2 hours | >90% | Rollback + manual fix |
| Schema Evolution | <1 hour | >95% | Automated rollback |
| Security Incident | <15 minutes | >99% | Immediate team alert |

---

**Last Updated**: August 28, 2025  
**Matrix Version**: 1.0.0  
**Contact**: TBWA Platform Team