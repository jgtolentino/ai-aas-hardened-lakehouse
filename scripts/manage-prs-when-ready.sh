#!/usr/bin/env bash
set -euo pipefail

echo "🎯 PR Management Commands"
echo "Run these when your GitHub token has 'public_repo' scope:"
echo

# Check current token status
echo "Current GitHub token status:"
gh auth status

echo
echo "=== CLOSE STALE PRS ==="
echo "# Close the oldest PRs (24+ days old)"
echo "gh pr close 1 --comment 'Closing stale PR: CI hardening superseded by Git Expert + Universal CI'"
echo "gh pr close 19 --comment 'Closing stale PR: DocsWriter features integrated elsewhere'"  
echo "gh pr close 20 --comment 'Closing stale PR: Monorepo restructuring handled in other PRs'"

echo
echo "=== CHECK WHICH PRS ARE GREEN ==="
echo "# After Universal CI runs, check which PRs are ready to merge:"

for pr in 52 45 44 32 31 30 29 28 27 24; do
    echo "echo -n 'PR #$pr: '; gh pr view $pr --json statusCheckRollup -q '.statusCheckRollup[0].state // \"NO_STATUS\"'"
done

echo
echo "=== MERGE GREEN PRS ==="
echo "# For each PR that shows SUCCESS status, run:"
echo "# gh pr merge <PR_NUMBER> --squash --delete-branch"
echo
echo "# Example commands (replace <PR_NUMBER> with actual green PRs):"
echo "# gh pr merge 52 --squash --delete-branch"
echo "# gh pr merge 45 --squash --delete-branch"
echo "# gh pr merge 44 --squash --delete-branch"

echo
echo "=== FIX TOKEN SCOPES ==="
echo "If you get scope errors, fix with:"
echo "1. Go to: https://github.com/settings/tokens"
echo "2. Edit your token and add 'public_repo' scope"
echo "3. Or run: gh auth refresh -h github.com -s public_repo"

echo
echo "=== MONITOR PROGRESS ==="
echo "# Watch PR status with:"
echo "./scripts/pr-simple.sh"

echo
echo "🚀 Once Universal CI runs on PRs, they should turn green and be ready for auto-merge!"