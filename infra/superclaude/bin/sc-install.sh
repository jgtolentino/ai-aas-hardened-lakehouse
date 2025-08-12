#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
SC_DIR="$ROOT/infra/superclaude"

echo "[SuperClaude] Starting installation..."

# Create vendor directory
mkdir -p "$SC_DIR/vendor"

# Clone or update SuperClaude Framework
if [ ! -d "$SC_DIR/vendor/SuperClaude_Framework" ]; then
  echo "[SuperClaude] Cloning SuperClaude Framework v3..."
  git submodule add --force https://github.com/SuperClaude-Org/SuperClaude_Framework.git \
    "$SC_DIR/vendor/SuperClaude_Framework" || {
    echo "[ERROR] Failed to add submodule. Trying direct clone..."
    git clone https://github.com/SuperClaude-Org/SuperClaude_Framework.git \
      "$SC_DIR/vendor/SuperClaude_Framework"
  }
fi

# Checkout v3 branch
echo "[SuperClaude] Checking out v3 branch..."
git -C "$SC_DIR/vendor/SuperClaude_Framework" checkout SuperClaude-v3-Backup || {
  echo "[WARNING] v3 branch not found, trying v4 beta"
  git -C "$SC_DIR/vendor/SuperClaude_Framework" checkout SuperClaude_V4_Beta || {
    echo "[INFO] Using master branch"
    git -C "$SC_DIR/vendor/SuperClaude_Framework" checkout master
  }
}

# Run environment guard
echo "[SuperClaude] Running security guards..."
bash "$SC_DIR/guards/env_guard.sh"

# Create local config
echo "[SuperClaude] Creating local configuration..."
cat > "$SC_DIR/config.json" << 'EOF'
{
  "version": "3.0",
  "security": {
    "enforceGuards": true,
    "blockDirectExec": true,
    "auditMode": true
  },
  "integration": {
    "mode": "adapter",
    "executor": "bruno",
    "router": "pulser"
  }
}
EOF

echo "[OK] SuperClaude vendored and guarded successfully."
echo "[INFO] Next steps:"
echo "  1. Set CONTEXT7_API_KEY environment variable"
echo "  2. Run 'sc-validate.sh' to verify installation"
echo "  3. Configure Claude Code CLI with the adapter"