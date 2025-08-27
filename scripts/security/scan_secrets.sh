#!/usr/bin/env bash
set -euo pipefail
command -v gitleaks >/dev/null || { echo "Install gitleaks"; exit 2; }
gitleaks detect -v -c .gitleaks.toml --no-banner
