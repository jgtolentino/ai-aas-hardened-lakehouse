#!/bin/bash

# Script to identify unique migrations in ai-aas-hardened-lakehouse that should be copied to scout-databank-new

SCOUT_NEW="/Users/tbwa/Documents/GitHub/scout-databank-new"
AI_AAS="/Users/tbwa/Documents/GitHub/ai-aas-hardened-lakehouse"

echo "=== Unique Migrations in ai-aas-hardened-lakehouse ==="
echo ""

# Check db/migrations for unique files
echo "Checking db/migrations for unique files..."
for file in "$AI_AAS/db/migrations"/*.sql; do
    filename=$(basename "$file")
    if [[ ! -f "$SCOUT_NEW/ai-aas-hardened-lakehouse/db/migrations/$filename" ]]; then
        echo "Unique in ai-aas: $filename"
        
        # These are the critical ones we identified
        case "$filename" in
            "026_brand_detection_schema.sql"|"110_geo_boundaries.sql"|"111_srp_catalog.sql"|"112_resolvers.sql"|"120_ml_monitoring.sql"|"121_tx_confidence.sql")
                echo "  -> CRITICAL: Should be copied to scout-databank-new"
                # Uncomment to actually copy:
                # cp "$file" "$SCOUT_NEW/ai-aas-hardened-lakehouse/db/migrations/"
                ;;
        esac
    fi
done

echo ""
echo "=== Migration Locations Summary ==="
echo ""
echo "scout-databank-new migration locations:"
echo "  - $SCOUT_NEW/supabase/migrations/"
echo "  - $SCOUT_NEW/ai-aas-hardened-lakehouse/supabase/migrations/"
echo "  - $SCOUT_NEW/ai-aas-hardened-lakehouse/db/migrations/"
echo ""
echo "ai-aas-hardened-lakehouse migration locations:"
echo "  - $AI_AAS/supabase/migrations/"
echo "  - $AI_AAS/db/migrations/"
echo "  - $AI_AAS/platform/scout/blueprint-dashboard/supabase/migrations/"
echo "  - $AI_AAS/platform/scout/scout-databank/supabase/migrations/"

echo ""
echo "=== Recommendations ==="
echo "1. All scout-specific migrations should be in a consistent location"
echo "2. Use date-based naming convention (YYYYMMDD_description.sql)"
echo "3. Remove duplicate migrations"
echo "4. Document which migrations have been applied to production"