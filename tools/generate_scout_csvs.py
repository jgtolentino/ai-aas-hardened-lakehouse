#!/usr/bin/env python3
"""
Generate Scout Analytics CSV files with TBWA client data
Includes all 17 Philippine regions with realistic barangay coverage
Market share: TBWA FMCG ~20%, JTI Tobacco ~39%
"""

import uuid
import random
import csv
import os
from datetime import datetime, timedelta
import numpy as np
from pathlib import Path

# Set seeds for reproducibility
random.seed(42)
np.random.seed(42)

# Output directory
outdir = Path("scout_seed_data")
outdir.mkdir(exist_ok=True)

# -----------------------------
# 1) Regions & Barangays
# -----------------------------
regions = [
    (1, "Ilocos Region (Region I)"),
    (2, "Cagayan Valley (Region II)"),
    (3, "Central Luzon (Region III)"),
    (4, "CALABARZON (Region IV-A)"),
    (5, "MIMAROPA (Region IV-B)"),
    (6, "Bicol Region (Region V)"),
    (7, "Western Visayas (Region VI)"),
    (8, "Central Visayas (Region VII)"),
    (9, "Eastern Visayas (Region VIII)"),
    (10, "Zamboanga Peninsula (Region IX)"),
    (11, "Northern Mindanao (Region X)"),
    (12, "Davao Region (Region XI)"),
    (13, "SOCCSKSARGEN (Region XII)"),
    (14, "Caraga (Region XIII)"),
    (15, "NCR (Metro Manila)"),
    (16, "Cordillera Administrative Region (CAR)"),
    (17, "BARMM"),
]

# Common barangay names
barangay_pool = [
    "Poblacion", "San Isidro", "San Jose", "San Roque", "San Antonio", "San Pedro",
    "Santa Cruz", "Santa Maria", "Santa Rosa", "Santo Niño", "Santo Tomas", "Bagong Silang",
    "Bagumbayan", "Bayanihan", "Mabini", "Rizal", "Del Pilar", "San Nicolas",
    "Maligaya", "Bagong Pag-asa", "Masagana", "Malabanias", "Pulang Lupa", "Santo Cristo"
]

# Cities per region
region_city_map = {
    15: ["Quezon City", "Manila", "Makati", "Taguig", "Caloocan", "Pasig", "Mandaluyong"],
    4: ["Antipolo", "Bacoor", "Dasmariñas", "Calamba", "San Pedro", "Lipa"],
    3: ["San Fernando", "Angeles", "Olongapo", "Malolos"],
    7: ["Iloilo City", "Bacolod City", "Roxas City"],
    8: ["Cebu City", "Mandaue", "Lapu-Lapu"],
    12: ["Davao City", "Tagum", "Digos"],
    11: ["Cagayan de Oro", "Iligan", "Valencia"],
    1: ["Laoag", "Vigan", "San Fernando (La Union)"],
    2: ["Tuguegarao", "Cauayan", "Santiago"],
    5: ["Puerto Princesa", "Calapan", "Odiongan"],
    6: ["Legazpi", "Naga", "Sorsogon City"],
    9: ["Tacloban", "Ormoc", "Borongan"],
    10: ["Zamboanga City", "Dipolog", "Pagadian"],
    13: ["General Santos", "Koronadal", "Tacurong"],
    14: ["Butuan", "Surigao", "Bislig"],
    16: ["Baguio", "La Trinidad", "Bontoc"],
    17: ["Cotabato City", "Marawi", "Jolo"],
}

# Build geography and stores
rows_geo = []
store_rows = []
store_id_seq = 1001

for reg_id, reg_name in regions:
    cities = region_city_map.get(reg_id, [f"City-{reg_id}-A", f"City-{reg_id}-B"])
    for city in cities:
        # Generate 8-15 barangays per city
        bcount = np.random.randint(8, 16)
        brgys = np.random.choice(barangay_pool, size=bcount, replace=True)
        for bname in brgys:
            rows_geo.append({
                "region_id": reg_id,
                "region_name": reg_name,
                "city": city,
                "barangay": bname
            })
            # Spawn 1-3 sari-sari stores per barangay
            for _ in range(np.random.randint(1, 4)):
                store_rows.append({
                    "store_id": store_id_seq,
                    "store_name": f"{bname} Sari-Sari #{store_id_seq % 1000:03d}",
                    "region_id": reg_id,
                    "region_name": reg_name,
                    "city": city,
                    "barangay": bname
                })
                store_id_seq += 1

