#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# SECURITY: Install Pre-commit Hook for Secret Detection
# ============================================================

echo "🔒 Installing pre-commit hook for secret detection..."

# Create pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/usr/bin/env bash
set -e

echo "🔍 Scanning for secrets before commit..."

# Check for Supabase PAT tokens
if git diff --cached -U0 | grep -E 'sbp_[A-Za-z0-9]+' >/dev/null; then
  echo "❌ BLOCKED: Detected Supabase PAT token in staged changes" >&2
  echo "   Remove the token and use environment variables instead" >&2
  exit 1
fi

# Check for JWT tokens
if git diff --cached -U0 | grep -E 'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]*' >/dev/null; then
  echo "❌ BLOCKED: Detected JWT-like token in staged changes" >&2
  echo "   Remove the token and use environment variables instead" >&2
  exit 1
fi

# Check for service_role in code files (not docs)
if git diff --cached --name-only | grep -E '\.(js|ts|json|env)$' | xargs -I {} git diff --cached {} | grep -E 'service_role' >/dev/null; then
  echo "❌ BLOCKED: Detected service_role in staged code changes" >&2
  echo "   Use read-only database roles for MCP connections" >&2
  exit 1
fi

# Check for database passwords
if git diff --cached -U0 | grep -E 'password.*[:=].*[^"]{8,}' >/dev/null; then
  echo "❌ BLOCKED: Detected possible database password in staged changes" >&2
  exit 1
fi

echo "✅ No secrets detected - commit allowed"
EOF

# Make the hook executable
chmod +x .git/hooks/pre-commit

echo "✅ Pre-commit hook installed successfully"
echo ""
echo "The hook will now scan for:"
echo "• Supabase PAT tokens (sbp_*)"
echo "• JWT tokens (eyJ*.*.*)"
echo "• Service role references in code"
echo "• Database passwords"
echo ""
echo "To test: git add some_file && git commit -m 'test'"