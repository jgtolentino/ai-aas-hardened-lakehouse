#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "figma:stub" ]; then
  COMP="${2:?Component name (e.g., KpiTile)}"
  DEST="apps/scout-ui/src/components/${COMP}/${COMP}.figma.tsx"
  mkdir -p "$(dirname "$DEST")"
  cat > "$DEST" <<'TSX'
import { connect, figma } from "@figma/code-connect";
import { COMPONENT } from "./COMPONENT";

// TODO: set your real file key and node id from Dev Mode (right sidebar → "Copy link")
// Example link: https://www.figma.com/file/<FILE_KEY>/<name>?node-id=<NODE_ID>
const FILE_KEY = "<YOUR_FIGMA_FILE_KEY>";
const NODE_ID  = "<YOUR_NODE_ID>"; // e.g. "12:345"

export default connect(COMPONENT, figma.component(FILE_KEY, NODE_ID), {
  // Map Figma layer properties or tokens to props
  props: {
    /* TODO: map figma controls → props */
  },

  example: {
    /* TODO: default props */
  },

  variants: [
    /* TODO: add component variants */
  ],
});
TSX
  
  # Replace placeholders with actual component name
  if command -v sed >/dev/null 2>&1; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      # macOS sed
      sed -i '' "s/COMPONENT/$COMP/g" "$DEST"
    else
      # GNU sed
      sed -i "s/COMPONENT/$COMP/g" "$DEST"
    fi
  else
    # Fallback using basic text replacement
    perl -i -pe "s/COMPONENT/$COMP/g" "$DEST" 2>/dev/null || {
      echo "Warning: Could not replace placeholders automatically"
      echo "Please manually replace 'COMPONENT' with '$COMP' in $DEST"
    }
  fi
  
  echo "✅ Figma Code Connect stub created at $DEST"
  echo "📝 Next steps:"
  echo "   1. Open Figma in Dev Mode"
  echo "   2. Navigate to your component"
  echo "   3. Copy the component link from right sidebar"
  echo "   4. Update FILE_KEY and NODE_ID in $DEST"
  echo "   5. Map Figma properties to component props"
else
  echo "Usage: superclaude.sh figma:stub <ComponentName>"
  echo ""
  echo "Example: superclaude.sh figma:stub KpiTile"
  echo ""
  echo "This creates a Code Connect mapping stub for the specified component"
  exit 2
fi