# Save geography.csv
with open(outdir / "geography.csv", 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=["region_id", "region_name", "city", "barangay"])
    writer.writeheader()
    writer.writerows(rows_geo)

# Save stores.csv
with open(outdir / "stores.csv", 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=["store_id", "store_name", "region_id", "region_name", "city", "barangay"])
    writer.writeheader()
    writer.writerows(store_rows)

# -----------------------------
# 2) Categories, Brands, SKUs
# -----------------------------
categories = [
    {"category_id": 1, "category_name": "Dairy & Beverages"},
    {"category_id": 2, "category_name": "Snacks & Beverages"},
    {"category_id": 3, "category_name": "Oils & Margarine"},
    {"category_id": 4, "category_name": "Canned Goods & Sauces"},
    {"category_id": 5, "category_name": "Tobacco"},
]

# Save categories.csv
with open(outdir / "categories.csv", 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=["category_id", "category_name"])
    writer.writeheader()
    writer.writerows(categories)

# Brands (TBWA + Competitors)
brands = [
    # TBWA Clients
    {"brand_id": 1, "brand_name": "Alaska", "category_id": 1, "is_tbwa_client": True},
    {"brand_id": 2, "brand_name": "Oishi", "category_id": 2, "is_tbwa_client": True},
    {"brand_id": 3, "brand_name": "Marca Leon", "category_id": 3, "is_tbwa_client": True},
    {"brand_id": 4, "brand_name": "Del Monte", "category_id": 4, "is_tbwa_client": True},
    {"brand_id": 5, "brand_name": "JTI", "category_id": 5, "is_tbwa_client": True},
    # Competitors
    {"brand_id": 6, "brand_name": "Bear Brand", "category_id": 1, "is_tbwa_client": False},
    {"brand_id": 7, "brand_name": "Nido", "category_id": 1, "is_tbwa_client": False},
    {"brand_id": 8, "brand_name": "Piattos", "category_id": 2, "is_tbwa_client": False},
    {"brand_id": 9, "brand_name": "Jack 'n Jill", "category_id": 2, "is_tbwa_client": False},
    {"brand_id": 10, "brand_name": "Minola", "category_id": 3, "is_tbwa_client": False},
    {"brand_id": 11, "brand_name": "Baguio Oil", "category_id": 3, "is_tbwa_client": False},
    {"brand_id": 12, "brand_name": "Golden Fiesta", "category_id": 3, "is_tbwa_client": False},
    {"brand_id": 13, "brand_name": "UFC", "category_id": 4, "is_tbwa_client": False},
    {"brand_id": 14, "brand_name": "Hunt's", "category_id": 4, "is_tbwa_client": False},
    {"brand_id": 15, "brand_name": "555", "category_id": 4, "is_tbwa_client": False},
    {"brand_id": 16, "brand_name": "PMFTC", "category_id": 5, "is_tbwa_client": False},
    {"brand_id": 17, "brand_name": "BAT", "category_id": 5, "is_tbwa_client": False},
]

# Save brands.csv
with open(outdir / "brands.csv", 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=["brand_id", "brand_name", "category_id", "is_tbwa_client"])
    writer.writeheader()
    writer.writerows(brands)

# SKU definitions with all required fields
sku_data = []
sku_id = 10001

# Helper to create SKU entry
def add_sku(brand_id, sku_name, size, flavor, packaging):
    global sku_id
    brand = next(b for b in brands if b["brand_id"] == brand_id)
    cat = next(c for c in categories if c["category_id"] == brand["category_id"])
    
    sku_data.append({
        "brand_id": brand_id,
        "brand_name": brand["brand_name"],
        "category_id": brand["category_id"],
        "category_name": cat["category_name"],
        "sku_id": sku_id,
        "sku_name": sku_name,
        "variant_size": size,
        "variant_flavor": flavor,
        "variant_packaging": packaging,
        "is_tbwa_client": brand["is_tbwa_client"]
    })
    sku_id += 1

