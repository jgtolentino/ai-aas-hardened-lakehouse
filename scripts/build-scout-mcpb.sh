#!/usr/bin/env bash
set -euo pipefail

# Build Script for Scout Analytics MCPB Package
# Creates a Desktop Extension (.mcpb) file for one-click installation in Claude Desktop

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BUNDLE_DIR="$ROOT_DIR/scout-mcpb-bundle"
OUTPUT_DIR="$ROOT_DIR/dist"
PACKAGE_NAME="scout-analytics-mcp.mcpb"

echo "🚀 Building Scout Analytics MCPB Package..."
echo "Bundle directory: $BUNDLE_DIR"
echo "Output directory: $OUTPUT_DIR"

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js is required but not installed"
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ Error: npm is required but not installed"
    exit 1
fi

if ! command -v zip &> /dev/null; then
    echo "❌ Error: zip command is required but not found"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Validate bundle directory
if [[ ! -d "$BUNDLE_DIR" ]]; then
    echo "❌ Error: Bundle directory not found at $BUNDLE_DIR"
    echo "Please run this script from the repository root"
    exit 1
fi

# Check required files
REQUIRED_FILES=(
    "$BUNDLE_DIR/manifest.json"
    "$BUNDLE_DIR/index.js"
    "$BUNDLE_DIR/package.json"
    "$BUNDLE_DIR/icon.png"
    "$BUNDLE_DIR/README.md"
)

echo "📁 Validating bundle files..."
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "❌ Error: Required file missing: $file"
        exit 1
    fi
    echo "✅ Found: $(basename "$file")"
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Install dependencies in bundle directory
echo "📦 Installing dependencies..."
cd "$BUNDLE_DIR"

if [[ -f "package-lock.json" ]]; then
    rm package-lock.json
fi

npm install --production --no-package-lock --silent

if [[ ! -d "node_modules" ]]; then
    echo "❌ Error: Failed to install dependencies"
    exit 1
fi

echo "✅ Dependencies installed successfully"

# Validate manifest.json
echo "🔍 Validating manifest.json..."
if ! node -e "JSON.parse(require('fs').readFileSync('manifest.json', 'utf8'))" 2>/dev/null; then
    echo "❌ Error: manifest.json is not valid JSON"
    exit 1
fi

# Check icon file
if [[ ! -f "icon.png" ]]; then
    echo "❌ Error: icon.png not found"
    exit 1
fi

# Get file size of icon (should be reasonable for embedding)
ICON_SIZE=$(stat -f%z "icon.png" 2>/dev/null || stat -c%s "icon.png" 2>/dev/null || echo "unknown")
if [[ "$ICON_SIZE" != "unknown" ]] && [[ "$ICON_SIZE" -gt 1048576 ]]; then
    echo "⚠️  Warning: Icon file is large (${ICON_SIZE} bytes). Consider optimizing."
fi

echo "✅ Manifest and icon validation passed"

# Create temporary directory for packaging
TEMP_DIR=$(mktemp -d)
trap "rm -rf '$TEMP_DIR'" EXIT

echo "📦 Preparing package contents..."

# Copy files to temp directory (excluding development files)
cp manifest.json "$TEMP_DIR/"
cp index.js "$TEMP_DIR/"
cp package.json "$TEMP_DIR/"
cp icon.png "$TEMP_DIR/"
cp README.md "$TEMP_DIR/"

# Copy node_modules
cp -r node_modules "$TEMP_DIR/"

# Remove unnecessary files from node_modules to reduce size
find "$TEMP_DIR/node_modules" -name "*.md" -delete 2>/dev/null || true
find "$TEMP_DIR/node_modules" -name "*.txt" -delete 2>/dev/null || true
find "$TEMP_DIR/node_modules" -name "LICENSE*" -delete 2>/dev/null || true
find "$TEMP_DIR/node_modules" -name "CHANGELOG*" -delete 2>/dev/null || true
find "$TEMP_DIR/node_modules" -name "test" -type d -exec rm -rf {} + 2>/dev/null || true
find "$TEMP_DIR/node_modules" -name "tests" -type d -exec rm -rf {} + 2>/dev/null || true
find "$TEMP_DIR/node_modules" -name "*.test.js" -delete 2>/dev/null || true

echo "✅ Package contents prepared"

# Create MCPB package (ZIP file with .mcpb extension)
echo "🔨 Creating MCPB package..."
cd "$TEMP_DIR"

# Create the .mcpb file
OUTPUT_FILE="$OUTPUT_DIR/$PACKAGE_NAME"
zip -r "$OUTPUT_FILE" . -q

if [[ ! -f "$OUTPUT_FILE" ]]; then
    echo "❌ Error: Failed to create MCPB package"
    exit 1
fi

# Get package size
PACKAGE_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "unknown")
PACKAGE_SIZE_MB=$(echo "scale=2; $PACKAGE_SIZE / 1024 / 1024" | bc 2>/dev/null || echo "unknown")

echo "✅ MCPB package created successfully!"
echo ""
echo "📊 Package Information:"
echo "   File: $OUTPUT_FILE"
echo "   Size: ${PACKAGE_SIZE_MB} MB"
echo ""
echo "🎯 Installation Instructions:"
echo "   1. Open Claude Desktop"
echo "   2. Go to Settings → Extensions"
echo "   3. Click 'Install from file'"
echo "   4. Select: $OUTPUT_FILE"
echo "   5. Enter your database credentials when prompted"
echo ""
echo "📚 Configuration Required:"
echo "   - SUPABASE_URL: Your Supabase project URL"
echo "   - SUPABASE_ANON_KEY: Your Supabase anonymous key"
echo ""
echo "🎉 Your Scout Analytics MCP extension is ready for distribution!"

# Return to original directory
cd "$ROOT_DIR"

# Verify package can be read
echo "🔍 Verifying package integrity..."
if unzip -t "$OUTPUT_FILE" >/dev/null 2>&1; then
    echo "✅ Package integrity verified"
else
    echo "❌ Warning: Package may be corrupted"
    exit 1
fi

echo ""
echo "🚀 Build completed successfully!"
echo "Package location: $OUTPUT_FILE"