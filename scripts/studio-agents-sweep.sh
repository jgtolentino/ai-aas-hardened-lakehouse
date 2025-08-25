#!/usr/bin/env bash
# Root-wide Creative/Studio agent sweep + optional registry merge
# Portable: avoids 'mapfile' (works on macOS Bash 3.2)
set -euo pipefail

# --------- defaults / flags ----------
FORMAT="${FORMAT:-table}"    # table | csv | json
REGISTRY="${REGISTRY:-creative-studio/registry/creative-agents.yaml}"
UPDATE_REGISTRY=0
FAIL_ON_UNKNOWN=0
MIN_AGENTS="${MIN_AGENTS:-0}"

ROOTS=()

while (( "$#" )); do
  case "$1" in
    --update-registry) UPDATE_REGISTRY=1; shift ;;
    --fail-on-unknown) FAIL_ON_UNKNOWN=1; shift ;;
    --min) MIN_AGENTS="${2:-0}"; shift 2 ;;
    --format) FORMAT="${2:-table}"; shift 2 ;;
    --registry) REGISTRY="${2:-$REGISTRY}"; shift 2 ;;
    *) ROOTS+=("$1"); shift ;;
  esac
done

if [ "${#ROOTS[@]}" -eq 0 ]; then
  # Fallback: search current repo plus common siblings (quoted, spaces ok)
  ROOTS=( "." "../CreativeOps" "../creative-studio" "../Creative Studio" "../My Drive/Google AI Studio" )
fi

have_cmd(){ command -v "$1" >/dev/null 2>&1; }
HAVE_YQ=0; HAVE_JQ=0
have_cmd yq && HAVE_YQ=1
have_cmd jq && HAVE_JQ=1

tmp_candidates="$(mktemp)"; trap 'rm -f "$tmp_candidates"' EXIT

# --------- collect candidates ----------
for root in "${ROOTS[@]}"; do
  [ -d "$root" ] || continue
  # Focus on Creative/Studio/Ops directories but also include whole tree as fallback
  find "$root" \( -ipath "*/creative*" -o -ipath "*/*studio*" -o -ipath "*/ops*" -o -path "$root" \) \
    -type f \( -iname "*.yml" -o -iname "*.yaml" -o -iname "*.json" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" 2>/dev/null || true
done | sort -u > "$tmp_candidates"

# --------- parsing helpers ----------
print_row(){ # name|codename|id|version|type|owner|file|class|description
  printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
}

class_for_path(){
  case "$1" in
    *pulser/agents/*) echo "pulser" ;;
    *qa/pulser/agents/*) echo "qa" ;;
    *mcp/*) echo "mcp" ;;
    *creative-studio/*|*CreativeOps/*|*creative*studio*|*Studio/*) echo "creative" ;;
    *) echo "other" ;;
  esac
}

parse_yaml(){
  local f="$1"
  if [ $HAVE_YQ -eq 1 ]; then
    local name id code ver typ owner desc
    name=$(yq -r '.metadata.name // .name // "unknown"' "$f" 2>/dev/null || echo unknown)
    id=$(yq -r '.metadata.id // .id // .codename // "unknown"' "$f" 2>/dev/null || echo unknown)
    code=$(yq -r '.metadata.codename // .codename // .metadata.id // "unknown"' "$f" 2>/dev/null || echo unknown)
    ver=$(yq -r '.metadata.version // .version // "unknown"' "$f" 2>/dev/null || echo unknown)
    typ=$(yq -r '.metadata.type // .type // "unknown"' "$f" 2>/dev/null || echo unknown)
    owner=$(yq -r '.metadata.owner // .owner // "unknown"' "$f" 2>/dev/null || echo unknown)
    desc=$(yq -r '.metadata.description // .description // ""' "$f" 2>/dev/null || echo "")
    print_row "$name" "$code" "$id" "$ver" "$typ" "$owner" "$f" "$(class_for_path "$f")" "$desc"
  else
    # fallback (best-effort grep/awk)
    local name id code ver typ owner desc
    name=$(awk '/^metadata:/{m=1} m && /^[[:space:]]+name:/{sub(/.*name:[[:space:]]*/,""); gsub(/["\047]/, ""); print; exit}' "$f")
    [ -z "$name" ] && name=$(grep -E '^name:' "$f" | head -1 | sed 's/.*name:[[:space:]]*//' | tr -d '"\047')
    id=$(awk '/^metadata:/{m=1} m && /^[[:space:]]+id:/{sub(/.*id:[[:space:]]*/,""); gsub(/["\047]/, ""); print; exit}' "$f")
    code=$(awk '/^metadata:/{m=1} m && /^[[:space:]]+codename:/{sub(/.*codename:[[:space:]]*/,""); gsub(/["\047]/, ""); print; exit}' "$f")
    [ -z "$code" ] && code="$id"; [ -z "$code" ] && code="$name"
    ver=$(awk '/^metadata:/{m=1} m && /^[[:space:]]+version:/{sub(/.*version:[[:space:]]*/,""); gsub(/["\047]/, ""); print; exit}' "$f")
    typ=$(awk '/^metadata:/{m=1} m && /^[[:space:]]+type:/{sub(/.*type:[[:space:]]*/,""); gsub(/["\047]/, ""); print; exit}' "$f")
    owner=$(awk '/^metadata:/{m=1} m && /^[[:space:]]+owner:/{sub(/.*owner:[[:space:]]*/,""); gsub(/["\047]/, ""); print; exit}' "$f")
    desc=$(awk '/^metadata:/{m=1} m && /^[[:space:]]+description:/{sub(/.*description:[[:space:]]*/,""); gsub(/["\047]/, ""); print; exit}' "$f")
    print_row "${name:-unknown}" "${code:-unknown}" "${id:-unknown}" "${ver:-unknown}" "${typ:-unknown}" "${owner:-unknown}" "$f" "$(class_for_path "$f")" "${desc:-}"
  fi
}

# --------- sweep & collect ----------
rows_tmp="$(mktemp)"; trap 'rm -f "$rows_tmp" "$tmp_candidates"' EXIT
while IFS= read -r f; do
  case "${f##*.}" in
    yml|yaml) parse_yaml "$f" >> "$rows_tmp" ;;
    json)
      if [ $HAVE_JQ -eq 1 ]; then
        # try JSON with similar fields
        name=$(jq -r '.metadata.name // .name // "unknown"' "$f" 2>/dev/null || echo unknown)
        id=$(jq -r '.metadata.id // .id // .codename // "unknown"' "$f" 2>/dev/null || echo unknown)
        code=$(jq -r '.metadata.codename // .codename // .metadata.id // "unknown"' "$f" 2>/dev/null || echo unknown)
        ver=$(jq -r '.metadata.version // .version // "unknown"' "$f" 2>/dev/null || echo unknown)
        typ=$(jq -r '.metadata.type // .type // "unknown"' "$f" 2>/dev/null || echo unknown)
        owner=$(jq -r '.metadata.owner // .owner // "unknown"' "$f" 2>/dev/null || echo unknown)
        desc=$(jq -r '.metadata.description // .description // ""' "$f" 2>/dev/null || echo "")
        print_row "$name" "$code" "$id" "$ver" "$typ" "$owner" "$f" "$(class_for_path "$f")" "$desc" >> "$rows_tmp"
      fi
      ;;
  esac
