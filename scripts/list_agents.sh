#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
FORMAT="${FORMAT:-table}"   # table | csv | json
shopt -s nullglob

# discover files (broadened: include ALL YAML in pulser/agents plus heuristics elsewhere)
mapfile -t FILES < <(
  {
    # 1) canonical agent folder(s)
    find "$ROOT/pulser/agents" -type f \( -iname '*.yml' -o -iname '*.yaml' \) 2>/dev/null
    find "$ROOT/qa/pulser/agents" -type f \( -iname '*.yml' -o -iname '*.yaml' \) 2>/dev/null
    # 2) heuristic matches across repo
    find "$ROOT" -type f \( -iname '*agent*.yml' -o -iname '*agent*.yaml' -o -iname '*.pulserrc' -o -iname 'registry.yaml' -o -iname 'mcp.json' \) 2>/dev/null
    # 3) configs that may carry agent metadata (e.g., agentic analytics, mcp)
    find "$ROOT"/{config,mcp} -type f \( -iname '*.yml' -o -iname '*.yaml' -o -iname '*.json' \) 2>/dev/null \
      | grep -Ei '(agent|agentic|mcp|registry|pulserrc|analytics)'
  } | sort -u
)

# yq/jq availability
have_yq=0; command -v yq >/dev/null 2>&1 && have_yq=1
have_jq=0; command -v jq >/dev/null 2>&1 && have_jq=1

# collectors
rows=()

emit_row() {
  local name="$1" codename="$2" version="$3" source="$4" desc="$5"
  rows+=("$name|$codename|$version|$source|$desc")
}

parse_yaml_with_yq() {
  local f="$1"
  # common Pulser agent schema - handle single document
  yq -o=json '
    {
       "name": .metadata.name // .name // "unknown",
       "codename": .metadata.id // .codename // .metadata.name // .name // "unknown",
       "version": .metadata.version // .version // "unknown",
       "description": .metadata.description // .description // "",
       "_source": "'"$f"'"
    }' "$f" 2>/dev/null || true
}

parse_yaml_fallback() {
  local f="$1"
  # super lenient grep-based extraction - handle nested metadata
  local name codename version desc id
  # Try to get name from metadata section first
  name=$(awk '/^metadata:/{m=1} m && /^[[:space:]]+name:/{gsub(/^[[:space:]]+name:[[:space:]]*/, ""); gsub(/["'"'"']/, ""); print; exit}' "$f")
  # If not found, try top-level
  [ -z "$name" ] && name=$(grep -E '^name:' "$f" | head -1 | sed 's/.*name:[[:space:]]*//' | sed 's/["'"'"']//g')
  
  # Get ID from metadata (used as codename)
  id=$(awk '/^metadata:/{m=1} m && /^[[:space:]]+id:/{gsub(/^[[:space:]]+id:[[:space:]]*/, ""); gsub(/["'"'"']/, ""); print; exit}' "$f")
  codename=$(grep -E '^ *codename:' "$f" | head -1 | sed 's/.*codename:[[:space:]]*//' | sed 's/["'"'"']//g')
  # Use id as codename if codename not found
  [ -z "$codename" ] && codename="$id"
  [ -z "$codename" ] && codename="$name"
  
  # Get version from metadata section
  version=$(awk '/^metadata:/{m=1} m && /^[[:space:]]+version:/{gsub(/^[[:space:]]+version:[[:space:]]*/, ""); gsub(/["'"'"']/, ""); print; exit}' "$f")
  [ -z "$version" ] && version=$(grep -E '^version:' "$f" | head -1 | sed 's/.*version:[[:space:]]*//' | sed 's/["'"'"']//g')
  
  # Get description from metadata section
  desc=$(awk '/^metadata:/{m=1} m && /^[[:space:]]+description:/{gsub(/^[[:space:]]+description:[[:space:]]*/, ""); gsub(/["'"'"']/, ""); print; exit}' "$f")
  [ -z "$desc" ] && desc=$(grep -E '^description:' "$f" | head -1 | sed 's/.*description:[[:space:]]*//' | sed 's/["'"'"']//g')
  
  echo "name=${name:-unknown} codename=${codename:-unknown} version=${version:-unknown} desc=$desc source=$f"
}

parse_pulserrc_defaults() {
  local f="$1"
  if [[ $have_yq -eq 1 ]]; then
    yq -o=json '.default_agents // [] | map({"name": .,"codename": .,"version":"(default)","_source":"'"$f"'","description":"default agent in .pulserrc"})' "$f" 2>/dev/null || true
  else
    grep -E 'default_agents' -n "$f" >/dev/null 2>&1 || return 0
    # naive list extraction
    awk '
      $0 ~ /default_agents:/ { inlist=1; next }
      inlist && $0 ~ /^ *- / { gsub(/^- /,""); gsub(/^ +/,""); print $0 }
      inlist && $0 !~ /^ *- / { inlist=0 }
    ' "$f" | while read -r a; do
      echo "name=$a codename=$a version=(default) desc=default agent in .pulserrc source=$f"
    done
  fi
}

