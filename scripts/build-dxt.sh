#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$HOME/ai-aas-hardened-lakehouse/scout-mcpb-bundle"
DIST_DIR="$HOME/ai-aas-hardened-lakehouse/dist"
cd "$BUNDLE_DIR"

echo "🚀 Building Scout Analytics DXT Package..."

# Sanity check required files
for f in manifest.json index.js package.json icon.png; do
  [ -f "$f" ] || { echo "❌ Missing $f in $BUNDLE_DIR"; exit 1; }
done
[ -d node_modules ] || { echo "❌ Missing node_modules (run npm i)"; exit 1; }

echo "✅ All required files present"

mkdir -p "$DIST_DIR"

# Build .dxt (zip)
OUT="$DIST_DIR/scout-analytics-mcp.dxt"
rm -f "$OUT"
zip -qr "$OUT" manifest.json index.js package.json icon.png node_modules

echo "✅ Built: $OUT"
echo "📊 Package size: $(ls -lh "$OUT" | awk '{print $5}')"
echo "🔐 SHA256: $(shasum -a 256 "$OUT" | cut -d' ' -f1)"

echo ""
echo "🎯 Installation Instructions:"
echo "   1. Open Claude Desktop"
echo "   2. Settings → Extensions → Install from file"
echo "   3. Select: $OUT"
echo "   4. Configure as needed (DATABASE_URL optional - uses keychain)"