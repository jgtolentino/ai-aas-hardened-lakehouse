# 🌩️ Cloud Wire: API-First Superset ⇄ Supabase Integration

Zero-manual-SQL pipeline that wires Superset to Supabase with persistent credentials and choropleth maps.

## 🚀 Quick Start

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env with your actual Supabase URL, credentials, and Superset endpoint

# 2. Set up MCP (persistent credentials)
export SUPABASE_ACCESS_TOKEN="sbp_your_personal_access_token_here"

# 3. Run the complete pipeline
./scripts/run_cloud_wire.sh
```

## ✨ What This Gives You

### 🔗 **API-First Integration**
- Creates Supabase database connection in Superset via API
- Imports complete bundle: datasets + charts + dashboards
- No manual SQL copying or pasting
- Idempotent operations (safe to re-run)

### 🗺️ **Choropleth Pack Included**
- Geographic visualization of Scout Analytics data
- Mapbox integration for base map tiles
- Deck.gl GeoJSON rendering
- Philippines regional sales heatmap

### 🔐 **Persistent Credentials**
- MCP configuration for Claude integration
- Environment-based secret management
- No credential retyping across sessions

## 📁 What Gets Created

### Superset Assets
- **Database**: `Supabase (prod)` connection
- **Datasets**:
  - `world_bank.wb_health_population` - World Bank demo data
  - `scout.gold_region_choropleth` - Geographic sales data
- **Charts**:
  - `World's Pop Growth (Supabase)` - Line chart
  - `Philippines Regional Sales Heatmap (Cloud)` - Choropleth map
- **Dashboards**:
  - `World Bank's Data (Supabase)` - Demo dashboard
  - `Scout Analytics - Geographic Dashboard (Cloud)` - Geo dashboard

## 🧪 Testing & Verification

The pipeline includes Bruno API tests:
1. `01_login.bru` - Superset authentication
2. `02_csrf.bru` - CSRF token retrieval
3. `03_create_db_conn.bru` - Database connection creation
4. `04_import_bundle.bru` - YAML bundle import
5. `05_test_choropleth.bru` - Choropleth visualization test
6. `06_verify_geo_data.bru` - Geographic data verification

## 🔧 Configuration Options

### Cloud vs Self-Hosted Superset

**Cloud (Preset, etc.)**:
```bash
SUPERSET_BASE=https://your-account.preset.app
```

**Self-Hosted**:
```bash
SUPERSET_BASE=http://localhost:8088
# or
SUPERSET_BASE=https://superset.your-domain.com
```

### MCP Integration

Place the provided `mcp/mcp.json` in your MCP configuration directory:
- **Claude Desktop**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Project-specific**: Copy to `.mcp.json` in your project root

```json
{
  "mcpServers": {
    "supabase": {
      "command": "npx",
      "args": ["-y", "@supabase/mcp-server-supabase@latest", "--read-only"],
      "env": {
        "SUPABASE_URL": "https://your-project.supabase.co",
        "SUPABASE_ACCESS_TOKEN": "env://SUPABASE_ACCESS_TOKEN"
      }
    }
  }
}
```

## 📊 Prerequisites

### Required Services
- **Supabase project** with PostGIS enabled (for choropleth)
- **Superset instance** (cloud or self-hosted)
- **Mapbox account** for base map tiles (free tier OK)

### Required Data
For choropleth visualization to work:
```sql
-- Must exist in your Supabase project
scout.gold_region_choropleth (
  region_key TEXT,
  region_name TEXT,
  day DATE,
  peso_total NUMERIC,
  txn_count BIGINT,
  geom GEOMETRY
)
```

### Required Tools
- `bruno` CLI: `npm install -g @usebruno/cli`
- `envsubst`: `brew install gettext` (macOS) or `apt-get install gettext-base` (Ubuntu)

## 🔍 Troubleshooting

### Database Connection Fails
- Check `SUPABASE_DB_URI` format: `postgresql://user:pass@host:port/db`
- Verify Supabase project allows external connections
- Ensure credentials have sufficient permissions

### Bundle Import Fails
- Check Superset version compatibility (requires Apache Superset 2.0+)
- Verify CSRF token is being passed correctly
- Try running individual Bruno requests for debugging

### Choropleth Not Loading
- Verify PostGIS is enabled: `SELECT PostGIS_Version();`
- Check geographic data exists: `SELECT COUNT(*) FROM scout.gold_region_choropleth;`
- Ensure Mapbox API key is valid and has required permissions

### MCP Not Working
- Verify `SUPABASE_ACCESS_TOKEN` is set in environment
- Check MCP configuration syntax
- Ensure Supabase MCP server is installed: `npx @supabase/mcp-server-supabase@latest --version`

## 🧩 Extending the Pipeline

### Add New Datasets
1. Create `superset/assets/datasets/your_dataset.yaml.tpl`
2. Create corresponding chart/dashboard templates
3. Update `run_cloud_wire.sh` to include new files

### Custom Visualizations
1. Export existing chart from Superset UI
2. Convert to template with `${VARIABLE}` placeholders
3. Add to assets directory and build script

### Additional Tests
1. Create `.bru` files in `bruno/requests/`
2. Follow sequential naming: `07_your_test.bru`
3. Include proper assertions and variable saving

## 🎯 Production Deployment

### Security Checklist
- [ ] Use strong Superset admin password
- [ ] Rotate Supabase access tokens regularly
- [ ] Enable HTTPS for all endpoints
- [ ] Configure Superset CSRF protection
- [ ] Use read-only database user where possible

### Performance Optimization
- [ ] Enable Superset Redis caching
- [ ] Create database indexes for large datasets
- [ ] Use Superset async queries for heavy operations
- [ ] Configure appropriate query timeouts

## 🆘 Support

- **Supabase**: [docs.supabase.com](https://docs.supabase.com)
- **Apache Superset**: [superset.apache.org](https://superset.apache.org)
- **Bruno API Client**: [usebruno.com](https://usebruno.com)
- **Mapbox**: [docs.mapbox.com](https://docs.mapbox.com)

## 📚 Related Documentation

- [Choropleth Setup Guide](../docs/setup/choropleth_optimization.md)
- [Performance Benchmarks](../scripts/benchmark_choropleth_hard.py)
- [Complete Deployment Checklist](../DEPLOYMENT_CHECKLIST.md)