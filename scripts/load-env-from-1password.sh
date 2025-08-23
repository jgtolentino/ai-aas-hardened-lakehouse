#!/usr/bin/env bash
# Load environment variables from 1Password using template
set -euo pipefail

if ! command -v op >/dev/null 2>&1; then
  echo "❌ 1Password CLI (op) not found. Install from: https://developer.1password.com/docs/cli"
  exit 1
fi

# Ensure user is signed in
if ! op account get >/dev/null 2>&1; then
  echo "🔐 Please sign in to 1Password:"
  eval $(op signin)
fi

# Load variables from template
while IFS= read -r line; do
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  if [[ "$line" =~ ^export ]]; then
    var="${line#export }"
    var="${var%%=*}"
    ref="${line#*=}"
    ref="${ref//\'/}"
    
    # Special case for static values
    if [[ "$ref" != "op://"* ]]; then
      export "$var"="$ref"
    else
      value=$(op read "$ref" 2>/dev/null) || {
        echo "⚠️  Failed to read $var from 1Password"
        continue
      }
      export "$var"="$value"
    fi
  fi
done < .env.op.template

echo "✅ Environment loaded from 1Password"