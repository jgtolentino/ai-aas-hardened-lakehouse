# 🗺️ Repository Map - AI-AAS Hardened Lakehouse

## 📍 **Quick Navigation for Newcomers**

Welcome to the **AI-AAS Hardened Lakehouse** - an enterprise-grade monorepo supporting multiple data platforms and applications.

### 🏛️ **Core Database & Infrastructure**

| Path | Purpose | Key Files |
|------|---------|-----------|
| `supabase/migrations/` | **Canonical DB migrations** | All schema changes, 30+ production migrations |
| `supabase/functions/` | **Edge functions** (ingest, exports, embeddings) | `ingest-transaction/`, `export-platinum/` |
| `supabase/seed.sql` | **Seed data** for development | Test data, lookup tables |
| `.github/workflows/` | **CI/CD pipelines** | `ci.yml`, `deploy-prod.yml`, `auto-migration.yml` |

### 🎯 **Domain-Specific Platforms**

| Platform | Path | Description |
|----------|------|-------------|
| **Scout Analytics** | `platform/scout/` | Retail intelligence platform with Bronze→Silver→Gold ETL |
| **Data Lakehouse** | `platform/lakehouse/` | Trino, MinIO, Nessie for data lake operations |
| **Superset BI** | `platform/superset/` | Business intelligence dashboards and visualizations |
| **Security** | `platform/security/` | Network policies, secret rotation, Gatekeeper |

### 🚀 **Applications & Services**

| App | Path | Technology | Purpose |
|-----|------|------------|---------|
| **Scout Dashboard** | `apps/scout-dashboard/` | React/Vite | Real-time retail analytics UI |
| **Brand Dashboard** | `apps/brand-dashboard/` | Next.js | Brand intelligence dashboard |
| **Edge Pi Device** | `apps/pi-edge/` | Node.js/Python | Edge data collection |
| **API Gateway** | `services/api/` | Node.js/Express | RESTful API layer |

### ⚙️ **Operations & DevOps**

| Path | Purpose | Key Scripts |
|------|---------|-------------|
| `scripts/ci/` | **Quality gates** (streaming, forecast, math) | `accept_streaming_gate.sh` |
| `scripts/security/` | **Security automation** | `create_readonly_mcp_role.sql` |
| `monitoring/` or `observability/` | **Dashboards & SQL views** | Grafana, Prometheus configs |
| `infra/` | **Infrastructure as Code** | Terraform, Kubernetes manifests |

### 📚 **Documentation & Testing**

| Path | Contents |
|------|----------|
| `docs/` | Architecture diagrams, API docs, deployment guides |
| `tests/` | Integration tests, quality assurance |
| `qa/` | QA automation, browser testing with Playwright |

---

## 🏃‍♂️ **10-Minute Quickstart**

### 1. **Clone & Setup**
```bash
git clone https://github.com/jgtolentino/ai-aas-hardened-lakehouse.git
cd ai-aas-hardened-lakehouse
cp .env.example .env.local  # Configure your environment
```

### 2. **Database Setup**
```bash
# Run all migrations
cd supabase && npx supabase migration up

# Seed development data  
psql "$DATABASE_URL" -f seed.sql
```

### 3. **Start Development**
```bash
# Scout Dashboard (React)
cd apps/scout-dashboard && npm install && npm run dev

# API Services
cd services/api && npm install && npm start
```

### 4. **Run Quality Gates**
```bash
# Streaming pipeline health
./scripts/ci/accept_streaming_gate.sh

# Math validation
./scripts/validate_analytics_math.sh
```

---

## 🎯 **Common Tasks**

| Task | Command/Location |
|------|------------------|
| **Add new migration** | `supabase/migrations/YYYYMMDD_description.sql` |
| **Deploy Edge Function** | `supabase functions deploy function-name` |
| **Run all tests** | `./scripts/run-tests.sh` |
| **Check pipeline health** | `./scripts/ci/accept_streaming_gate.sh` |
| **View monitoring** | `monitoring/grafana-dashboards/` |

---

## 🔒 **Security & Best Practices**

- **All DB changes** go through `supabase/migrations/`
- **No secrets** in code - use environment variables
- **Quality gates** must pass before merge
- **Review required** for production deployments

---

## 📞 **Getting Help**

- 📖 **Full docs**: `docs/README.md`
- 🏗️ **Architecture**: `docs/architecture/`
- 🚨 **Issues**: GitHub Issues tab
- 💬 **Questions**: Check existing issues or create new one

---

*Last updated: August 2024 | Scout v5.2*