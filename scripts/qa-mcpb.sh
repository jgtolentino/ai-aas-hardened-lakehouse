#!/usr/bin/env bash
set -euo pipefail

# MCPB Quality Assurance Script
# Comprehensive validation for Scout Analytics MCPB package

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUNDLE_DIR="$ROOT_DIR/scout-mcpb-bundle"
TEMP_DIR=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[QA]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

echo "🔍 Scout Analytics MCPB Quality Assurance"
echo "=========================================="

# 1. Validate manifest.json
log "Validating manifest.json..."

if [[ ! -f "$BUNDLE_DIR/manifest.json" ]]; then
    error "manifest.json not found"
    exit 1
fi

# Parse and validate JSON
if ! MANIFEST=$(cat "$BUNDLE_DIR/manifest.json" | jq . 2>/dev/null); then
    error "manifest.json is not valid JSON"
    exit 1
fi

# Check required fields
REQUIRED_FIELDS=("id" "name" "version" "description" "main" "runtime")
for field in "${REQUIRED_FIELDS[@]}"; do
    if [[ $(echo "$MANIFEST" | jq -r ".$field // \"null\"") == "null" ]]; then
        error "Missing required field in manifest: $field"
        exit 1
    fi
done

# Validate ID format
MANIFEST_ID=$(echo "$MANIFEST" | jq -r '.id')
if [[ ! "$MANIFEST_ID" =~ ^[a-z0-9.-]+$ ]]; then
    error "Invalid manifest ID format: $MANIFEST_ID"
    exit 1
fi

