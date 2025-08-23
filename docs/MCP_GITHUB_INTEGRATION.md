# GitHub MCP Server Integration Guide

A fast, execution-ready guide to use the GitHub MCP server with Claude Code CLI—no hard-coded tokens, minimal scope, and copy-paste commands.

---

## 1) Prerequisites

* Docker installed
* Claude Code CLI (or your orchestrator) can read `~/.mcp/mcp.json`
* GitHub Personal Access Token (PAT) with minimal scopes

---

## 2) One-time Secure Token Setup (macOS Keychain)

> If you already set this up from earlier, skip to **Step 3**.

```bash
# Store the fine-grained PAT in Keychain (paste when prompted)
read -s -p "Paste NEW_GH_PAT: " NEW_GH_PAT; echo
security add-generic-password -a "$USER" -s GITHUB_PAT -w "$NEW_GH_PAT" -U
unset NEW_GH_PAT

# Minimal env loader (no token literal on disk)
mkdir -p ~/.secrets
cat > ~/.secrets/github_pat.env <<'EOF'
export GITHUB_TOKEN="$(security find-generic-password -s GITHUB_PAT -w)"
export GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN"
EOF
chmod 600 ~/.secrets/github_pat.env

# One-shot launcher that injects the token only at runtime
mkdir -p ~/bin
cat > ~/bin/mcp-github.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
export GITHUB_TOKEN="$(security find-generic-password -s GITHUB_PAT -w)"
exec docker run -i --rm -e GITHUB_TOKEN ghcr.io/model-context-protocol/github:latest
SH
chmod +x ~/bin/mcp-github.sh
echo "✅ Keychain secret set, env loader & MCP GitHub launcher ready."
```

### Required PAT Scopes

For issue work, give the fine-grained PAT repo-level access with:
- **Issues**: Read/Write
- **Metadata**: Read  
- **Pull Requests**: Read (optional)

Avoid `contents:write` unless you need to push code.

---

## 3) Register the GitHub MCP Server

```bash
mkdir -p ~/.mcp
cat > ~/.mcp/mcp.json <<'JSON'
{
  "github": {
    "command": "~/bin/mcp-github.sh",
    "args": [],
    "working_directory": "~"
  }
}
JSON
echo "✅ Registered MCP server 'github' in ~/.mcp/mcp.json"
```

Claude Code CLI (or your MCP-aware IDE) will pick this up on next start.

---

## 4) Smoke Test

```bash
# Prime env for this shell only (optional)
source ~/.secrets/github_pat.env

# Pull image (first run will do this anyway)
docker pull ghcr.io/model-context-protocol/github:latest

# Dry-run the container (should output MCP handshake logs or wait for a client)
~/bin/mcp-github.sh </dev/null | head -n 5 || true
echo "If you see handshake/waiting logs, the server is healthy."
```

---

## 5) Ready-to-Run Prompt Snippets

### Tool Discovery

```
"Show the list of tools and schemas for the MCP server named `github`, then give me short examples for each."
```

### Common Workflows

#### 📋 TODO Scanner → GitHub Issues

```
"Scan all .ts, .tsx, .js, .py, .go, and .md files in this repo for TODO, FIXME, and HACK markers. For each unique actionable item:
1. Create a GitHub issue with title format: '[TODO] <summary>'
2. Include the code snippet with file path and line number
3. Add labels: 'tech-debt', 'todo-conversion'
4. Group related TODOs if they're in the same file
5. Return a summary table with: File | Line | TODO Text | Issue URL"
```

#### 🔍 PR Summary with Reviewers

```
"Using the GitHub MCP tools:
1. List all open PRs for this repository
2. For each PR, show:
   - PR number and title
   - Author and assigned reviewers
   - Status (draft, ready, approved, changes requested)
   - Number of comments and unresolved conversations
   - CI/CD check status
3. Highlight PRs waiting > 3 days for review
4. Format as a markdown table sorted by age"
```

#### 🐛 Issue Triage Dashboard

```
"Create an issue triage report:
1. List all open issues with 'bug' label
2. Group by: Critical, High, Medium, Low (based on labels)
3. For each issue show: age, last update, assignee
4. Identify stale issues (no activity > 14 days)
5. Suggest assignees based on CODEOWNERS or recent commits to related files
6. Output as markdown with emoji indicators for urgency"
```

#### 🚨 CI Failure → Issue Creation

```
"Check the most recent CI/CD runs for this repo:
1. Identify any failed workflows in the last 24 hours
2. For each unique failure:
   - Create an issue with title: '[CI Failure] <workflow_name> - <error_summary>'
   - Include relevant error logs
   - Add labels: 'ci-failure', 'automated'
   - Assign to the last person who modified the workflow file
3. Link the issue to the failed run URL"
```

#### 📊 Weekly PR Metrics

```
"Generate a weekly PR metrics report:
1. Count PRs: opened, closed, merged this week
2. Average time to merge
3. Average number of review cycles
4. Top contributors by PRs merged
5. Longest open PRs with reasons
6. Format as a markdown report suitable for team standup"
```

#### 🏷️ Label Standardization

