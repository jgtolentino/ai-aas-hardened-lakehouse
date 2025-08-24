#!/usr/bin/env bash
set -euo pipefail

# Required env: PGHOST PGPORT PGDATABASE PGUSER PGPASSWORD
# Optional env: MODEL_NAME MODEL_VERSION DAYS SN_PERIOD WAPE_TOL SMAPE_TOL MIN_COVERAGE MAX_COVERAGE

: "${MODEL_NAME:=demand_forecast}"
: "${MODEL_VERSION:=}"
: "${DAYS:=30}"
: "${SN_PERIOD:=7}"
: "${WAPE_TOL:=1.02}"
: "${SMAPE_TOL:=1.02}"
: "${MIN_COVERAGE:=0.75}"
: "${MAX_COVERAGE:=0.90}"

PSQL_URI="sslmode=require host=$PGHOST port=${PGPORT:-5432} dbname=$PGDATABASE user=$PGUSER"

echo "Applying/refreshing views..."
psql "$PSQL_URI" -v ON_ERROR_STOP=1 -f platform/scout/sql/metrics/backtest_baseline_30d.sql
psql "$PSQL_URI" -v ON_ERROR_STOP=1 -f platform/scout/sql/metrics/backtest_model_30d.sql

echo "Running forecast gate..."
psql "$PSQL_URI" \
  -v ON_ERROR_STOP=1 \
  -v MODEL_NAME="$MODEL_NAME" \
  -v MODEL_VERSION="$MODEL_VERSION" \
  -v DAYS="$DAYS" \
  -v SN_PERIOD="$SN_PERIOD" \
  -v WAPE_TOL="$WAPE_TOL" \
  -v SMAPE_TOL="$SMAPE_TOL" \
  -v MIN_COVERAGE="$MIN_COVERAGE" \
  -v MAX_COVERAGE="$MAX_COVERAGE" \
  -f platform/scout/sql/metrics/forecast_gate.sql