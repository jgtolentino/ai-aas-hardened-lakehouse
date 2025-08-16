#!/bin/bash
# Scout Edge: Export Brand Catalog for Edge Devices

# Check environment
if [ -z "$POSTGRES_URL" ]; then
    echo "Error: POSTGRES_URL not set"
    exit 1
fi

# Export canonical brand catalog as CSV
echo "Exporting brand catalog..."
psql "$POSTGRES_URL" -A -F',' -q -t <<SQL > /tmp/brand_catalog.csv
select 
  brand as keyword,
  brand as brand_name,
  coalesce(
    (select min(category) 
     from suqi.ph_brand_catalog c 
     where scout.norm_brand(c.brand_name) = u.brand),
    (select min(category)
     from scout.stt_brand_dictionary s
     where scout.norm_brand(s.brand) = u.brand),
    'Unknown'
  ) as category,
  0.90 as confidence
from scout.v_brand_universe u
where brand is not null
order by brand;
SQL

# Add header
echo "keyword,brand_name,category,confidence" > /tmp/brand_catalog_with_header.csv
cat /tmp/brand_catalog.csv >> /tmp/brand_catalog_with_header.csv
mv /tmp/brand_catalog_with_header.csv /tmp/brand_catalog.csv

# Export variant mappings as JSON
echo "Exporting variant mappings..."
psql "$POSTGRES_URL" -A -t <<SQL > /tmp/brand_variants.json
select json_agg(
  json_build_object(
    'brand', brand,
    'variants', variants
  )
)
from (
  select 
    brand,
    array_agg(distinct variant_raw order by variant_raw) as variants
  from scout.v_variant_index
  where variant_raw is not null
  group by brand
) x;
SQL

# Summary
echo "Export complete!"
echo "Files created:"
echo "  - /tmp/brand_catalog.csv ($(wc -l < /tmp/brand_catalog.csv) brands)"
echo "  - /tmp/brand_variants.json"
echo ""
echo "To deploy to Pi:"
echo "  scp /tmp/brand_catalog.csv pi@192.168.1.44:/opt/scout-edge/app/dictionaries/"
echo "  scp /tmp/brand_variants.json pi@192.168.1.44:/opt/scout-edge/app/dictionaries/"