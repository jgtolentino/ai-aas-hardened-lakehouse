#!/usr/bin/env bash
set -euo pipefail

# Script to verify status of Dependabot PRs
# Usage: ./scripts/dependabot-verify-status.sh [OWNER/REPO]

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

echo "📊 Dependabot PR Status Report"
echo "==============================="
echo "Repo: $REPO"
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

PASSING=0
FAILING=0
PENDING=0

echo "📋 Status Overview:"
echo "-------------------"

for PR_DATA in "${PRS[@]}"; do
  IFS='|' read -r PR TITLE <<< "$PR_DATA"
  
  # Get check buckets
  BUCKETS=$(gh pr checks -R "$REPO" "$PR" --json bucket -q '[.[]|.bucket] | unique | join(",")')
  
  # Count status types
  FAIL_COUNT=$(gh pr checks -R "$REPO" "$PR" --json bucket -q '[.[] | select(.bucket=="fail")] | length')
  PENDING_COUNT=$(gh pr checks -R "$REPO" "$PR" --json bucket -q '[.[] | select(.bucket=="pending")] | length')
  
  # Truncate title if too long
  TRUNCATED_TITLE=$(echo "$TITLE" | cut -c1-60)
  if [[ ${#TITLE} -gt 60 ]]; then
    TRUNCATED_TITLE="${TRUNCATED_TITLE}..."
  fi
  
  if [[ "$FAIL_COUNT" -gt 0 ]]; then
    echo "❌ PR #$PR: $TRUNCATED_TITLE"
    echo "   Failing: $FAIL_COUNT checks"
    ((FAILING++))
  elif [[ "$PENDING_COUNT" -gt 0 ]]; then
    echo "⏳ PR #$PR: $TRUNCATED_TITLE"
    echo "   Pending: $PENDING_COUNT checks"
    ((PENDING++))
  else
    echo "✅ PR #$PR: $TRUNCATED_TITLE"
    echo "   All checks passing"
    ((PASSING++))
  fi
  echo ""
done

echo "==============================="
echo "📈 Summary:"
echo "  ✅ Passing: $PASSING PRs"
echo "  ❌ Failing: $FAILING PRs"  
echo "  ⏳ Pending: $PENDING PRs"
echo ""

if [[ $PASSING -gt 0 ]]; then
  echo "🚀 Ready to merge: $PASSING PR(s)"
  echo "   Run: ./scripts/dependabot-auto-merge.sh"
  echo ""
fi

if [[ $FAILING -gt 0 ]]; then
  echo "🔧 Need attention: $FAILING PR(s)"
  echo "   Run: ./scripts/dependabot-recreate-failing.sh"
  echo ""
fi

if [[ $PENDING -gt 0 ]]; then
  echo "⏳ In progress: $PENDING PR(s)"
  echo "   Wait for checks to complete"
  echo ""
fi

# Show detailed failing check info
if [[ $FAILING -gt 0 ]]; then
  echo "🔍 Detailed Failure Analysis:"
  echo "-----------------------------"
  
  for PR_DATA in "${PRS[@]}"; do
    IFS='|' read -r PR TITLE <<< "$PR_DATA"
    
    FAIL_COUNT=$(gh pr checks -R "$REPO" "$PR" --json bucket -q '[.[] | select(.bucket=="fail")] | length')
    
    if [[ "$FAIL_COUNT" -gt 0 ]]; then
      echo "PR #$PR failing checks:"
      gh pr checks -R "$REPO" "$PR" --json name,bucket,state \
        -q '.[] | select(.bucket=="fail") | "  • \(.name) (\(.state))"'
      echo ""
    fi
  done
fi

echo "🔄 To refresh this report: ./scripts/dependabot-verify-status.sh"