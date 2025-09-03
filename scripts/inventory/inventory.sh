#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$HOME/ai-aas-hardened-lakehouse}"
cd "$ROOT"

mkdir -p scripts/inventory out docs

# --- config (edit if needed) ---
: "${SUPABASE_PROJECT_REF:?set SUPABASE_PROJECT_REF=<ref>}"
: "${SUPABASE_ACCESS_TOKEN:?set SUPABASE_ACCESS_TOKEN=<pat>}"
KC_SERVICE="${KC_SERVICE:-ai-aas-hardened-lakehouse.supabase}"
OUT_JSON="out/supabase_inventory.json"
OUT_MD="docs/INVENTORY_AUTO.md"

# Resolve DATABASE_URL from Keychain (read-only user recommended)
DB_URL="$(security find-generic-password -s "$KC_SERVICE" -a DATABASE_URL -w 2>/dev/null || true)"
if [ -z "$DB_URL" ]; then
  echo "❌ DATABASE_URL not in Keychain (service=$KC_SERVICE, account=DATABASE_URL)"; exit 2
fi

echo "🔎 Collecting Edge Functions…"
if supabase functions list --project-ref "$SUPABASE_PROJECT_REF" --format json >/dev/null 2>&1; then
  supabase functions list --project-ref "$SUPABASE_PROJECT_REF" --format json > out/_edge.json
else
  # Fallback: table parse
  supabase functions list --project-ref "$SUPABASE_PROJECT_REF" > out/_edge.txt
  awk 'NR>2 && $1!=""{print $0}' out/_edge.txt | \
  awk -v OFS='\t' '{name=$1; inv=$(NF-1); for(i=2;i<=NF-2;i++){url=url $i " "} gsub(/[ \t]+$/,"",url); print name,url,inv; url="" }' | \
  jq -R -s 'split("\n")|map(select(length>0))|map(split("\t"))|map({name:.[0], url:.[1], invocations:(.[2]|tonumber?)})' > out/_edge.json
fi

echo "🗄️  Scanning repo migrations…"
MIGS=$(jq -n --arg root "$ROOT" '
  {
    main: ( [inputs] | . ),
    extra: []
  }' \
  < <(find supabase/migrations -maxdepth 1 -type f -name "*.sql" -print 2>/dev/null | sort | jq -R .) \
  < /dev/null)

# gather additional module migrations
EXTRA=$(find modules -type d -path "*/supabase/migrations" -print 2>/dev/null | while read -r d; do find "$d" -type f -name "*.sql"; done | sort | jq -R -s 'split("\n")|map(select(length>0))')
jq -n --argjson main "$(echo "$MIGS" | jq '.main')" --argjson extra "$EXTRA" '{main:$main, extra:$extra}' > out/_migs.json

echo "🧪 Querying database (psql)…"
PSQL="psql '$DB_URL' -v ON_ERROR_STOP=1 -qtAX"
SCHEMAS=$(eval "$PSQL" <<'SQL'
select json_agg(s) from (
  select schema_name as name
  from information_schema.schemata
  where schema_name in ('scout','public','auth','storage')
  order by 1
) s;
SQL
)

TABLE_COUNTS=$(eval "$PSQL" <<'SQL'
select json_agg(t) from (
  select table_schema as schema, count(*)::int as tables
  from information_schema.tables
  where table_type='BASE TABLE'
  group by 1
  order by 1
) t;
SQL
)

POLICIES=$(eval "$PSQL" <<'SQL'
select coalesce(json_agg(p), '[]'::json) from (
  select schemaname as schema, tablename as table, count(*)::int as policies
  from pg_policies
  where schemaname='scout'
  group by 1,2
  order by 1,2
) p;
SQL
)

MEDALLION=$(eval "$PSQL" <<'SQL'
with x as (
  select table_schema, table_name from information_schema.tables where table_type='BASE TABLE'
)
select json_build_object(
  'bronze', (select count(*) from x where table_name like 'bronze%'),
  'silver', (select count(*) from x where table_name like 'silver%'),
  'gold',   (select count(*) from x where table_name like 'gold%'),
  'platinum',(select count(*) from x where table_name like 'platinum%')
);
SQL
)

echo "🧩 Composing JSON…"
jq -n \
  --arg generated "$(date -u +%F)" \
  --arg repo "ai-aas-hardened-lakehouse" \
  --arg project "Scout Analytics Platform" \
  --slurpfile edge out/_edge.json \
  --slurpfile migs out/_migs.json \
  --argjson schemas "${SCHEMAS:-null}" \
  --argjson table_counts "${TABLE_COUNTS:-null}" \
  --argjson policies "${POLICIES:-[]}" \
  --argjson medallion "${MEDALLION:-null}" '
{
  generated: $generated,
  repository: $repo,
  project: $project,
  edge_functions: $edge[0],
  migrations: $migs[0],
  db: {
    schemas: $schemas,
    table_counts: $table_counts,
    policies: $policies,
    medallion_counts: $medallion
  }
}' > "$OUT_JSON"

echo "📝 Rendering Markdown…"
node - <<'NODE' "$OUT_JSON" "$OUT_MD"
const fs=require('fs'); const [,,inPath,outPath]=process.argv;
const j=JSON.parse(fs.readFileSync(inPath,'utf8'));
const ef=j.edge_functions||[];
const migMain=(j.migrations?.main)||[];
const migExtra=(j.migrations?.extra)||[];
const med=j.db?.medallion_counts||{};
function h(n){return n??0}
let md=`# Supabase Project Inventory (Auto-Generated)
**Generated**: ${j.generated}  \n**Repository**: ${j.repository}  \n**Project**: ${j.project}

## Summary
- Edge Functions: **${ef.length}**
- Migrations (main + modules): **${migMain.length + migExtra.length}** (${migMain.length} main, ${migExtra.length} modules)
- Schemas: ${(j.db?.schemas||[]).map(s=>s.name).join(', ')||'—'}
- Medallion counts: bronze=${h(med.bronze)}, silver=${h(med.silver)}, gold=${h(med.gold)}, platinum=${h(med.platinum)}

---

## Edge Functions
${ef.length?ef.map(x=>`- ${x.name||'?'}  ${x.last_updated?`(updated ${x.last_updated})`:''}`).join('\n'):'_none_'}

## Migrations
**Main** (${migMain.length})
${migMain.map(x=>`- ${x}`).join('\n')||'_none_'}

**Modules** (${migExtra.length})
${migExtra.map(x=>`- ${x}`).join('\n')||'_none_'}

## DB Policies (scout.*)
${(j.db.policies||[]).length?(j.db.policies||[]).map(p=>`- ${p.schema}.${p.table}: ${p.policies} policies`).join('\n'):'_none_'}

## Table counts by schema
${(j.db.table_counts||[]).map(t=>`- ${t.schema}: ${t.tables}`).join('\n')||'_none_'}
`;
fs.writeFileSync(outPath, md);
console.log("Wrote", outPath);
NODE

echo "✅ Inventory updated:"
echo "  - $OUT_JSON"
echo "  - $OUT_MD"