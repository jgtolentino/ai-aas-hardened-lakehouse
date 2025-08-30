#!/usr/bin/env python3
"""
Load all 347 SKUs from CSV into Supabase SKU Master Dimension Table
"""

import csv
import json
from datetime import datetime
import os

def get_persona_affinities(category, brand, price):
    """Determine persona affinities based on category/brand/price"""
    affinities = {
        'juan': 0.25,
        'maria': 0.25,
        'carlo': 0.25,
        'lola': 0.25
    }
    
    cat = (category or '').lower()
    
    if 'cigarette' in cat or 'tobacco' in cat:
        affinities['juan'] = 0.55
        affinities['carlo'] = 0.35
        affinities['maria'] = 0.05
        affinities['lola'] = 0.05
    elif 'milk' in cat or 'dairy' in cat:
        affinities['maria'] = 0.50
        affinities['lola'] = 0.20
        affinities['juan'] = 0.15
        affinities['carlo'] = 0.15
    elif 'detergent' in cat or 'soap' in cat or 'cleaning' in cat:
        affinities['maria'] = 0.65
        affinities['lola'] = 0.15
        affinities['juan'] = 0.10
        affinities['carlo'] = 0.10
    elif 'telco' in cat or 'load' in cat or 'data' in cat:
        affinities['carlo'] = 0.40
        affinities['juan'] = 0.35
        affinities['maria'] = 0.20
        affinities['lola'] = 0.05
    elif 'snack' in cat or 'chips' in cat:
        affinities['carlo'] = 0.45
        affinities['maria'] = 0.25
        affinities['juan'] = 0.20
        affinities['lola'] = 0.10
    elif 'biscuit' in cat or 'cookie' in cat:
        affinities['lola'] = 0.40
        affinities['maria'] = 0.30
        affinities['carlo'] = 0.20
        affinities['juan'] = 0.10
    elif 'canned' in cat or 'sardine' in cat:
        affinities['maria'] = 0.45
        affinities['juan'] = 0.30
        affinities['carlo'] = 0.15
        affinities['lola'] = 0.10
    elif 'noodle' in cat or 'instant' in cat:
        affinities['juan'] = 0.50
        affinities['maria'] = 0.25
        affinities['carlo'] = 0.15
        affinities['lola'] = 0.10
    elif 'beverage' in cat or 'drink' in cat or 'juice' in cat:
        affinities['carlo'] = 0.35
        affinities['maria'] = 0.30
        affinities['juan'] = 0.25
        affinities['lola'] = 0.10
    elif 'coffee' in cat:
        affinities['juan'] = 0.35
        affinities['carlo'] = 0.35
        affinities['maria'] = 0.20
        affinities['lola'] = 0.10
    
    return affinities

def get_time_affinities(category):
    """Determine time affinities based on category"""
    affinities = {
        'morning': 0.25,
        'afternoon': 0.25,
        'evening': 0.25,
        'night': 0.25
    }
    
    cat = (category or '').lower()
    
    if 'coffee' in cat or 'milk' in cat or 'bread' in cat:
        affinities['morning'] = 0.60
        affinities['afternoon'] = 0.20
        affinities['evening'] = 0.10
        affinities['night'] = 0.10
    elif 'cigarette' in cat or 'tobacco' in cat:
        affinities['morning'] = 0.20
        affinities['afternoon'] = 0.35
        affinities['evening'] = 0.25
        affinities['night'] = 0.20
    elif 'snack' in cat or 'chips' in cat or 'biscuit' in cat:
        affinities['morning'] = 0.10
        affinities['afternoon'] = 0.45
        affinities['evening'] = 0.25
        affinities['night'] = 0.20
    elif 'detergent' in cat or 'soap' in cat:
        affinities['morning'] = 0.35
        affinities['afternoon'] = 0.15
        affinities['evening'] = 0.40
        affinities['night'] = 0.10
    elif 'telco' in cat or 'load' in cat:
        affinities['morning'] = 0.15
        affinities['afternoon'] = 0.25
        affinities['evening'] = 0.25
        affinities['night'] = 0.35
    elif 'canned' in cat or 'noodle' in cat:
        affinities['morning'] = 0.15
        affinities['afternoon'] = 0.20
        affinities['evening'] = 0.50
        affinities['night'] = 0.15
    
    return affinities