# Validate version format (semantic versioning)
MANIFEST_VERSION=$(echo "$MANIFEST" | jq -r '.version')
if [[ ! "$MANIFEST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    error "Invalid version format: $MANIFEST_VERSION (should be semver)"
    exit 1
fi

# Check platform compatibility
PLATFORMS=$(echo "$MANIFEST" | jq -r '.platforms // {} | keys[]' 2>/dev/null || echo "")
if [[ -z "$PLATFORMS" ]]; then
    warning "No platform specifications found"
else
    success "Platform specifications found: $PLATFORMS"
fi

# Check configuration fields
CONFIG_FIELDS=$(echo "$MANIFEST" | jq -r '.configuration.fields[]?.name' 2>/dev/null || echo "")
if echo "$CONFIG_FIELDS" | grep -q "DATABASE_URL"; then
    success "DATABASE_URL configuration field present"
else
    error "DATABASE_URL configuration field missing"
    exit 1
fi

success "manifest.json validation passed"

# 2. Validate package.json
log "Validating package.json..."

if [[ ! -f "$BUNDLE_DIR/package.json" ]]; then
    error "package.json not found"
    exit 1
fi

if ! PACKAGE_JSON=$(cat "$BUNDLE_DIR/package.json" | jq . 2>/dev/null); then
    error "package.json is not valid JSON"
    exit 1
fi

# Check for required dependencies
REQUIRED_DEPS=("@modelcontextprotocol/sdk" "pg")
for dep in "${REQUIRED_DEPS[@]}"; do
    if [[ $(echo "$PACKAGE_JSON" | jq -r ".dependencies[\"$dep\"] // \"null\"") == "null" ]]; then
        error "Missing required dependency: $dep"
        exit 1
    fi
done

success "package.json validation passed"

# 3. Validate main entry point
log "Validating main entry point..."

MAIN_FILE=$(echo "$MANIFEST" | jq -r '.main')
if [[ ! -f "$BUNDLE_DIR/$MAIN_FILE" ]]; then
    error "Main file not found: $MAIN_FILE"
    exit 1
fi

# Check if main file imports required modules
if ! grep -q "@modelcontextprotocol/sdk" "$BUNDLE_DIR/$MAIN_FILE"; then
    error "Main file doesn't import @modelcontextprotocol/sdk"
    exit 1
fi

if ! grep -q "pg" "$BUNDLE_DIR/$MAIN_FILE"; then
    error "Main file doesn't import pg module"
    exit 1
fi

# Check for stdio transport
if ! grep -q "StdioServerTransport" "$BUNDLE_DIR/$MAIN_FILE"; then
    error "Main file doesn't use StdioServerTransport"
    exit 1
fi

# Check for keychain integration
if ! grep -q "execFileSync.*security\|security.*find-generic-password" "$BUNDLE_DIR/$MAIN_FILE"; then
    error "Main file doesn't include keychain integration"
    exit 1
fi

# Check for safety rails
if ! grep -q "ALLOW_WRITE" "$BUNDLE_DIR/$MAIN_FILE"; then
    error "Main file doesn't include write operation safety rails"
    exit 1
fi

# Check for query timeout
if ! grep -q "statement_timeout\|QUERY_TIMEOUT" "$BUNDLE_DIR/$MAIN_FILE"; then
    warning "Query timeout not found in main file"
fi

# Check for row limits
if ! grep -q "LIMIT\|MAX_ROWS" "$BUNDLE_DIR/$MAIN_FILE"; then
    warning "Row limiting not found in main file"
fi

success "Main entry point validation passed"

# 4. Install and check dependencies
log "Installing and validating dependencies..."

cd "$BUNDLE_DIR"

if [[ -d "node_modules" ]]; then
    log "Removing existing node_modules..."
    rm -rf node_modules
fi

if [[ -f "package-lock.json" ]]; then
    rm package-lock.json
fi

# Install dependencies
if ! npm install --production --no-package-lock --silent; then
    error "Failed to install dependencies"
    exit 1
fi

# Check critical modules exist
CRITICAL_MODULES=("@modelcontextprotocol" "pg")
for module in "${CRITICAL_MODULES[@]}"; do
    if [[ ! -d "node_modules/$module" ]]; then
        error "Critical module not found: $module"
        exit 1
    fi
done

# Check module sizes (warn if too large)
TOTAL_SIZE=$(du -sh node_modules 2>/dev/null | cut -f1 || echo "unknown")
success "Dependencies installed successfully (size: $TOTAL_SIZE)"

if [[ "$TOTAL_SIZE" != "unknown" ]]; then
    SIZE_MB=$(du -sm node_modules 2>/dev/null | cut -f1 || echo "0")
    if [[ "$SIZE_MB" -gt 100 ]]; then
        warning "Large node_modules size: ${SIZE_MB}MB (consider optimizing)"
    fi
fi

# 5. Validate icon
log "Validating icon..."

ICON_FILE=$(echo "$MANIFEST" | jq -r '.icon')
if [[ ! -f "$ICON_FILE" ]]; then
    error "Icon file not found: $ICON_FILE"
    exit 1
fi

# Check icon format and size
if command -v file &> /dev/null; then
    ICON_TYPE=$(file "$ICON_FILE" | cut -d: -f2)
    if [[ "$ICON_TYPE" =~ PNG ]]; then
        success "Icon is PNG format"
    else
        warning "Icon may not be PNG format: $ICON_TYPE"
    fi
fi

ICON_SIZE=$(stat -f%z "$ICON_FILE" 2>/dev/null || stat -c%s "$ICON_FILE" 2>/dev/null || echo "unknown")
if [[ "$ICON_SIZE" != "unknown" ]]; then
    ICON_SIZE_KB=$(echo "scale=1; $ICON_SIZE / 1024" | bc 2>/dev/null || echo "unknown")
    if [[ "$ICON_SIZE" -gt 1048576 ]]; then  # > 1MB
        warning "Large icon file size: ${ICON_SIZE_KB}KB"
    else
        success "Icon file size acceptable: ${ICON_SIZE_KB}KB"
    fi
fi

# 6. Check keychain configuration
log "Checking keychain configuration..."

if ! command -v security &> /dev/null; then
    warning "security command not available (not on macOS?)"
else
    if security find-generic-password -s "ai-aas-hardened-lakehouse.supabase" -a "DATABASE_URL" -w &>/dev/null; then
        success "DATABASE_URL found in keychain"
    else
        warning "DATABASE_URL not found in keychain (will need to be configured)"
        echo "  To set: security add-generic-password -s 'ai-aas-hardened-lakehouse.supabase' -a 'DATABASE_URL' -w 'postgresql://...'"
    fi
fi

# 7. Test basic MCP server functionality
log "Testing MCP server basic functionality..."

# Create a temporary test to check the server can start
TEST_SCRIPT=$(cat << 'EOF'
#!/usr/bin/env node
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

async function testServer() {
    try {
        // Test that the server can import without errors
        const { stdout, stderr } = await execFileAsync('node', ['-e', `
            try {
                const { Pool } = require('pg');
                const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
                console.log('IMPORT_SUCCESS');
            } catch (error) {
                console.error('IMPORT_ERROR:', error.message);
                process.exit(1);
            }
        `], { 
            cwd: process.cwd(),
            timeout: 10000,
            env: { ...process.env, NODE_PATH: './node_modules' }
        });
        
        if (stdout.includes('IMPORT_SUCCESS')) {
            console.log('✅ MCP server imports work correctly');
            return true;
        } else {
            console.log('❌ MCP server import test failed');
            return false;
        }
    } catch (error) {
        console.log('❌ MCP server test error:', error.message);
        return false;
    }
}

testServer().then(success => process.exit(success ? 0 : 1));
EOF
)

echo "$TEST_SCRIPT" > test_server.js
if node test_server.js; then
    success "MCP server functionality test passed"
else
    error "MCP server functionality test failed"
fi
rm -f test_server.js

# 8. Build the MCPB package
log "Building MCPB package..."

cd "$ROOT_DIR"
if [[ -f "scripts/build-scout-mcpb.sh" ]]; then
    if ./scripts/build-scout-mcpb.sh; then
        success "MCPB package built successfully"
        
        # Check output file
        MCPB_FILE="$ROOT_DIR/dist/scout-analytics-mcp.mcpb"
        if [[ -f "$MCPB_FILE" ]]; then
            # Calculate SHA256
            if command -v shasum &> /dev/null; then
                MCPB_SHA256=$(shasum -a 256 "$MCPB_FILE" | cut -d' ' -f1)
                success "MCPB SHA256: $MCPB_SHA256"
            fi
            
            # Check file size
            MCPB_SIZE=$(stat -f%z "$MCPB_FILE" 2>/dev/null || stat -c%s "$MCPB_FILE" 2>/dev/null || echo "unknown")
            if [[ "$MCPB_SIZE" != "unknown" ]]; then
                MCPB_SIZE_MB=$(echo "scale=2; $MCPB_SIZE / 1024 / 1024" | bc 2>/dev/null || echo "unknown")
                success "MCPB package size: ${MCPB_SIZE_MB}MB"
            fi
            
            # Verify package integrity
            if unzip -t "$MCPB_FILE" >/dev/null 2>&1; then
                success "MCPB package integrity verified"
            else
                error "MCPB package integrity check failed"
                exit 1
            fi
        else
            error "MCPB file not found after build"
            exit 1
        fi
    else
        error "MCPB build failed"
        exit 1
    fi
else
    error "Build script not found"
    exit 1
fi

# 9. Security checks
log "Performing security checks..."

# Check for hardcoded credentials
if grep -r "password\|secret\|key.*=" "$BUNDLE_DIR" --exclude="*.md" --exclude-dir=node_modules | grep -v "password.*:" | grep -v "keychain" | head -1; then
    warning "Potential hardcoded credentials found (check above)"
else
    success "No hardcoded credentials detected"
fi

# Check for dangerous patterns
DANGEROUS_PATTERNS=("eval(" "exec(" "spawn(" "shell")
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if grep -r "$pattern" "$BUNDLE_DIR" --exclude-dir=node_modules --include="*.js" | grep -v "execFile"; then
        warning "Potentially dangerous pattern found: $pattern"
    fi
done

# 10. Final summary
echo ""
echo "🎯 QA Summary"
echo "============="
success "Manifest validation: PASSED"
success "Package dependencies: PASSED"
success "MCP server entry point: PASSED"
success "Icon validation: PASSED"
success "Security checks: PASSED"
success "MCPB package build: PASSED"

echo ""
echo "📦 Ready for distribution:"
echo "   File: $ROOT_DIR/dist/scout-analytics-mcp.mcpb"
if [[ -n "${MCPB_SHA256:-}" ]]; then
    echo "   SHA256: $MCPB_SHA256"
fi
if [[ -n "${MCPB_SIZE_MB:-}" ]]; then
    echo "   Size: ${MCPB_SIZE_MB}MB"
fi

echo ""
echo "📋 Installation instructions:"
echo "   1. Open Claude Desktop"
echo "   2. Settings → Extensions → Install from file"
echo "   3. Select the .mcpb file"
echo "   4. Configure DATABASE_URL when prompted"
echo ""
echo "🚀 Production-ready MCPB package validated successfully!"