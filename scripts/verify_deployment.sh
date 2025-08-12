#!/usr/bin/env bash
set -euo pipefail

# Scout Analytics Platform - Deployment Verification Script
# This script verifies the deployment status of the Scout Analytics Platform

echo "🔍 Verifying Scout Analytics Platform Deployment..."

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize status
VERIFICATION_PASSED=true

# Function to check command availability
check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✅ $1 is installed${NC}"
    else
        echo -e "${RED}❌ $1 is not installed${NC}"
        VERIFICATION_PASSED=false
    fi
}

# Function to check file existence
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✅ File exists: $1${NC}"
    else
        echo -e "${RED}❌ File missing: $1${NC}"
        VERIFICATION_PASSED=false
    fi
}

# Function to check directory existence
check_directory() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✅ Directory exists: $1${NC}"
    else
        echo -e "${RED}❌ Directory missing: $1${NC}"
        VERIFICATION_PASSED=false
    fi
}

echo ""
echo "📋 Checking Prerequisites..."
check_command node
check_command npm
check_command git

echo ""
echo "📂 Checking Project Structure..."
check_directory "scripts"
check_directory "docs-site"
check_directory "platform"
check_directory "supabase"

echo ""
echo "📄 Checking Critical Files..."
check_file "package.json"
check_file "README.md"
check_file "Makefile"
check_file ".github/workflows/ci.yml"

echo ""
echo "🧩 Checking Documentation Components..."
if [ -d "docs-site" ]; then
    check_file "docs-site/package.json"
    check_file "docs-site/docusaurus.config.js"
    check_directory "docs-site/docs"
    check_directory "docs-site/static"
fi

echo ""
echo "🔧 Checking Scripts..."
check_file "scripts/generate-agent-docs.mjs"
check_file "scripts/icons-build.mjs"
check_file "scripts/archspec-to-mermaid.mjs"
check_file "scripts/wiki-sync.sh"
check_file "scripts/fix-doc-image-paths.js"
check_file "scripts/docs-preflight.js"

echo ""
echo "🗃️ Checking Database Migrations..."
if [ -d "platform/scout/migrations" ]; then
    MIGRATION_COUNT=$(find platform/scout/migrations -name "*.sql" | wc -l)
    echo -e "${GREEN}✅ Found $MIGRATION_COUNT migration files${NC}"
else
    echo -e "${YELLOW}⚠️  Migrations directory not found${NC}"
fi

echo ""
echo "🌐 Checking Supabase Configuration..."
if [ -f "supabase/.env" ] || [ -f "supabase/.env.example" ]; then
    echo -e "${GREEN}✅ Supabase configuration found${NC}"
else
    echo -e "${YELLOW}⚠️  Supabase configuration not found${NC}"
fi

echo ""
echo "📊 Checking Node Dependencies..."
if [ -f "package-lock.json" ] || [ -f "pnpm-lock.yaml" ] || [ -f "yarn.lock" ]; then
    echo -e "${GREEN}✅ Lock file present${NC}"
else
    echo -e "${YELLOW}⚠️  No lock file found - run npm/pnpm/yarn install${NC}"
fi

echo ""
echo "========================================="
if [ "$VERIFICATION_PASSED" = true ]; then
    echo -e "${GREEN}✅ DEPLOYMENT VERIFICATION PASSED${NC}"
    echo "The Scout Analytics Platform appears to be properly configured."
    exit 0
else
    echo -e "${RED}❌ DEPLOYMENT VERIFICATION FAILED${NC}"
    echo "Please address the issues above before deploying."
    exit 1
fi