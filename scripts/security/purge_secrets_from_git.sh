#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# SECURITY: Purge Secrets from Git History
# WARNING: This rewrites git history - coordinate with team
# ============================================================

echo "🚨 SECURITY: Purging secrets from git history"
echo "============================================="

# Check if git-filter-repo is available
if ! command -v git-filter-repo >/dev/null 2>&1; then
    echo "Installing git-filter-repo..."
    python3 -m pip install --upgrade git-filter-repo
fi

echo "Creating replacement patterns for secret scrubbing..."

# Create replacement patterns file
cat > replacements.txt <<'EOF'
regex:sbp_[A-Za-z0-9]+==?==>REDACTED_SUPABASE_PAT
regex:eyJ[A-Za-z0-9_\-]+\.eyJ[A-Za-z0-9_\-]+\.?[A-Za-z0-9_\-]*==>REDACTED_JWT
regex:postgresql://[^@]+:[^@]+@[^/]+/[^"'\s]+==>postgresql://REDACTED:REDACTED@REDACTED/REDACTED
SUPABASE_ACCESS_TOKEN==>REDACTED_ACCESS_TOKEN
SUPABASE_SERVICE_ROLE_KEY==>REDACTED_SERVICE_ROLE
service_role==>REDACTED_ROLE
EOF

echo "Backing up current HEAD..."
git tag backup-before-secret-purge HEAD

echo "Rewriting git history to remove secrets..."

# Remove risky paths completely
git filter-repo --invert-paths \
    --path-glob '*.env.mcp' \
    --path-glob '**/secrets/*.json' \
    --force

# Replace secret patterns in remaining files
git filter-repo --replace-text replacements.txt --force

echo "Cleaning up temporary files..."
rm -f replacements.txt

echo "Verifying no secrets remain..."
if git log --all --source --grep="sbp_" --grep="eyJ" --oneline | head -10; then
    echo "⚠️  Some references may still exist - manual review needed"
else
    echo "✅ No obvious secret patterns found in commit messages"
fi

echo ""
echo "🔥 CRITICAL NEXT STEPS:"
echo "1. Push rewritten history: git push --force-with-lease"
echo "2. Notify all team members to re-clone the repository"
echo "3. Verify all CI/CD secrets are rotated in GitHub/Vercel/etc"
echo "4. Remove backup tag when confident: git tag -d backup-before-secret-purge"

echo ""
echo "⚠️  WARNING: This rewrites history. All contributors must re-clone!"