# TBWA Client SKUs
# Alaska
add_sku(1, "Alaska Evaporada 370ml", "370ml", "Original", "Can")
add_sku(1, "Alaska Condensada 300ml", "300ml", "Original", "Can")
add_sku(1, "Alaska Fresh Milk 1L", "1L", "Original", "Tetra")
add_sku(1, "Alaska Powdered Milk Drink 300g", "300g", "Original", "Pouch")
add_sku(1, "Alaska Powdered Milk Drink 700g", "700g", "Original", "Pouch")
add_sku(1, "Alaska UHT Chocolate 1L", "1L", "Chocolate", "Tetra")
add_sku(1, "Alaska Slim Low Fat 1L", "1L", "Low Fat", "Tetra")
add_sku(1, "Alaska Evaporada Pouch 180ml", "180ml", "Original", "Pouch")
add_sku(1, "Alaska Creamy Taste 370ml", "370ml", "Creamy", "Can")
add_sku(1, "Alaska Sweetened Condensed Pouch 90g", "90g", "Sweetened", "Pouch")

# Oishi
add_sku(2, "Oishi Prawn Crackers Regular 60g", "60g", "Regular", "Plastic")
add_sku(2, "Oishi Prawn Crackers Spicy 60g", "60g", "Spicy", "Plastic")
add_sku(2, "Oishi Marty's Cracklin' 90g", "90g", "Plain", "Plastic")
add_sku(2, "Oishi Pillows Chocolate 150g", "150g", "Chocolate", "Plastic")
add_sku(2, "Oishi Pillows Ube 150g", "150g", "Ube", "Plastic")
add_sku(2, "Oishi Ridges Potato Chips 85g", "85g", "Salted", "Plastic")
add_sku(2, "Oishi Rinbee Cheese Sticks 55g", "55g", "Cheese", "Plastic")
add_sku(2, "Oishi Bread Pan Garlic 50g", "50g", "Garlic", "Plastic")
add_sku(2, "Oishi Bread Pan Cheese 50g", "50g", "Cheese", "Plastic")
add_sku(2, "Oishi Choco Chug 250ml", "250ml", "Chocolate", "Tetra")
add_sku(2, "Oishi Smart C Drink 350ml", "350ml", "Citrus", "Plastic")
add_sku(2, "Oishi Fishda Fish Crackers 90g", "90g", "Original", "Plastic")

# Marca Leon / Star Margarine
add_sku(3, "Marca Leon Pure Coconut Oil 1L", "1L", "Original", "Bottle")
add_sku(3, "Marca Leon Palm Oil 1L", "1L", "Original", "Bottle")
add_sku(3, "Marca Leon Palm Oil 2L", "2L", "Original", "Bottle")
add_sku(3, "Marca Leon Corn Oil 500ml", "500ml", "Original", "Bottle")
add_sku(3, "Marca Leon Canola Oil 1L", "1L", "Original", "Bottle")
add_sku(3, "Star Margarine Classic 250g", "250g", "Original", "Tub")
add_sku(3, "Star Margarine Classic 500g", "500g", "Original", "Tub")
add_sku(3, "Star Margarine Sweet Blend 250g", "250g", "Sweet", "Tub")
add_sku(3, "Star Margarine Sweet Blend 500g", "500g", "Sweet", "Tub")
add_sku(3, "Star Margarine Garlic 250g", "250g", "Garlic", "Tub")

# Del Monte
add_sku(4, "Del Monte Pineapple Juice Can 240ml", "240ml", "Original", "Can")
add_sku(4, "Del Monte Pineapple Juice 1L", "1L", "Original", "Tetra")
add_sku(4, "Del Monte Spaghetti Sauce Sweet 1kg", "1kg", "Sweet", "Pouch")
add_sku(4, "Del Monte Spaghetti Sauce Italian 1kg", "1kg", "Italian", "Pouch")
add_sku(4, "Del Monte Tomato Sauce 200g", "200g", "Original", "Pouch")
add_sku(4, "Del Monte Tomato Sauce 1kg", "1kg", "Original", "Pouch")
add_sku(4, "Del Monte Fruit Cocktail 432g", "432g", "Mixed", "Can")
add_sku(4, "Del Monte Pineapple Tidbits 432g", "432g", "Original", "Can")
add_sku(4, "Del Monte Red Cane Vinegar 350ml", "350ml", "Original", "Bottle")
add_sku(4, "Del Monte Quick 'n Easy Marinade 200ml", "200ml", "Original", "Pouch")
add_sku(4, "Del Monte Ketchup Banana 320g", "320g", "Banana", "Pouch")
add_sku(4, "Del Monte Ketchup Tomato 320g", "320g", "Tomato", "Pouch")
add_sku(4, "Del Monte Juice Drink Four Seasons 1L", "1L", "Fruit Mix", "Tetra")
add_sku(4, "Del Monte Juice Drink Mango 1L", "1L", "Mango", "Tetra")

