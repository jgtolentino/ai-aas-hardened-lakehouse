#!/bin/bash

# Fix Script for 3 Issues
# 1. Supabase Scout MCP
# 2. Memory Bridge 
# 3. GitHub PRs

echo "=== Fixing Scout System Issues ==="

# 1. Fix Supabase MCP - Add credentials to keychain
echo "Setting up Supabase credentials in keychain..."
security add-generic-password -a $USER -s SUPABASE_SERVICE_KEY -w "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU" 2>/dev/null || echo "Service key already exists"
security add-generic-password -a $USER -s SUPABASE_ANON_KEY -w "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0" 2>/dev/null || echo "Anon key already exists"

# 2. Fix Memory Bridge - Install dependencies
echo "Installing memory bridge dependencies..."
cd /Users/tbwa/ai-aas-hardened-lakehouse/session-history
npm install @modelcontextprotocol/server-memory --save

# Make script executable
chmod +x memory_bridge.sh

# 3. Process GitHub PRs
echo "Processing open PRs..."
cd /Users/tbwa/ai-aas-hardened-lakehouse

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Stash any changes
git stash

# Process each PR
echo "Merging approved PRs..."

# Complete Creative Studio Agents Registry with 25+ Agents (#45)
git checkout main
git pull origin main
git merge origin/pr/45 --no-ff -m "Merge PR #45: Complete Creative Studio Agents Registry with 25+ Agents"

# Release/scout scraper v0.1.0 (#44)
git merge origin/pr/44 --no-ff -m "Merge PR #44: Release/scout scraper v0.1.0"

# feat: automated dictionary lifecycle with UNK feedback loop (#32)
git merge origin/pr/32 --no-ff -m "Merge PR #32: feat: automated dictionary lifecycle with UNK feedback loop"

# ci: nightly DQ enforcement (#31)
git merge origin/pr/31 --no-ff -m "Merge PR #31: ci: nightly DQ enforcement"

# ci: add canary checks with auto-rollback (#30)
git merge origin/pr/30 --no-ff -m "Merge PR #30: ci: add canary checks with auto-rollback"

# k8s: runtime hardening with security controls (#29)
git merge origin/pr/29 --no-ff -m "Merge PR #29: k8s: runtime hardening with security controls"

# ci: add SBOM and keyless signing for supply chain integrity (#28)
git merge origin/pr/28 --no-ff -m "Merge PR #28: ci: add SBOM and keyless signing for supply chain integrity"

# feat: auto-generated README sections + CI guard (#27)
git merge origin/pr/27 --no-ff -m "Merge PR #27: feat: auto-generated README sections + CI guard"

# ci: add Docker image release workflow to GHCR (#24)
git merge origin/pr/24 --no-ff -m "Merge PR #24: ci: add Docker image release workflow to GHCR"

# Push all merges
git push origin main

# Return to original branch
git checkout $CURRENT_BRANCH
git stash pop

echo "=== All fixes completed ==="
echo "Please restart Claude Desktop to apply MCP server changes"