parse_mcp_json() {
  local f="$1"
  [[ $have_jq -eq 1 ]] || return 0
  jq -r '
    to_entries[] | select(.key|test("servers|mcp_servers|mcp")) | .value
    | to_entries[] | {name: .key, codename: .key, version:"(mcp)", description:(.value.description//""), _source:"'"$f"'"}' "$f" 2>/dev/null || true
}

# walk files
for f in "${FILES[@]}"; do
  case "$f" in
    *.yaml|*.yml)
      if [[ $have_yq -eq 1 ]]; then
        # Parse single YAML document
        json_output=$(parse_yaml_with_yq "$f")
        if [[ -n "$json_output" ]]; then
          name=$(echo "$json_output" | jq -r '.name // "unknown"' 2>/dev/null || echo unknown)
          code=$(echo "$json_output" | jq -r '.codename // "unknown"' 2>/dev/null || echo unknown)
          ver=$(echo "$json_output" | jq -r '.version // "unknown"' 2>/dev/null || echo unknown)
          src=$(echo "$json_output" | jq -r '._source // "unknown"' 2>/dev/null || echo "$f")
          desc=$(echo "$json_output" | jq -r '.description // ""' 2>/dev/null || echo "")
          emit_row "$name" "$code" "$ver" "$src" "$desc"
        fi
      else
        # fallback
        eval "$(parse_yaml_fallback "$f")"
        emit_row "${name:-unknown}" "${codename:-unknown}" "${version:-unknown}" "$source" "${desc:-}"
      fi
      ;;
    *.pulserrc|registry.yaml)
      if [[ $have_yq -eq 1 ]]; then
        while IFS= read -r j; do
          name=$(jq -r '.name' <<<"$j")
          emit_row "$name" "$name" "(default)" "$f" "default agent in .pulserrc"
        done < <(parse_pulserrc_defaults "$f")
      else
        while read -r line; do
          eval "$line"   # sets name/codename/version/desc/source
          emit_row "${name:-unknown}" "${codename:-unknown}" "${version:-(default)}" "$source" "${desc:-}"
        done < <(parse_pulserrc_defaults "$f")
      fi
      ;;
    mcp.json)
      if [[ $have_jq -eq 1 ]]; then
        while IFS= read -r j; do
          name=$(jq -r '.name' <<<"$j")
          code=$(jq -r '.codename' <<<"$j")
          ver=$(jq -r '.version' <<<"$j")
          desc=$(jq -r '.description' <<<"$j")
          emit_row "$name" "$code" "$ver" "$f" "$desc"
        done < <(parse_mcp_json "$f")
      fi
      ;;
  esac
done

# de-dup
IFS=$'\n' read -r -d '' -a dedup < <(printf '%s\n' "${rows[@]}" | awk '!seen[$0]++' && printf '\0')

# output
case "$FORMAT" in
  csv)
    echo "name,codename,version,source,description"
    printf '%s\n' "${dedup[@]}" | sed 's/|/,/g'
    ;;
  json)
    if [[ $have_jq -eq 1 ]]; then
      printf '%s\n' "${dedup[@]}" | awk -F'|' '{printf("{\"name\":\"%s\",\"codename\":\"%s\",\"version\":\"%s\",\"source\":\"%s\",\"description\":\"%s\"}\n",$1,$2,$3,$4,$5)}' \
        | jq -s .
    else
      printf '%s\n' "${dedup[@]}" | awk -F'|' '{printf("{\"name\":\"%s\",\"codename\":\"%s\",\"version\":\"%s\",\"source\":\"%s\",\"description\":\"%s\"}\n",$1,$2,$3,$4,$5)}' \
        | sed '$!s/$/,/' | sed '1s/^/[/' -e '$s/$/]/'
    fi
    ;;
  table|*)
    printf '%-28s %-28s %-12s %-48s %s\n' "NAME" "CODENAME" "VERSION" "SOURCE" "DESCRIPTION"
    printf '%s\n' "${dedup[@]}" | while IFS='|' read -r a b c d e; do
      printf '%-28s %-28s %-12s %-48s %s\n' "$a" "$b" "$c" "$d" "$e"
    done
    ;;
esac

# basic validation: unique codenames
dupes=$(printf '%s\n' "${dedup[@]}" | awk -F'|' '{print $2}' | awk '++c[$0]==2{print $0}')
if [[ -n "${dupes:-}" ]]; then
  echo "WARN: duplicate codenames detected:" >&2
  printf ' - %s\n' $dupes >&2
fi