#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-.}"
OUTDIR="$ROOT/traces/usage"; mkdir -p "$OUTDIR"
OUT="$OUTDIR/usage-latest.csv"
# header
echo "date,agent,runs,input_tokens,output_tokens,total_tokens" > "$OUT"
# find JSONL traces: traces/<agent>/<ISO>.jsonl
find "$ROOT/traces" -type f -name '*.jsonl' | while read -r f; do
  agent="$(basename "$(dirname "$f")")"
  day="$(basename "$f" .jsonl | cut -c1-8)" # YYYYMMDD
  date="$(echo "$day" | sed -E 's#([0-9]{4})([0-9]{2})([0-9]{2})#\1-\2-\3#')"
  runs=1
  itok=$(jq -r 'select(.usage!=null) | .usage.input_tokens' < "$f" | awk '{s+=$1} END{print s+0}')
  otok=$(jq -r 'select(.usage!=null) | .usage.output_tokens' < "$f" | awk '{s+=$1} END{print s+0}')
  echo "$date,$agent,$runs,$itok,$otok,$((itok+otok))" >> "$OUT"
done
# roll-up (daily totals)
awk -F, 'NR==1{next} {k=$1; it[$1]+=$4; ot[$1]+=$5; tt[$1]+=$6; c[$1]+=1}
  END{print "date,runs,input_tokens,output_tokens,total_tokens" > "'$OUTDIR'/daily.csv";
      for (d in c) print d","c[d]","it[d]","ot[d]","tt[d] >> "'$OUTDIR'/daily.csv"}' "$OUT"
echo "$OUT"