# JTI
add_sku(5, "Winston Red 20s", "20s", "Full Flavor", "Box")
add_sku(5, "Winston Blue 20s", "20s", "Light", "Box")
add_sku(5, "Winston White 20s", "20s", "Ultra Light", "Box")
add_sku(5, "Mevius Original Blue 20s", "20s", "Full Flavor", "Box")
add_sku(5, "Mevius Sky Blue 20s", "20s", "Light", "Box")
add_sku(5, "Mevius Option Purple 20s", "20s", "Menthol", "Box")
add_sku(5, "Camel Yellow 20s", "20s", "Full Flavor", "Box")
add_sku(5, "Camel Blue 20s", "20s", "Light", "Box")
add_sku(5, "Camel Activate Purple 20s", "20s", "Menthol Capsule", "Box")
add_sku(5, "LD Red 20s", "20s", "Full Flavor", "Box")
add_sku(5, "LD Blue 20s", "20s", "Light", "Box")

# Competitors
# Bear Brand
add_sku(6, "Bear Brand Fortified 320g", "320g", "Original", "Pouch")
add_sku(6, "Bear Brand Fortified 900g", "900g", "Original", "Pouch")
add_sku(6, "Bear Brand Choco 320g", "320g", "Chocolate", "Pouch")

# Nido
add_sku(7, "Nido Fortigrow 700g", "700g", "Original", "Pouch")

# Piattos
add_sku(8, "Piattos Cheese 85g", "85g", "Cheese", "Plastic")
add_sku(8, "Piattos Sour Cream 85g", "85g", "Sour Cream", "Plastic")

# Jack 'n Jill
add_sku(9, "Jack n Jill Chippy BBQ 110g", "110g", "BBQ", "Plastic")
add_sku(9, "Jack n Jill Nova Country Cheddar 78g", "78g", "Cheese", "Plastic")

# Oils competitors
add_sku(10, "Minola Coconut Oil 1L", "1L", "Original", "Bottle")
add_sku(11, "Baguio Oil 1L", "1L", "Original", "Bottle")
add_sku(12, "Golden Fiesta Palm Oil 1L", "1L", "Original", "Bottle")

# Canned/sauces competitors
add_sku(13, "UFC Banana Ketchup 320g", "320g", "Banana", "Bottle")
add_sku(13, "UFC Spaghetti Sauce 1kg", "1kg", "Sweet", "Pouch")
add_sku(14, "Hunts Spaghetti Sauce 1kg", "1kg", "Original", "Pouch")
add_sku(15, "555 Sardines 155g", "155g", "Tomato", "Can")
add_sku(15, "555 Tuna Afritada 155g", "155g", "Afritada", "Can")

# Tobacco competitors
add_sku(16, "Marlboro Red 20s", "20s", "Full Flavor", "Box")
add_sku(16, "Philip Morris Blue 20s", "20s", "Light", "Box")
add_sku(17, "Lucky Strike Red 20s", "20s", "Full Flavor", "Box")
add_sku(17, "Dunhill Blue 20s", "20s", "Light", "Box")

# Save master_data_brand_sku.csv
with open(outdir / "master_data_brand_sku.csv", 'w', newline='') as f:
    fieldnames = ["brand_id", "brand_name", "category_id", "category_name", "sku_id", "sku_name", 
                  "variant_size", "variant_flavor", "variant_packaging", "is_tbwa_client"]
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(sku_data)

