#!/usr/bin/env bash
set -euo pipefail

# Script to auto-merge passing Dependabot PRs
# Usage: ./scripts/dependabot-auto-merge.sh [OWNER/REPO] [--dry-run]

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
  esac
done

echo "🚀 Dependabot Auto-Merge Tool"
echo "============================="
echo "Repo: $REPO"
if [[ "$DRY_RUN" == true ]]; then
  echo "Mode: DRY RUN (no actual merging)"
else
  echo "Mode: LIVE (will merge passing PRs)"
fi
echo ""

# Get all open Dependabot PRs
mapfile -t PRS < <(gh pr list -R "$REPO" \
  --search 'is:open author:app/dependabot' \
  --json number,title -q '.[] | "\(.number)|\(.title)"')

if [[ ${#PRS[@]} -eq 0 ]]; then
  echo "✅ No open Dependabot PRs found."
  exit 0
fi

echo "Found ${#PRS[@]} open Dependabot PR(s)"
echo ""

MERGED=0
SKIPPED=0

for PR_DATA in "${PRS[@]}"; do
  IFS='|' read -r PR TITLE <<< "$PR_DATA"
  
  echo "🔍 Checking PR #$PR..."
  
  # Check if all checks are passing (no failures)
  FAIL_COUNT=$(gh pr checks -R "$REPO" "$PR" --json bucket -q '[.[] | select(.bucket=="fail")] | length')
  PENDING_COUNT=$(gh pr checks -R "$REPO" "$PR" --json bucket -q '[.[] | select(.bucket=="pending")] | length')
  
  # Truncate title for display
  TRUNCATED_TITLE=$(echo "$TITLE" | cut -c1-50)
  if [[ ${#TITLE} -gt 50 ]]; then
    TRUNCATED_TITLE="${TRUNCATED_TITLE}..."
  fi
  
  echo "  📝 $TRUNCATED_TITLE"
  
  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo "  ❌ Has $FAIL_COUNT failing check(s) - skipping"
    ((SKIPPED++))
  elif [[ "$PENDING_COUNT" -gt 0 ]]; then
    echo "  ⏳ Has $PENDING_COUNT pending check(s) - skipping"
    ((SKIPPED++))
  else
    echo "  ✅ All checks passing"
    
    if [[ "$DRY_RUN" == true ]]; then
      echo "  🔍 [DRY RUN] Would merge PR #$PR with squash"
      ((MERGED++))
    else
      echo "  🚀 Merging with squash..."
      
      # Use --auto flag for auto-merge when checks pass
      if gh pr merge -R "$REPO" "$PR" --squash --auto 2>/dev/null; then
        echo "  ✅ Auto-merge enabled for PR #$PR"
        ((MERGED++))
      else
        echo "  ⚠️  Could not enable auto-merge (may already be set or have conflicts)"
        ((SKIPPED++))
      fi
    fi
  fi
  
  echo ""
done

echo "============================="
echo "📊 Summary:"
if [[ "$DRY_RUN" == true ]]; then
  echo "  🔍 Would merge: $MERGED PRs"
else
  echo "  ✅ Auto-merge enabled: $MERGED PRs"
fi
echo "  ⏭️  Skipped: $SKIPPED PRs"
echo ""

if [[ $MERGED -gt 0 ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    echo "🎯 Dry run complete. To actually merge:"
    echo "  ./scripts/dependabot-auto-merge.sh"
  else
    echo "🎯 Auto-merge enabled for passing PRs"
    echo "  PRs will merge automatically when all checks pass"
    echo "  Use 'gh pr list' to monitor merge status"
  fi
  echo ""
fi

if [[ $SKIPPED -gt 0 ]]; then
  echo "⚠️  Some PRs were skipped:"
  echo "  • Check './scripts/dependabot-verify-status.sh' for details"
  echo "  • Use './scripts/dependabot-recreate-failing.sh' for failing PRs"
  echo ""
fi

echo "🔄 To refresh status: ./scripts/dependabot-verify-status.sh"

# Safety note
if [[ "$DRY_RUN" == false ]] && [[ $MERGED -gt 0 ]]; then
  echo ""
  echo "⚡ Note: Auto-merge is enabled. PRs will merge when checks complete."
  echo "   To disable auto-merge on a PR: gh pr ready --undo [PR_NUMBER]"
fi