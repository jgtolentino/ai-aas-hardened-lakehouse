# 🤝 Contributing to AI-AAS Hardened Lakehouse

Welcome! This guide helps you get started contributing to our enterprise data platform in **10 minutes**.

## 🚀 **Quick Onboarding (10 Minutes)**

### 1️⃣ **Environment Setup (2 min)**
```bash
# Clone and navigate
git clone https://github.com/jgtolentino/ai-aas-hardened-lakehouse.git
cd ai-aas-hardened-lakehouse

# Copy environment template
cp .env.example .env.local

# Install dependencies
npm install
```

### 2️⃣ **Database Connection (2 min)**
```bash
# Set your connection string in .env.local:
DATABASE_URL=postgresql://your_connection_string

# Test connection
psql "$DATABASE_URL" -c "SELECT 'Connected!' as status;"
```

### 3️⃣ **Repository Structure (2 min)**
📖 Read the **[Repository Map](docs/REPO_MAP.md)** - essential 2-minute overview

**Key locations:**
- `supabase/migrations/` - All database changes go here
- `supabase/functions/` - Edge functions (APIs)
- `platform/scout/` - Scout analytics platform
- `scripts/ci/` - Quality gates and testing

### 4️⃣ **Development Workflow (2 min)**
```bash
# Create feature branch
git checkout -b feat/your-feature-name

# Make your changes...

# Run quality gates (REQUIRED before merge)
./scripts/ci/accept_streaming_gate.sh
./scripts/validate_analytics_math.sh
```

### 5️⃣ **Testing & Verification (2 min)**
```bash
# Run all tests
./scripts/run-tests.sh

# Check for issues
npm run lint
npm run typecheck
```

---

## 📋 **Development Standards**

### 🗃️ **Database Changes**
- ✅ All SQL → `supabase/migrations/YYYYMMDDHHMMSS_description.sql`
- ✅ Use proper naming: `20250824120000_add_users_table.sql`
- ✅ Test migration both up and down
- ❌ Never edit existing migrations

### 🏗️ **Code Standards**
- ✅ TypeScript for new code
- ✅ Proper error handling
- ✅ Security-first mindset (no hardcoded secrets)
- ✅ Tests for new features

### 🔒 **Security Requirements**
- ✅ All secrets in environment variables
- ✅ RLS policies for database tables
- ✅ Input validation and sanitization
- ✅ Least-privilege access patterns

---

## 🧪 **Quality Gates (MANDATORY)**

Before any merge, these must pass:

```bash
# 1. Streaming pipeline health
./scripts/ci/accept_streaming_gate.sh

# 2. Math validation (zero tolerance)
./scripts/validate_analytics_math.sh

# 3. Database drift check
git ls-files '*.sql' | grep -v '^supabase/migrations/' && echo "❌ SQL outside migrations!" || echo "✅ OK"

# 4. Linting and type checking
npm run lint && npm run typecheck
```

---

## 🏆 **Pull Request Process**

### 1. **Before Creating PR**
- [ ] Quality gates pass locally
- [ ] Tests added for new features
- [ ] Documentation updated if needed
- [ ] No secrets or sensitive data committed

### 2. **PR Requirements**
- [ ] Descriptive title and description
- [ ] Links to related issues
- [ ] Screenshots for UI changes
- [ ] Migration notes if DB changes

### 3. **Review Process**
- [ ] Automated CI checks pass
- [ ] Code review from team member
- [ ] Quality gate approval
- [ ] Security review for sensitive changes

---

## 🛠️ **Common Development Tasks**

### Adding a Database Migration
```bash
# Generate timestamp
timestamp=$(date +%Y%m%d%H%M%S)

# Create migration file
touch supabase/migrations/${timestamp}_your_description.sql

# Write your SQL
echo "CREATE TABLE users (id UUID PRIMARY KEY DEFAULT gen_random_uuid());" > supabase/migrations/${timestamp}_add_users_table.sql

# Apply locally
psql "$DATABASE_URL" -f supabase/migrations/${timestamp}_add_users_table.sql
```

### Deploying an Edge Function
```bash
# Navigate to functions
cd supabase/functions

# Create new function
mkdir my-function && cd my-function
echo 'export default async (req) => new Response("Hello World")' > index.ts

# Deploy
npx supabase functions deploy my-function
```

### Testing Streaming Pipeline
```bash
# Full end-to-end test
./scripts/test_streaming_pipeline.sh

# Check pipeline health
psql "$DATABASE_URL" -c "SELECT * FROM scout.v_ingest_freshness;"
```

---

## 📚 **Architecture Deep Dive**

| Component | Documentation |
|-----------|---------------|
| **Overall Architecture** | [docs/architecture/overview.md](docs/architecture/overview.md) |
| **Scout Platform** | [docs/SCOUT_V5_2_PRD.md](docs/SCOUT_V5_2_PRD.md) |
| **Security Model** | [SECURITY.md](SECURITY.md) |
| **API Reference** | [docs/API_DOCUMENTATION_ENHANCED.md](docs/API_DOCUMENTATION_ENHANCED.md) |

---

## 🚨 **Emergency Procedures**

### Production Issues
1. Check [PRODUCTION_ROLLBACK_RUNBOOK.md](PRODUCTION_ROLLBACK_RUNBOOK.md)
2. Run health checks: `./scripts/ci/accept_streaming_gate.sh`
3. Contact on-call engineer if critical

### Database Issues
```sql
-- Emergency stop processing
SELECT scout.control_ingestion('pause');

-- Check for issues
SELECT * FROM scout.v_quality_alerts WHERE severity = 'critical';

-- Resume when fixed
SELECT scout.control_ingestion('resume');
```

---

## 💡 **Tips for Success**

### 🏃‍♀️ **For Speed**
- Use our [MCP setup](docs/MCP_DEVELOPER_SETUP.md) for Claude integration
- Bookmark the [Repository Map](docs/REPO_MAP.md)
- Run quality gates early and often

### 🎯 **For Quality**
- Test database changes on development data first
- Write tests for edge cases
- Consider security implications of every change

### 🤝 **For Collaboration**
- Ask questions in GitHub Discussions
- Share knowledge in team meetings
- Document your solutions for others

---

## ❓ **Getting Help**

| Need | Resource |
|------|----------|
| **Quick questions** | GitHub Discussions |
| **Bug reports** | GitHub Issues |
| **Architecture questions** | Team Slack or meetings |
| **Emergency issues** | On-call rotation |

---

## 🎉 **Recognition**

Contributors are recognized in our monthly team meeting and listed in our Hall of Fame. 
Significant contributions earn you a co-author credit in releases!

---

*Happy coding! 🚀*

---
**Last updated**: August 2024 | Version 5.2.0