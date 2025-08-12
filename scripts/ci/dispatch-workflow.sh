#!/bin/bash
# Dispatch workflow script for CI operations
# Usage: ./dispatch-workflow.sh <workflow_file> <pr_number>

set -e

WORKFLOW_FILE="$1"
PR_NUMBER="$2"

if [ -z "$WORKFLOW_FILE" ] || [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <workflow_file> <pr_number>"
    echo "Example: $0 .github/workflows/security.yml 19"
    exit 1
fi

# Get PR details
PR_DETAILS=$(gh pr view "$PR_NUMBER" --json headRefName,baseRefName)
HEAD_REF=$(echo "$PR_DETAILS" | jq -r '.headRefName')
BASE_REF=$(echo "$PR_DETAILS" | jq -r '.baseRefName')

echo "Dispatching workflow: $WORKFLOW_FILE"
echo "PR: #$PR_NUMBER ($HEAD_REF -> $BASE_REF)"

# Dispatch the workflow
gh workflow run "$WORKFLOW_FILE" --ref "$HEAD_REF"

echo "✅ Workflow dispatched successfully"
echo "Check status with: gh run list --branch $HEAD_REF"