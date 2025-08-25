#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
REG="$ROOT/pulser/registry/agents.yaml"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing $1"; exit 2; }; }
need yq; need jq

# 1) Collect manifests (Pulser + QA + MCP-as-agents if desired)
mapfile -t FILES < <(
  { find "$ROOT/pulser/agents" -type f \( -iname '*.yml' -o -iname '*.yaml' \) 2>/dev/null;
    find "$ROOT/qa/pulser/agents" -type f \( -iname '*.yml' -o -iname '*.yaml' \) 2>/dev/null;
    find "$ROOT/mcp/agents" -type f \( -iname '*.yml' -o -iname '*.yaml' \) 2>/dev/null;
    find "$ROOT/config" -name "agentic-analytics.yaml" 2>/dev/null; } | sort -u
)

[[ -f "$REG" ]] || { echo "Registry missing: $REG"; exit 1; }

# 2) Extract from registry
mapfile -t REG_CODENAMES < <(yq -r '.agents[].codename' "$REG" | sort -u)
mapfile -t REG_FILES     < <(yq -r '.agents[].file' "$REG" | sort -u)

# 3) Lint each manifest
errors=0
declare -A seen_code seen_id
declare -a FS_CODENAMES FS_FILES

for f in "${FILES[@]}"; do
  # Read required fields; support both top-level and metadata nesting
  name=$(yq -r '.metadata.name // .name // "unknown"' "$f")
  id=$(yq -r '.metadata.id // .codename // "unknown"' "$f")
  code=$(yq -r '.metadata.codename // .codename // .metadata.id // "unknown"' "$f")
  ver=$(yq -r '.metadata.version // .version // "unknown"' "$f")
  typ=$(yq -r '.metadata.type // .type // "unknown"' "$f")
  owner=$(yq -r '.metadata.owner // .owner // "unknown"' "$f")

  FS_CODENAMES+=("$code"); FS_FILES+=("$f")

  # Naming rules
  [[ "$code" =~ ^[a-z0-9][a-z0-9-]*-v[0-9]+$ ]] || { echo "✗ codename invalid: $code ($f)"; errors=$((errors+1)); }
  [[ "$id"   =~ ^[a-z0-9][a-z0-9-]*-v[0-9]+$ ]] || { echo "✗ id invalid: $id ($f)"; errors=$((errors+1)); }

  # Semver is required for version (not just -vN)
  [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "✗ version not semver (x.y.z): $ver ($f)"; errors=$((errors+1)); }

  # Type enum
  case "$typ" in
    architect|engineer|analyzer|generator|orchestrator|writer|analytics|mcp) : ;;
    *) echo "✗ type invalid: $typ ($f)"; errors=$((errors+1));;
  esac

  # Owner required
  [[ "$owner" != "unknown" ]] || { echo "✗ owner missing ($f)"; errors=$((errors+1)); }

  # Uniqueness
  if [[ -n "${seen_code[$code]:-}" ]]; then echo "✗ duplicate codename: $code"; errors=$((errors+1)); fi
  seen_code[$code]=1
  if [[ -n "${seen_id[$id]:-}" ]]; then echo "✗ duplicate id: $id"; errors=$((errors+1)); fi
  seen_id[$id]=1

  # Anthropic-first guardrails
  # tools allow-list must exist; forbid obvious secrets keys
  if ! yq -e '.tools' "$f" >/dev/null 2>&1 && ! yq -e '.capabilities' "$f" >/dev/null 2>&1; then 
    echo "✗ tools/capabilities section missing ($f)"; errors=$((errors+1)); 
  fi
  if grep -Eq 'anon_key|service_role|api_key|password' "$f"; then
    echo "✗ probable secret embedded in $f"; errors=$((errors+1));
  fi
done

# 4) Registry parity
# set difference: registry files vs filesystem files
missing_in_fs=0
for rf in "${REG_FILES[@]}"; do
  found=0
  for ff in "${FS_FILES[@]}"; do
    if [[ "$ff" == *"$rf" ]] || [[ "$rf" == *"$(basename "$ff")" ]]; then
      found=1
      break
    fi
  done
  if [[ $found -eq 0 ]]; then
    echo "✗ registry lists file not found: $rf"; missing_in_fs=1; errors=$((errors+1))
  fi
done

missing_in_reg=0
for ff in "${FS_FILES[@]}"; do
  rel_path="${ff#$ROOT/}"
  found=0
  for rf in "${REG_FILES[@]}"; do
    if [[ "$rf" == "$rel_path" ]]; then
      found=1
      break
    fi
  done
  if [[ $found -eq 0 ]]; then
    echo "✗ file not in registry: $rel_path"; missing_in_reg=1; errors=$((errors+1))
  fi
done

# 5) Count gate (optionally enforce >=15)
count="${#FS_FILES[@]}"
min="${MIN_AGENTS:-15}"
if (( count < min )); then
  echo "✗ only $count agents found; expected >= $min"; errors=$((errors+1))
fi

# 6) Print summary & exit code
if (( errors > 0 )); then
  echo "❌ agent validation failed with $errors error(s)."
  exit 1
else
  echo "✅ agents OK ($count) and registry in sync."
fi