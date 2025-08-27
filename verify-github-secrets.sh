#!/usr/bin/env bash
set -euo pipefail

echo "🔍 GitHub Secrets Verification"
echo "=============================="

cd /Users/tbwa/ai-aas-hardened-lakehouse

echo ""
echo "📝 Current Repository Secrets:"
gh secret list

echo ""
echo "📝 Current Repository Variables:"  
gh variable list

echo ""
echo "🔄 Recent Workflow Runs:"
gh run list --limit 10

echo ""
echo "❌ Failed Runs (if any):"
gh run list --status failure --limit 5

echo ""
echo "🎯 To re-run failed workflow:"
echo "gh run rerun <RUN_ID> --failed"

echo ""
echo "🔗 Open workflows in browser:"
echo "gh browse --repo jgtolentino/ai-aas-hardened-lakehouse /actions"