# Save sku_variants.csv
sku_variants = [{k: v for k, v in sku.items() if k in ["sku_id", "variant_size", "variant_flavor", "variant_packaging"]} 
                for sku in sku_data]
with open(outdir / "sku_variants.csv", 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=["sku_id", "variant_size", "variant_flavor", "variant_packaging"])
    writer.writeheader()
    writer.writerows(sku_variants)

# -----------------------------
# 3) Brand Ownership (RLS)
# -----------------------------
tbwa_tenant_uuid = str(uuid.uuid4())
brand_ownership = []
for brand in brands:
    brand_ownership.append({
        "brand_id": brand["brand_id"],
        "tenant_id": tbwa_tenant_uuid,
        "is_tbwa_client": brand["is_tbwa_client"]
    })

with open(outdir / "brand_ownership.csv", 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=["brand_id", "tenant_id", "is_tbwa_client"])
    writer.writeheader()
    writer.writerows(brand_ownership)

# -----------------------------
# 4) Transactions & Items
# -----------------------------
N_TX = 18000
start_date = datetime.now() - timedelta(days=365)

# Price map
price_map = {
    10001: 45.00, 10002: 38.00, 10003: 95.00, 10004: 115.00, 10005: 145.00,
    10006: 98.00, 10007: 95.00, 10008: 25.00, 10009: 42.00, 10010: 22.00,
    10011: 20.00, 10012: 20.00, 10013: 28.00, 10014: 55.00, 10015: 58.00,
    10016: 38.00, 10017: 15.00, 10018: 18.00, 10019: 18.00, 10020: 85.00,
    10021: 42.00, 10022: 18.00, 10023: 180.00, 10024: 185.00, 10025: 220.00,
    10026: 95.00, 10027: 195.00, 10028: 65.00, 10029: 85.00, 10030: 68.00,
    10031: 88.00, 10032: 72.00, 10033: 42.00, 10034: 85.00, 10035: 105.00,
    10036: 115.00, 10037: 28.00, 10038: 58.00, 10039: 35.00, 10040: 38.00,
    10041: 25.00, 10042: 22.00, 10043: 45.00, 10044: 48.00, 10045: 68.00,
    10046: 72.00, 10047: 145.00, 10048: 140.00, 10049: 138.00, 10050: 150.00,
    10051: 148.00, 10052: 155.00, 10053: 140.00, 10054: 138.00, 10055: 145.00,
    10056: 120.00, 10057: 118.00, 10058: 125.00, 10059: 165.00, 10060: 128.00,
    10061: 285.00, 10062: 38.00, 10063: 40.00, 10064: 30.00, 10065: 32.00,
    10066: 165.00, 10067: 155.00, 10068: 140.00, 10069: 42.00, 10070: 48.00,
    10071: 98.00, 10072: 25.00, 10073: 28.00, 10074: 155.00, 10075: 150.00,
    10076: 145.00, 10077: 165.00
}

# Build SKU pools by category
fmcg_skus = [s for s in sku_data if s["category_id"] in [1,2,3,4]]
tobacco_skus = [s for s in sku_data if s["category_id"] == 5]

# Weighted selection functions
def select_fmcg_sku():
    tbwa_fmcg = [s for s in fmcg_skus if s["is_tbwa_client"]]
    comp_fmcg = [s for s in fmcg_skus if not s["is_tbwa_client"]]
    
    if random.random() < 0.20 and tbwa_fmcg:
        return random.choice(tbwa_fmcg)
    elif comp_fmcg:
        return random.choice(comp_fmcg)
    return random.choice(fmcg_skus)

def select_tobacco_sku():
    jti_skus = [s for s in tobacco_skus if s["brand_id"] == 5]
    other_tobacco = [s for s in tobacco_skus if s["brand_id"] != 5]
    
    if random.random() < 0.39 and jti_skus:
        return random.choice(jti_skus)
    elif other_tobacco:
        return random.choice(other_tobacco)
    return random.choice(tobacco_skus)

# Generate transactions
tx_rows = []
item_rows = []