done < "$tmp_candidates"

# de-dup by (file) then by (codename|file)
sort -u "$rows_tmp" > "${rows_tmp}.dedup"
mv "${rows_tmp}.dedup" "$rows_tmp"

# --------- unknowns / counters ----------
unknowns="$(grep -E '\|unknown\|' "$rows_tmp" || true)"
count_total="$(wc -l < "$rows_tmp" | tr -d ' ')"

# --------- output ----------
header="NAME|CODENAME|ID|VERSION|TYPE|OWNER|FILE|CLASS|DESCRIPTION"
case "$FORMAT" in
  csv)
    echo "${header//|/,}"
    sed 's/|/,/g' "$rows_tmp"
    ;;
  json)
    if [ $HAVE_JQ -eq 1 ]; then
      awk -F'|' 'BEGIN{print "["} {printf "{\"name\":\"%s\",\"codename\":\"%s\",\"id\":\"%s\",\"version\":\"%s\",\"type\":\"%s\",\"owner\":\"%s\",\"file\":\"%s\",\"class\":\"%s\",\"description\":\"%s\"}%s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9, (NR==0?"":",")} END{print "]"}' "$rows_tmp" | jq .
    else
      awk -F'|' 'BEGIN{print "["} {printf "{\"name\":\"%s\",\"codename\":\"%s\",\"id\":\"%s\",\"version\":\"%s\",\"type\":\"%s\",\"owner\":\"%s\",\"file\":\"%s\",\"class\":\"%s\",\"description\":\"%s\"}%s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9, (NR==0?"":",")} END{print "]"}' "$rows_tmp"
    fi
    ;;
  table|*)
    printf '%-28s %-30s %-26s %-10s %-12s %-28s %-48s %-10s %s\n' NAME CODENAME ID VERSION TYPE OWNER FILE CLASS DESCRIPTION
    while IFS='|' read -r a b c d e f g h i; do
      printf '%-28s %-30s %-26s %-10s %-12s %-28s %-48s %-10s %s\n' "$a" "$b" "$c" "$d" "$e" "$f" "$g" "$h" "$i"
    done < "$rows_tmp"
    ;;
esac

# --------- registry merge (optional) ----------
if [ "$UPDATE_REGISTRY" -eq 1 ]; then
  if [ $HAVE_YQ -ne 1 ]; then
    echo "WARN: --update-registry requested but 'yq' not found; skipping." >&2
  else
    mkdir -p "$(dirname "$REGISTRY")"
    [ -f "$REGISTRY" ] || printf 'version: 1\nupdated: "%s"\nagents: []\n' "$(date -u +%F)" > "$REGISTRY"
    # add missing entries
    while IFS='|' read -r _ codename _ _ _ owner file _ _; do
      # skip if codename/file unknown
      if [ "$codename" = "unknown" ] || [ "$file" = "unknown" ]; then continue; fi
      exists=$(yq -r ".agents[]?|select(.codename==\"$codename\")|.codename" "$REGISTRY" || true)
      if [ -z "$exists" ]; then
        yq -i ".agents += [{\"codename\":\"$codename\",\"file\":\"${file#./}\",\"owner\":\"$owner\",\"status\":\"active\"}]" "$REGISTRY"
      fi
    done < "$rows_tmp"
    yq -i ".updated = \"$(date -u +%F)\"" "$REGISTRY"
    echo "Updated registry: $REGISTRY" >&2
  fi
fi

# --------- gates ----------
if [ "$MIN_AGENTS" -gt 0 ] && [ "$count_total" -lt "$MIN_AGENTS" ]; then
  echo "✗ only $count_total agents found; expected >= $MIN_AGENTS" >&2
  exit 1
fi

if [ "$FAIL_ON_UNKNOWN" -eq 1 ] && [ -n "$unknowns" ]; then
  echo "✗ unknown fields present in some entries; run with FORMAT=table to inspect." >&2
  exit 1
fi