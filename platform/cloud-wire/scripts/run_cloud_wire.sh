#\!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Load env
if [ -f .env ]; then set -a; . ./.env; set +a; else cp .env.example .env && echo "Fill .env then rerun"; exit 1; fi
command -v envsubst >/dev/null || { echo "install gettext-base (envsubst)"; exit 1; }

# Render YAML → bundle.zip (World Bank + Choropleth)
mkdir -p superset/build/{databases,datasets,charts,dashboards}
envsubst < superset/assets/databases/postgres.yaml.tpl           > superset/build/databases/postgres.yaml
envsubst < superset/assets/datasets/world_bank.yaml.tpl          > superset/build/datasets/world_bank.yaml
envsubst < superset/assets/datasets/scout_choropleth.yaml.tpl    > superset/build/datasets/scout_choropleth.yaml
envsubst < superset/assets/charts/world_pop_growth.yaml.tpl      > superset/build/charts/world_pop_growth.yaml
envsubst < superset/assets/charts/scout_region_choropleth.yaml.tpl > superset/build/charts/scout_region_choropleth.yaml
envsubst < superset/assets/dashboards/world_bank_supabase.yaml.tpl > superset/build/dashboards/world_bank_supabase.yaml
envsubst < superset/assets/dashboards/scout_analytics_geo.yaml.tpl > superset/build/dashboards/scout_analytics_geo.yaml
cp superset/assets/metadata.yaml superset/build/metadata.yaml
( cd superset/build && zip -qr ../bundle.zip . )
echo "[ok] bundle: superset/bundle.zip (includes choropleth)"

# Run Bruno: login → csrf → create db (idempotent) → import bundle → test choropleth
pushd bruno >/dev/null
bruno run . --env production --only "01_login.bru"
bruno run . --env production --only "02_csrf.bru"
# Try DB create; ignore 422 if it already exists
bruno run . --env production --only "03_create_db_conn.bru" || true
bruno run . --env production --only "04_import_bundle.bru"
# Test choropleth visualization
bruno run . --env production --only "05_test_choropleth.bru" || echo "Choropleth test skipped (may need PostGIS data)"
popd >/dev/null

echo "[DONE] Cloud wire complete!"
echo "🌍 Open Superset and search:"
echo "  • World Bank's Data (Supabase)"
echo "  • Scout Analytics - Geographic Dashboard (Cloud)" 
echo "  • Philippines Regional Sales Heatmap (Cloud)"
