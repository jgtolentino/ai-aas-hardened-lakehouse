#!/usr/bin/env bash
set -euo pipefail

# Script to recreate failing Dependabot PRs with new workflows
# Usage: ./scripts/dependabot-recreate-failing.sh [OWNER/REPO]

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

echo "🔧 Dependabot PR Recreate Tool"
echo "================================"
echo "Repo: $REPO"
echo ""

echo "📋 Finding open Dependabot PRs with failing checks..."
echo ""

mapfile -t PRS < <(gh pr list -R "$REPO" \
  --search 'is:open author:app/dependabot' \
  --json number -q '.[].number')

if [[ ${#PRS[@]} -eq 0 ]]; then
  echo "✅ No open Dependabot PRs found."
  exit 0
fi

echo "Found ${#PRS[@]} open Dependabot PR(s)"
echo ""

RECREATED=0
SKIPPED=0

for PR in "${PRS[@]}"; do
  echo "🔍 Checking PR #$PR..."
  
  # Check if PR has failing checks
  FAILING=$(gh pr checks -R "$REPO" "$PR" --json bucket -q '[.[] | select(.bucket=="fail")] | length')
  
  if [[ "$FAILING" -gt 0 ]]; then
    echo "  ❌ PR #$PR has $FAILING failing check(s)"
    
    # Get PR title for better output
    TITLE=$(gh pr view -R "$REPO" "$PR" --json title -q '.title')
    echo "  📝 $TITLE"
    
    # Comment to recreate the PR
    echo "  🔄 Requesting Dependabot to recreate..."
    gh pr comment -R "$REPO" "$PR" --body "@dependabot recreate"
    
    ((RECREATED++))
    echo "  ✅ Recreate requested for PR #$PR"
  else
    echo "  ✅ PR #$PR is not failing (skipping)"
    ((SKIPPED++))
  fi
  
  echo ""
done

echo "================================"
echo "📊 Summary:"
echo "  🔄 Recreated: $RECREATED PRs"
echo "  ⏭️  Skipped: $SKIPPED PRs"
echo ""

if [[ $RECREATED -gt 0 ]]; then
  echo "🎯 Next Steps:"
  echo "  1. Dependabot will refresh those PRs (may take a few minutes)"
  echo "  2. New PRs will use the fixed workflows:"
  echo "     • Gitleaks: Skipped for Dependabot"
  echo "     • Tests: Fixed PNPM setup"
  echo "     • Vercel: Proper configuration"
  echo "  3. Run './scripts/dependabot-verify-status.sh' to check results"
  echo "  4. Use './scripts/dependabot-auto-merge.sh' to merge passing PRs"
  echo ""
  echo "⏰ Allow 5-10 minutes for Dependabot to process recreate requests"
else
  echo "🎉 All Dependabot PRs are already passing!"
fi