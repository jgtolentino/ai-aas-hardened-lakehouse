#!/usr/bin/env bash
set -euo pipefail
ROOT="/Users/tbwa/ai-aas-hardened-lakehouse"
MIGDIR="$ROOT/supabase/migrations"
mkdir -p "$MIGDIR"
TS=$(date +"%Y%m%d%H%M%S")

cat > "$MIGDIR/${TS}_finebank_stub_rpcs.sql" <<'SQL'
-- Safe placeholders that return empty sets if fact tables don't exist yet.
create or replace function public.scout_get_kpis(filters jsonb)
returns table (revenue numeric, transactions numeric, basket_size numeric, unique_shoppers numeric)
language plpgsql stable as $$
begin
  return query select 0::numeric, 0::numeric, 0::numeric, 0::numeric;
end$$;

create or replace function public.scout_get_revenue_trend(filters jsonb)
returns table (x text, y numeric)
language plpgsql stable as $$
begin
  return query select to_char(d::date,'YYYY-MM-DD')::text, 0::numeric
  from generate_series((now()-interval '28 days')::date, now()::date, interval '7 days') as d;
end$$;

create or replace function public.scout_get_hour_weekday(filters jsonb)
returns table (hour int, weekday int, value numeric)
language sql stable as $$
  select h, w, 0::numeric
  from generate_series(0,23) h cross join generate_series(0,6) w
$$;
SQL

echo "✅ Supabase RPC stubs created at $MIGDIR"
