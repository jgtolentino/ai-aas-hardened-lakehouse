# 🤖 Claude Code CLI as Automated PR Reviewer

## Quick Start (3 Steps)

### 1. Enable GitHub Integration
The integration is automatically active for this repository through GitHub Actions.

### 2. Trigger Code Review
- **New PRs** → Claude automatically reviews and posts inline comments
- **Existing PRs** → Comment `@claude` to trigger a review

### 3. Auto-Fix Issues  
Comment `@claude fix` and Claude will:
- Generate patches for identified issues
- Commit fixes directly to the PR branch
- Update you with a summary of changes

---

## 🚦 How It Works

### Automatic Review Triggers
```yaml
# Triggers Claude review on:
- New PR creation
- PR updates (new commits)
- Comment with "@claude" mention
```

### Review Focus Areas
- 🛡️ **Security**: SQL injection, auth issues, data exposure
- 🏗️ **Architecture**: Medallion lakehouse alignment
- 📊 **Supabase**: RLS policies, migration safety, performance
- 🔧 **Code Quality**: TypeScript, error handling, docs

### Example Review Output
```markdown
## 🤖 Claude Code CLI Review

### 🛡️ Security Analysis
- ✅ No obvious security vulnerabilities
- ⚠️  Verify input validation in API endpoints
- ✅ RLS policies properly configured

### 📋 Recommendations
1. Test migrations on staging first
2. Add integration tests for new endpoints
3. Update TypeScript types after schema changes

**APPROVE** - Ready to merge with suggestions addressed
```

---

## 💬 Commands

### Review Commands
```bash
# In PR comments:
@claude                    # Trigger full review
@claude review             # Same as above
@claude security           # Focus on security only
@claude architecture       # Focus on architecture only
```

### Fix Commands  
```bash
# In PR comments:
@claude fix               # Auto-fix all issues
@claude fix security      # Fix security issues only
@claude fix types         # Fix TypeScript issues only
```

---

## 🎯 Features

### ✅ What Claude Reviews
- Database migrations (safety, performance)
- Edge functions (security, error handling)  
- API endpoints (validation, auth)
- TypeScript code (types, best practices)
- Configuration files (security, consistency)

### ✅ What Claude Can Fix
- TypeScript type errors
- ESLint/Prettier violations
- Package.json dependency issues
- Basic security improvements
- Documentation updates

### ❌ What Claude Won't Do
- Make breaking changes without approval
- Modify core business logic
- Change database schemas destructively
- Override explicit design decisions

---

## 🔧 Configuration

### PR Review Labels
Claude automatically adds labels:
- `claude-reviewed` - Review completed
- `ready-for-merge` - Approved by Claude
- `needs-attention` - Issues found
- `security-review-needed` - Security concerns

### Review Thresholds
```yaml
Security Score: 8/10     # Minimum for auto-approval
Architecture: 9/10       # Must align with patterns  
Code Quality: 7/10       # Acceptable threshold
```

---

## 🚨 Emergency Commands

### Skip Claude Review
```bash
# Add to PR description:
[skip claude]

# Or use label:
skip-claude-review
```

### Force Re-Review
```bash
# Comment on PR:
@claude review --force

# Or remove and re-add label:
claude-reviewed
```

---

## 📊 Analytics

Claude tracks:
- Review completion time
- Fix success rate  
- Security issue detection
- False positive rate

View analytics in: `.github/workflows/claude-analytics.json`

---

## 🤔 FAQ

### Q: Can Claude review draft PRs?
**A:** Yes, but reviews are less strict for drafts.

### Q: What if Claude makes a mistake?
**A:** Revert the commit and comment `@claude explain` for clarification.

### Q: Can I customize review rules?
**A:** Yes, edit `.github/claude-config.yml` for custom rules.

### Q: Does Claude work with external contributors?
**A:** Yes, but fixes require maintainer approval.

---

## 🔒 Security & Privacy

- Claude only reviews code in public repos or with explicit permission
- No code is stored outside GitHub
- All reviews are logged for audit purposes
- Private repo support requires additional configuration

---

**Next**: Set up [Custom Review Rules](.github/claude-config.yml) for your team's specific requirements.