#!/bin/bash
# Scout UI Backlog Sweep - Automated Feature Discovery
# Usage: ./sweep_command.sh
# Purpose: Find candidate features across monorepo for Scout Dashboard backlog

set -e

echo "🔍 Starting Scout UI backlog sweep..."
echo "======================================"

# Create output directory
mkdir -p .backlog_sweep

# 1) Search for components that might contain useful features
echo "📦 Searching for component candidates..."
find apps packages modules infra supabase scripts -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" 2>/dev/null \
  | grep -v node_modules \
  | grep -v .next \
  | grep -v dist \
  | grep -v build \
  | xargs grep -l -E 'forecast|predict|dashboard|chart|analytics|export|alert|schedule|insight|template' 2>/dev/null \
  > .backlog_sweep/component_candidates.txt || echo "No component candidates found"

# 2) Search for TODO/backlog annotations and feature flags
echo "🏷️  Searching for backlog annotations..."
grep -r -n --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.md" \
  --exclude-dir="node_modules" --exclude-dir=".next" --exclude-dir="dist" --exclude-dir="build" \
  -E 'TODO|FIXME|@backlog|@feature|feature:|FEATURE_FLAG|flag:' \
  apps/ packages/ modules/ infra/ supabase/ scripts/ 2>/dev/null \
  | sed 's/^/HIT: /' > .backlog_sweep/raw_hits.txt || echo "HIT: No annotation hits found" > .backlog_sweep/raw_hits.txt

# 3) Search for specific Scout-related features
echo "🎯 Searching for Scout-specific features..."
grep -r -n --include="*.ts" --include="*.tsx" --exclude-dir="node_modules" \
  -E 'scout_|Scout|SCOUT|forecast|predict|cohort|hexbin|ab.*test|insight.*template' \
  apps/ packages/ 2>/dev/null \
  | sed 's/^/SCOUT: /' >> .backlog_sweep/raw_hits.txt || true

# 4) Summarize by path
echo "📊 Generating summary..."
cut -d: -f1 .backlog_sweep/raw_hits.txt | sort | uniq -c | sort -nr > .backlog_sweep/by_path.txt

# 5) Component export analysis
echo "🔍 Analyzing component exports..."
grep -r -n --include="*.ts" --include="*.tsx" --exclude-dir="node_modules" \
  'export.*function.*Chart\|export.*function.*Dashboard\|export.*function.*Analytics\|export.*function.*Export' \
  apps/ packages/ 2>/dev/null \
  | sed 's/^/EXPORT: /' > .backlog_sweep/exports.txt || echo "EXPORT: No relevant exports found" > .backlog_sweep/exports.txt

# 6) Edge function discovery
echo "⚡ Discovering edge functions..."
if [ -d "supabase/functions" ]; then
  find supabase/functions -name "index.ts" -exec dirname {} \; \
    | sed 's|supabase/functions/||' \
    | sort > .backlog_sweep/edge_functions.txt
  
  # Analyze edge function capabilities
  echo "🔧 Analyzing edge function capabilities..." 
  for func in $(cat .backlog_sweep/edge_functions.txt); do
    func_path="supabase/functions/$func/index.ts"
    if [ -f "$func_path" ]; then
      # Extract key info: serve handler, RPC calls, API endpoints
      echo "EDGE_FUNC: $func" >> .backlog_sweep/edge_analysis.txt
      grep -n -E 'serve\(|Deno\.serve|\.rpc\(' "$func_path" | head -n 3 | sed "s/^/  $func: /" >> .backlog_sweep/edge_analysis.txt || true
    fi
  done
else
  echo "EDGE_FUNC: No supabase/functions directory found" > .backlog_sweep/edge_functions.txt
  echo "EDGE_ANALYSIS: Supabase functions not available" > .backlog_sweep/edge_analysis.txt
fi

# 7) Display results
echo ""
echo "📋 RESULTS SUMMARY"
echo "=================="
echo "📦 Component candidates: $(wc -l < .backlog_sweep/component_candidates.txt | tr -d ' ')"
echo "🏷️  Annotation hits: $(wc -l < .backlog_sweep/raw_hits.txt | tr -d ' ')"
echo "📤 Component exports: $(wc -l < .backlog_sweep/exports.txt | tr -d ' ')"
echo "⚡ Edge functions found: $(wc -l < .backlog_sweep/edge_functions.txt | tr -d ' ')"

echo ""
echo "🏆 TOP PATHS (by hit count):"
head -n 15 .backlog_sweep/by_path.txt

echo ""
echo "🔍 SAMPLE CANDIDATE COMPONENTS:"
head -n 10 .backlog_sweep/component_candidates.txt

echo ""
echo "🏷️  SAMPLE ANNOTATION HITS:"
head -n 10 .backlog_sweep/raw_hits.txt

echo ""
echo "⚡ EDGE FUNCTIONS DISCOVERED:"
cat .backlog_sweep/edge_functions.txt

echo ""
echo "✅ Sweep complete! Artifacts saved in .backlog_sweep/"
echo "📋 Next steps:"
echo "   1. Review candidates in .backlog_sweep/component_candidates.txt"
echo "   2. Check hits in .backlog_sweep/raw_hits.txt"
echo "   3. Review edge functions in .backlog_sweep/edge_functions.txt"
echo "   4. Check edge function analysis in .backlog_sweep/edge_analysis.txt"
echo "   5. Update docs/PRD/backlog/SCOUT_UI_BACKLOG.yml with new items"
echo "   6. Run: yq '.backlog_items[] | .id + \": \" + .title' docs/PRD/backlog/SCOUT_UI_BACKLOG.yml"
echo "   7. See .backlog_sweep/edge-function-integration-map.md for UI integration details"