for tx_id in range(1, N_TX + 1):
    dt = start_date + timedelta(days=np.random.randint(0, 365), minutes=np.random.randint(0, 24*60))
    store = random.choice(store_rows)
    
    # 1-4 items per basket
    n_items = np.random.choice([1,1,2,2,3,4], p=[0.35,0.10,0.25,0.15,0.10,0.05])
    item_total = 0.0
    
    for _ in range(n_items):
        # 88% FMCG, 12% tobacco
        if random.random() < 0.88:
            sku = select_fmcg_sku()
        else:
            sku = select_tobacco_sku()
        
        qty = np.random.choice([1,1,1,2,3], p=[0.45,0.25,0.15,0.10,0.05])
        price = price_map.get(sku["sku_id"], 50.00)
        line_total = price * qty
        
        item_rows.append({
            "transaction_id": tx_id,
            "sku_id": sku["sku_id"],
            "brand_id": sku["brand_id"],
            "quantity": qty,
            "unit_price": price,
            "line_total": round(line_total, 2)
        })
        item_total += line_total
    
    tx_rows.append({
        "transaction_id": tx_id,
        "store_id": store["store_id"],
        "transaction_ts": dt.isoformat(),
        "basket_total": round(item_total, 2)
    })

# Save transactions.csv
with open(outdir / "transactions.csv", 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=["transaction_id", "store_id", "transaction_ts", "basket_total"])
    writer.writeheader()
    writer.writerows(tx_rows)

# Save transaction_items.csv
with open(outdir / "transaction_items.csv", 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=["transaction_id", "sku_id", "brand_id", "quantity", "unit_price", "line_total"])
    writer.writeheader()
    writer.writerows(item_rows)

