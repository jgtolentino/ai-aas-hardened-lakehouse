#!/usr/bin/env bash
# GitHub MCP Workflow Macros for AI-AAS Hardened Lakehouse
# Source this file to get quick functions for common GitHub operations

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Not in a git repository${NC}"
        return 1
    fi
}

# Get the GitHub repo name from origin
get_repo_name() {
    git remote get-url origin | sed -E 's/.*[:/]([^/]+\/[^/]+)\.git/\1/'
}

# 1. TODO Scanner → GitHub Issues
gh_todos_to_issues() {
    check_git_repo || return 1
    
    echo -e "${BLUE}🔍 Scanning for TODOs and creating GitHub issues...${NC}"
    
    claude <<'EOF'
Scan all .ts, .tsx, .js, .py, .go, .sql, and .md files in this repo for TODO, FIXME, and HACK markers. For each unique actionable item:
1. Create a GitHub issue with title format: '[TODO] <summary>'
2. Include the code snippet with file path and line number
3. Add labels: 'tech-debt', 'todo-conversion'
4. Group related TODOs if they're in the same file
5. Return a summary table with: File | Line | TODO Text | Issue URL
EOF
}

# 2. PR Summary Dashboard
gh_pr_summary() {
    check_git_repo || return 1
    
    echo -e "${BLUE}📊 Generating PR summary dashboard...${NC}"
    
    claude <<'EOF'
Using the GitHub MCP tools:
1. List all open PRs for this repository
2. For each PR, show:
   - PR number and title
   - Author and assigned reviewers
   - Status (draft, ready, approved, changes requested)
   - Number of comments and unresolved conversations
   - CI/CD check status
3. Highlight PRs waiting > 3 days for review
4. Format as a markdown table sorted by age
EOF
}

# 3. Issue Triage Report
gh_triage_issues() {
    check_git_repo || return 1
    
    echo -e "${BLUE}🐛 Creating issue triage report...${NC}"
    
    claude <<'EOF'
Create an issue triage report:
1. List all open issues with 'bug' label
2. Group by: Critical, High, Medium, Low (based on labels)
3. For each issue show: age, last update, assignee
4. Identify stale issues (no activity > 14 days)
5. Suggest assignees based on CODEOWNERS or recent commits to related files
6. Output as markdown with emoji indicators for urgency
EOF
}

# 4. CI Failures → Issues
gh_ci_failures() {
    check_git_repo || return 1
    
    echo -e "${BLUE}🚨 Checking CI failures and creating issues...${NC}"
    
    claude <<'EOF'
Check the most recent CI/CD runs for this repo:
1. Identify any failed workflows in the last 24 hours
2. For each unique failure:
   - Create an issue with title: '[CI Failure] <workflow_name> - <error_summary>'
   - Include relevant error logs
   - Add labels: 'ci-failure', 'automated'
   - Assign to the last person who modified the workflow file
3. Link the issue to the failed run URL
EOF
}

# 5. Weekly Metrics
gh_weekly_metrics() {
    check_git_repo || return 1
    
    echo -e "${BLUE}📈 Generating weekly metrics report...${NC}"
    
    claude <<'EOF'
Generate a weekly PR metrics report:
1. Count PRs: opened, closed, merged this week
2. Average time to merge
3. Average number of review cycles
4. Top contributors by PRs merged
5. Longest open PRs with reasons
6. Format as a markdown report suitable for team standup
EOF
}

# 6. Data Quality Issues (Lakehouse specific)
gh_data_quality_issues() {
    check_git_repo || return 1
    
    echo -e "${BLUE}📊 Creating issues from data quality checks...${NC}"
    
    claude <<'EOF'
For the AI-AAS Hardened Lakehouse project:
1. Check for any failed Great Expectations validations
2. Look for dbt test failures in the logs
3. Identify Suqi Chat performance degradations
4. For each issue found:
   - Create GitHub issue with appropriate title
   - Include metrics/logs
   - Label with 'data-quality', severity
   - Assign to data team
EOF
}

# 7. Security Audit Issues
gh_security_audit() {
    check_git_repo || return 1
    
    echo -e "${BLUE}🔐 Running security audit and creating issues...${NC}"
    
    claude <<'EOF'
Security audit for the repository:
1. Check for TODO/FIXME markers mentioning security
2. Look for hardcoded credentials patterns
3. Identify dependencies with known vulnerabilities
4. Check for missing security headers in API code
5. Create issues for each finding with:
   - Title: '[Security] <issue_type>'
   - Labels: 'security', 'priority-high'
   - Private visibility if supported
   - Assign to security team
EOF
}