def generate_sql_insert(skus):
    """Generate SQL INSERT statement for batch of SKUs"""
    values = []
    
    for i, sku in enumerate(skus):
        category = sku.get('category_name', 'General')
        brand = sku.get('brand_name', 'Generic')
        price = float(sku.get('list_price', 0) or 0)
        
        persona_affinities = get_persona_affinities(category, brand, price)
        time_affinities = get_time_affinities(category)
        
        # Generate velocity rank based on category/price
        import random
        base_velocity = 50
        if 'cigarette' in category.lower():
            base_velocity = random.randint(70, 95)
        elif 'telco' in category.lower():
            base_velocity = random.randint(60, 85)
        elif 'milk' in category.lower() or 'coffee' in category.lower():
            base_velocity = random.randint(80, 95)
        elif 'snack' in category.lower():
            base_velocity = random.randint(65, 85)
        else:
            base_velocity = random.randint(40, 70)
        
        value = f"""(
    '{sku.get('sku', f'SKU-{i+1}').replace("'", "''")}',
    '{sku.get('product_name', 'Unknown').replace("'", "''")}',
    '{str(sku.get('brand_id', '')).replace("'", "''")}',
    '{brand.replace("'", "''")}',
    '{str(sku.get('category_id', '')).replace("'", "''")}',
    '{category.replace("'", "''")}',
    '{sku.get('pack_size', '').replace("'", "''")}',
    '{sku.get('unit_type', 'piece').replace("'", "''")}',
    {price},
    '{sku.get('barcode', 'UNKNOWN').replace("'", "''")}',
    '{sku.get('manufacturer', '').replace("'", "''")}',
    {str(sku.get('is_active', 'true')).lower() == 'true'},
    '{sku.get('halal_certified', 'unknown').replace("'", "''")}',
    '{sku.get('product_description', '').replace("'", "''")}',
    '{sku.get('price_source', 'Market estimate').replace("'", "''")}',
    {persona_affinities['juan']:.2f},
    {persona_affinities['maria']:.2f},
    {persona_affinities['carlo']:.2f},
    {persona_affinities['lola']:.2f},
    {time_affinities['morning']:.2f},
    {time_affinities['afternoon']:.2f},
    {time_affinities['evening']:.2f},
    {time_affinities['night']:.2f},
    {base_velocity},
    '{category.lower().replace(" ", "_").replace("'", "''")}'
)"""
        values.append(value)
    
    sql = f"""INSERT INTO scout.sku_master (
    sku, product_name, brand_id, brand_name, category_id, category_name,
    pack_size, unit_type, list_price, barcode, manufacturer, is_active,
    halal_certified, product_description, price_source,
    juan_affinity, maria_affinity, carlo_affinity, lola_affinity,
    morning_affinity, afternoon_affinity, evening_affinity, night_affinity,
    velocity_rank, substitution_group
) VALUES 
{','.join(values)}
ON CONFLICT (sku) DO UPDATE SET
    product_name = EXCLUDED.product_name,
    brand_name = EXCLUDED.brand_name,
    category_name = EXCLUDED.category_name,
    list_price = EXCLUDED.list_price,
    is_active = EXCLUDED.is_active,
    juan_affinity = EXCLUDED.juan_affinity,
    maria_affinity = EXCLUDED.maria_affinity,
    carlo_affinity = EXCLUDED.carlo_affinity,
    lola_affinity = EXCLUDED.lola_affinity,
    morning_affinity = EXCLUDED.morning_affinity,
    afternoon_affinity = EXCLUDED.afternoon_affinity,
    evening_affinity = EXCLUDED.evening_affinity,
    night_affinity = EXCLUDED.night_affinity,
    velocity_rank = EXCLUDED.velocity_rank,
    updated_at = CURRENT_TIMESTAMP;"""
    
    return sql

def main():
    """Main function to load SKUs"""
    csv_path = '/Users/tbwa/Downloads/sku_catalog_with_telco_filled.csv'
    
    # Read CSV
    skus = []
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        skus = list(reader)
    
    print(f"Loaded {len(skus)} SKUs from CSV")
    
    # Generate SQL in batches of 50
    batch_size = 50
    sql_files = []
    
    for i in range(0, len(skus), batch_size):
        batch = skus[i:i+batch_size]
        sql = generate_sql_insert(batch)
        
        # Save to file
        filename = f'/Users/tbwa/ai-aas-hardened-lakehouse/migrations/load_skus_batch_{i//batch_size + 1}.sql'
        with open(filename, 'w') as f:
            f.write(sql)
        sql_files.append(filename)
        print(f"Generated SQL batch {i//batch_size + 1}: {len(batch)} SKUs")
    
    # Generate summary
    categories = {}
    brands = {}
    
    for sku in skus:
        cat = sku.get('category_name', 'Unknown')
        brand = sku.get('brand_name', 'Unknown')
        
        if cat not in categories:
            categories[cat] = 0
        categories[cat] += 1
        
        if brand not in brands:
            brands[brand] = 0
        brands[brand] += 1
    
    print(f"\n📊 Summary:")
    print(f"Total SKUs: {len(skus)}")
    print(f"Categories: {len(categories)}")
    print(f"Brands: {len(brands)}")
    print(f"SQL Files Generated: {len(sql_files)}")
    
    print(f"\nTop 10 Categories:")
    for cat, count in sorted(categories.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f"  {cat}: {count} SKUs")
    
    print(f"\nTop 10 Brands:")
    for brand, count in sorted(brands.items(), key=lambda x: x[1], reverse=True)[:10]:
        print(f"  {brand}: {count} SKUs")
    
    print(f"\n✅ SQL files ready for execution in migrations folder")
    print(f"Run each file through Supabase to load all SKUs")

if __name__ == '__main__':
    import random
    random.seed(42)  # For consistent velocity ranks
    main()