# -----------------------------
# 5) SQL Schema with RLS
# -----------------------------
sql_content = f"""-- Scout Analytics Schema with RLS
-- Generated for TBWA Tenant: {tbwa_tenant_uuid}

CREATE SCHEMA IF NOT EXISTS scout;

-- Categories
CREATE TABLE IF NOT EXISTS scout.categories (
  category_id INT PRIMARY KEY,
  category_name TEXT NOT NULL
);

-- Brands
CREATE TABLE IF NOT EXISTS scout.brands (
  brand_id INT PRIMARY KEY,
  brand_name TEXT NOT NULL,
  category_id INT NOT NULL REFERENCES scout.categories(category_id),
  is_tbwa_client BOOLEAN NOT NULL DEFAULT FALSE
);

-- SKUs (Master)
CREATE TABLE IF NOT EXISTS scout.master_data_brand_sku (
  brand_id INT NOT NULL REFERENCES scout.brands(brand_id),
  brand_name TEXT NOT NULL,
  category_id INT NOT NULL REFERENCES scout.categories(category_id),
  category_name TEXT NOT NULL,
  sku_id INT PRIMARY KEY,
  sku_name TEXT NOT NULL,
  variant_size TEXT,
  variant_flavor TEXT,
  variant_packaging TEXT,
  is_tbwa_client BOOLEAN NOT NULL DEFAULT FALSE
);

-- SKU Variants (for filters)
CREATE TABLE IF NOT EXISTS scout.sku_variants (
  sku_id INT PRIMARY KEY REFERENCES scout.master_data_brand_sku(sku_id),
  variant_size TEXT,
  variant_flavor TEXT,
  variant_packaging TEXT
);

-- Brand ownership (RLS)
CREATE TABLE IF NOT EXISTS scout.brand_ownership (
  brand_id INT NOT NULL REFERENCES scout.brands(brand_id),
  tenant_id UUID NOT NULL,
  is_tbwa_client BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (brand_id, tenant_id)
);

-- Stores & Geography
CREATE TABLE IF NOT EXISTS scout.stores (
  store_id INT PRIMARY KEY,
  store_name TEXT NOT NULL,
  region_id INT NOT NULL,
  region_name TEXT NOT NULL,
  city TEXT NOT NULL,
  barangay TEXT NOT NULL
);

-- Transactions
CREATE TABLE IF NOT EXISTS scout.transactions (
  transaction_id INT PRIMARY KEY,
  store_id INT NOT NULL REFERENCES scout.stores(store_id),
  transaction_ts TIMESTAMP NOT NULL,
  basket_total NUMERIC(12,2) NOT NULL
);

-- Transaction Items
CREATE TABLE IF NOT EXISTS scout.transaction_items (
  transaction_id INT NOT NULL REFERENCES scout.transactions(transaction_id),
  sku_id INT NOT NULL REFERENCES scout.master_data_brand_sku(sku_id),
  brand_id INT NOT NULL REFERENCES scout.brands(brand_id),
  quantity INT NOT NULL,
  unit_price NUMERIC(10,2) NOT NULL,
  line_total NUMERIC(12,2) NOT NULL
);

-- RLS Policy Function
CREATE OR REPLACE FUNCTION scout.get_tenant_id() RETURNS UUID AS $$
DECLARE
  claims JSON;
  tid UUID;
BEGIN
  BEGIN
    claims := current_setting('request.jwt.claims', true)::json;
    tid := (claims->>'tenant_id')::uuid;
  EXCEPTION WHEN others THEN
    tid := NULL;
  END;
  RETURN tid;
END; $$ LANGUAGE plpgsql STABLE;

-- Enable RLS on brands
ALTER TABLE scout.brands ENABLE ROW LEVEL SECURITY;

CREATE POLICY brand_rls
  ON scout.brands
  USING (
    EXISTS (
      SELECT 1 FROM scout.brand_ownership bo
      WHERE bo.brand_id = brands.brand_id
        AND (bo.tenant_id = scout.get_tenant_id() OR scout.get_tenant_id() IS NULL)
    )
  );

-- Gold layer view
CREATE OR REPLACE VIEW scout.vw_sales_gold AS
SELECT
  ti.brand_id,
  b.brand_name,
  b.category_id,
  c.category_name,
  ti.sku_id,
  m.sku_name,
  s.region_id,
  s.region_name,
  s.city,
  s.barangay,
  DATE_TRUNC('day', t.transaction_ts) AS d,
  SUM(ti.quantity) AS qty,
  SUM(ti.line_total) AS revenue
FROM scout.transaction_items ti
JOIN scout.transactions t ON t.transaction_id = ti.transaction_id
JOIN scout.stores s ON s.store_id = t.store_id
JOIN scout.brands b ON b.brand_id = ti.brand_id
JOIN scout.categories c ON c.category_id = b.category_id
JOIN scout.master_data_brand_sku m ON m.sku_id = ti.sku_id
GROUP BY 1,2,3,4,5,6,7,8,9,10,11;

-- Indexes for performance
CREATE INDEX idx_transactions_ts ON scout.transactions(transaction_ts);
CREATE INDEX idx_transactions_store ON scout.transactions(store_id);
CREATE INDEX idx_items_sku ON scout.transaction_items(sku_id);
CREATE INDEX idx_items_brand ON scout.transaction_items(brand_id);
CREATE INDEX idx_stores_region ON scout.stores(region_id);

-- Seed the tenant mapping
INSERT INTO scout.brand_ownership (brand_id, tenant_id, is_tbwa_client)
SELECT brand_id, '{tbwa_tenant_uuid}'::uuid, is_tbwa_client FROM scout.brands
ON CONFLICT (brand_id, tenant_id) DO UPDATE
SET is_tbwa_client = EXCLUDED.is_tbwa_client;
"""

with open(outdir / "scout_rls_and_schema.sql", 'w') as f:
    f.write(sql_content)

# Summary
print(f"""
Scout Analytics CSV Generation Complete!
=======================================

Files created in {outdir}:
- geography.csv ({len(rows_geo)} locations)
- stores.csv ({len(store_rows)} stores)
- categories.csv (5 categories)
- brands.csv (17 brands)
- master_data_brand_sku.csv ({len(sku_data)} SKUs)
- sku_variants.csv ({len(sku_variants)} variants)
- brand_ownership.csv (RLS mapping)
- transactions.csv ({len(tx_rows)} transactions)
- transaction_items.csv ({len(item_rows)} line items)
- scout_rls_and_schema.sql (Complete schema with RLS)

TBWA Tenant UUID: {tbwa_tenant_uuid}

Market Share Targets:
- FMCG TBWA Clients: ~20%
- JTI Tobacco: ~39%

To load into Supabase:
1. Run the SQL schema: psql $DATABASE_URL < scout_seed_data/scout_rls_and_schema.sql
2. Upload CSVs via Supabase Dashboard or use COPY commands
""")