# 8. Release Notes Generator
gh_release_notes() {
    local TAG=${1:-""}
    check_git_repo || return 1
    
    echo -e "${BLUE}📝 Generating release notes...${NC}"
    
    if [ -z "$TAG" ]; then
        echo -e "${YELLOW}No tag specified, using last tag${NC}"
        TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
    fi
    
    claude <<EOF
Generate release notes since tag $TAG:
1. Find all merged PRs since that tag
2. Group by: Features, Bug Fixes, Chores, Breaking Changes
3. Extract PR titles and numbers
4. Include contributor acknowledgments
5. Note any Suqi Chat or AI orchestration updates
6. Format as markdown suitable for GitHub releases
7. Create a draft release with the generated notes
EOF
}

# 9. Epic Management
gh_link_epics() {
    check_git_repo || return 1
    
    echo -e "${BLUE}🔗 Linking issues to epics...${NC}"
    
    claude <<'EOF'
Link related issues to epics:
1. Find all issues with 'epic' label
2. For each epic, search for issues mentioning the epic number or title
3. Add a comment on related issues: 'Linked to Epic #X'
4. Create a summary showing the epic hierarchy
5. Identify orphaned issues that might belong to an epic
6. Special attention to AI/ML and Suqi Chat related epics
EOF
}

# 10. Contributor Report
gh_contributor_report() {
    check_git_repo || return 1
    
    echo -e "${BLUE}👥 Generating contributor report...${NC}"
    
    claude <<'EOF'
Analyze contributor patterns for the last 30 days:
1. List all contributors with PR/issue counts
2. Identify new contributors (first PR/issue)
3. Show contribution trends (increasing/decreasing)
4. Highlight top reviewers
5. Find potential maintainer candidates
6. Special recognition for Suqi Chat and AI features contributors
7. Output as a contribution health report
EOF
}

# Interactive menu
gh_mcp_menu() {
    echo -e "${GREEN}=== GitHub MCP Workflow Menu ===${NC}"
    echo "1) TODO Scanner → GitHub Issues"
    echo "2) PR Summary Dashboard"
    echo "3) Issue Triage Report"
    echo "4) CI Failures → Issues"
    echo "5) Weekly Metrics"
    echo "6) Data Quality Issues"
    echo "7) Security Audit"
    echo "8) Generate Release Notes"
    echo "9) Link Issues to Epics"
    echo "10) Contributor Report"
    echo "q) Quit"
    
    read -p "Select option: " choice
    
    case $choice in
        1) gh_todos_to_issues ;;
        2) gh_pr_summary ;;
        3) gh_triage_issues ;;
        4) gh_ci_failures ;;
        5) gh_weekly_metrics ;;
        6) gh_data_quality_issues ;;
        7) gh_security_audit ;;
        8) 
            read -p "Enter tag to generate notes from (or press Enter for last tag): " tag
            gh_release_notes "$tag"
            ;;
        9) gh_link_epics ;;
        10) gh_contributor_report ;;
        q) echo "Exiting..." ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
}

# Aliases for quick access
alias gh-todos='gh_todos_to_issues'
alias gh-prs='gh_pr_summary'
alias gh-triage='gh_triage_issues'
alias gh-ci='gh_ci_failures'
alias gh-metrics='gh_weekly_metrics'
alias gh-quality='gh_data_quality_issues'
alias gh-security='gh_security_audit'
alias gh-release='gh_release_notes'
alias gh-epics='gh_link_epics'
alias gh-contributors='gh_contributor_report'
alias gh-menu='gh_mcp_menu'

# Help function
gh_mcp_help() {
    echo -e "${GREEN}GitHub MCP Workflow Commands:${NC}"
    echo "  gh-todos        - Scan TODOs and create issues"
    echo "  gh-prs          - PR summary dashboard"
    echo "  gh-triage       - Triage bug issues"
    echo "  gh-ci           - Create issues from CI failures"
    echo "  gh-metrics      - Weekly metrics report"
    echo "  gh-quality      - Data quality issues"
    echo "  gh-security     - Security audit"
    echo "  gh-release [tag] - Generate release notes"
    echo "  gh-epics        - Link issues to epics"
    echo "  gh-contributors - Contributor report"
    echo "  gh-menu         - Interactive menu"
    echo ""
    echo "Run any command in a git repository with GitHub MCP configured."
}

# Show help on source
echo -e "${GREEN}GitHub MCP macros loaded!${NC} Type 'gh_mcp_help' for available commands."