```
"Audit and standardize issue labels:
1. List all existing labels with usage count
2. Identify similar/duplicate labels (e.g., 'bug' vs 'defect')
3. Propose a standardized label set with colors:
   - Type: bug, feature, chore, docs
   - Priority: P0-critical, P1-high, P2-medium, P3-low
   - Status: in-progress, blocked, needs-review
4. Create missing labels
5. Suggest bulk relabeling operations"
```

#### 🔗 Epic Linking

```
"Link related issues to epics:
1. Find all issues with 'epic' label
2. For each epic, search for issues mentioning the epic number or title
3. Add a comment on related issues: 'Linked to Epic #X'
4. Create a summary showing the epic hierarchy
5. Identify orphaned issues that might belong to an epic"
```

---

## 6) Repository Context

Many GitHub MCP flows use your **current working directory** to resolve the repo remote. Open Claude Code CLI in the repo folder:

```bash
cd /path/to/your-repo
# Now ask Claude to "create issues from TODOs" etc.
```

---

## 7) Security Best Practices

### Token Rotation

```bash
# Rotate every 60-90 days and name tokens clearly:
# e.g., "MCP-GitHub-MBP-2025-01 (Issues RW, PR Read)"

# Quick local leak scan:
grep -R --exclude-dir=.git -nE 'ghp_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]+' ~ 2>/dev/null || true
```

### Audit Access

```bash
# Check what repos the token can access
curl -H "Authorization: token $(security find-generic-password -s GITHUB_PAT -w)" \
  https://api.github.com/user/repos | jq '.[].full_name'
```

---

## 8) Advanced Workflows

### 🔄 Automated Release Notes

```
"Generate release notes for the next version:
1. Find all merged PRs since the last tag
2. Group by: Features, Bug Fixes, Chores, Breaking Changes
3. Extract PR titles and numbers
4. Include contributor acknowledgments
5. Format as markdown suitable for GitHub releases
6. Create a draft release with the generated notes"
```

### 📈 Contributor Analytics

```
"Analyze contributor patterns for the last 30 days:
1. List all contributors with PR/issue counts
2. Identify new contributors (first PR/issue)
3. Show contribution trends (increasing/decreasing)
4. Highlight top reviewers
5. Find potential maintainer candidates (high-quality contributions)
6. Output as a contribution health report"
```

### 🔐 Security Issue Workflow

```
"For security-related issues:
1. List all issues with 'security' label
2. Ensure they're private (if repo supports)
3. Check for accidental sensitive data in comments
4. Verify assignee has security team membership
5. Create a private tracking document with remediation timeline
6. Set up automated status updates every 48h"
```

---

## 9) Troubleshooting

### Common Issues

**MCP server not found:**
```bash
# Verify registration
cat ~/.mcp/mcp.json

# Check executable
ls -la ~/bin/mcp-github.sh

# Test token retrieval
security find-generic-password -s GITHUB_PAT -w
```

**Permission denied errors:**
```bash
# Verify token scopes
curl -H "Authorization: token $(security find-generic-password -s GITHUB_PAT -w)" \
  https://api.github.com/user \
  -I | grep X-OAuth-Scopes
```

**Container issues:**
```bash
# Check Docker daemon
docker ps

# Manually test container
docker run --rm -e GITHUB_TOKEN="$(security find-generic-password -s GITHUB_PAT -w)" \
  ghcr.io/model-context-protocol/github:latest
```

---

## 10) Integration with AI-AAS Lakehouse

### Create Issues from Data Quality Checks

```
"Analyze the data quality reports in scout.quality_check_results:
1. For each failing check with severity > 'warning'
2. Create a GitHub issue with:
   - Title: '[Data Quality] <check_name> failing on <table_name>'
   - Body: Include the check SQL, failure count, and sample bad records
   - Labels: 'data-quality', 'automated', severity level
   - Assign to data engineering team member
3. Link issues to the quality dashboard"
```

### Monitor Suqi Chat Performance

```
"Using Suqi Chat performance metrics:
1. If p95 response time > 2000ms for 3 consecutive hours
2. Create an issue: '[Performance] Suqi Chat P95 degradation'
3. Include metrics snapshot and potential causes
4. Label as 'performance', 'P1-high'
5. Assign to on-call engineer
6. Set up hourly status comments until resolved"
```

---

## What You Can Do with GitHub MCP

* **Issue Automation**: Create/update/close issues; link commits, attach labels, assign owners
* **PR Operations**: List/summarize PRs, fetch comments/reviews, post review comments, merge (if permitted)
* **Repository Intelligence**: Fetch contributors, commits, releases, branch protection data
* **Workflow Automation**: Raise maintenance issues from CI failures, turn TODOs into issues, backfill labels, cross-link epics

---

## Quick Reference Card

```bash
# Setup (one-time)
security add-generic-password -a "$USER" -s GITHUB_PAT -w "YOUR_PAT" -U
~/bin/mcp-github.sh  # Create launcher
~/.mcp/mcp.json     # Register server

# Daily use
cd /your/repo
claude "Create issues from TODOs"
claude "Summarize open PRs"
claude "Triage bug issues"

# Maintenance
security delete-generic-password -s GITHUB_PAT  # Before rotation
grep -R "ghp_" ~  # Leak scan
```

---

This integration enables powerful GitHub automation directly from Claude, perfect for maintaining the AI-AAS Hardened Lakehouse project!