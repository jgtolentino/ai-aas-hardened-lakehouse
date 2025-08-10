#!/usr/bin/env python3
"""
Synthetic Dataset Generator for Scout Medallion Architecture
Generates Bronze → Silver → Gold → Platinum data for Supabase/Postgres.
Includes TBWA clients with realistic market share:
- FMCG: ~20% for TBWA clients
- Tobacco: ~39% for JTI
"""

import json
import random
import uuid
import hashlib
import pandas as pd
from datetime import datetime, timedelta
from faker import Faker
from sqlalchemy import create_engine, text
import numpy as np
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# === CONFIG ===
DB_URI = os.getenv("SUPABASE_DB_URI", "postgresql://postgres:postgres@localhost:5432/postgres")
NUM_TRANSACTIONS = 18000  # 365 days realistic volume
NUM_CUSTOMERS = 1000
SEED_START_DATE = datetime(2024, 1, 1)

fake = Faker("en_PH")
random.seed(42)
np.random.seed(42)

# === REGIONS & GEOGRAPHY ===
regions = [
    (1, "NCR", "National Capital Region"),
    (2, "Region I", "Ilocos Region"),
    (3, "Region II", "Cagayan Valley"),
    (4, "Region III", "Central Luzon"),
    (5, "CALABARZON", "Region IV-A"),
    (6, "MIMAROPA", "Region IV-B"),
    (7, "Region V", "Bicol Region"),
    (8, "Region VI", "Western Visayas"),
    (9, "Region VII", "Central Visayas"),
    (10, "Region VIII", "Eastern Visayas"),
    (11, "Region IX", "Zamboanga Peninsula"),
    (12, "Region X", "Northern Mindanao"),
    (13, "Region XI", "Davao Region"),
    (14, "Region XII", "SOCCSKSARGEN"),
    (15, "CARAGA", "Region XIII"),
    (16, "CAR", "Cordillera Administrative Region"),
    (17, "BARMM", "Bangsamoro Autonomous Region")
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
    1: ["Quezon City", "Manila", "Makati", "Taguig", "Caloocan", "Pasig", "Mandaluyong"],
    5: ["Antipolo", "Bacoor", "Dasmariñas", "Calamba", "San Pedro", "Lipa"],
    4: ["San Fernando", "Angeles", "Olongapo", "Malolos"],
    8: ["Iloilo City", "Bacolod City", "Roxas City"],
    9: ["Cebu City", "Mandaue", "Lapu-Lapu"],
    13: ["Davao City", "Tagum", "Digos"],
    12: ["Cagayan de Oro", "Iligan", "Valencia"]
}

# === MASTER DATA - BRANDS & PRODUCTS ===
categories = [
    (1, "Dairy & Beverages"),
    (2, "Snacks & Beverages"),
    (3, "Oils & Margarine"),
    (4, "Canned Goods & Sauces"),
    (5, "Tobacco")
]

# TBWA Clients
brands_tbwa = [
    (1, "Alaska", 1, True),
    (2, "Oishi", 2, True),
    (3, "Marca Leon", 3, True),
    (4, "Del Monte", 4, True),
    (5, "JTI", 5, True)
]

# Competitors
brands_comp = [
    (6, "Bear Brand", 1, False),
    (7, "Nido", 1, False),
    (8, "Piattos", 2, False),
    (9, "Jack 'n Jill", 2, False),
    (10, "Minola", 3, False),
    (11, "Baguio Oil", 3, False),
    (12, "Golden Fiesta", 3, False),
    (13, "UFC", 4, False),
    (14, "Hunt's", 4, False),
    (15, "555", 4, False),
    (16, "PMFTC", 5, False),
    (17, "BAT", 5, False)
]

# SKU definitions
sku_definitions = [
    # Alaska
    (1, "Alaska Evaporada 370ml", "370ml", "Original", "Can", 45.00),
    (1, "Alaska Condensada 300ml", "300ml", "Original", "Can", 38.00),
    (1, "Alaska Fresh Milk 1L", "1L", "Original", "Tetra", 95.00),
    (1, "Alaska Powdered Milk Drink 300g", "300g", "Original", "Pouch", 115.00),
    (1, "Alaska UHT Chocolate 1L", "1L", "Chocolate", "Tetra", 98.00),
    
    # Oishi
    (2, "Oishi Prawn Crackers 60g", "60g", "Regular", "Plastic", 20.00),
    (2, "Oishi Prawn Crackers 60g Spicy", "60g", "Spicy", "Plastic", 20.00),
    (2, "Oishi Pillows 150g Chocolate", "150g", "Chocolate", "Plastic", 55.00),
    (2, "Oishi Rinbee 55g Cheese Sticks", "55g", "Cheese", "Plastic", 15.00),
    
    # Marca Leon / Star
    (3, "Marca Leon Coconut Oil 1L", "1L", "Original", "Bottle", 180.00),
    (3, "Star Margarine Classic 250g", "250g", "Original", "Tub", 65.00),
    (3, "Star Margarine Sweet 250g", "250g", "Sweet", "Tub", 68.00),
    
    # Del Monte
    (4, "Del Monte Pineapple Juice 1L", "1L", "Original", "Tetra", 85.00),
    (4, "Del Monte Spaghetti Sauce 1kg Sweet", "1kg", "Sweet", "Pouch", 105.00),
    (4, "Del Monte Tomato Sauce 200g", "200g", "Original", "Pouch", 28.00),
    (4, "Del Monte Banana Ketchup 320g", "320g", "Banana", "Pouch", 45.00),
    
    # JTI
    (5, "Winston Red 20s", "20s", "Full Flavor", "Box", 145.00),
    (5, "Mevius Original Blue 20s", "20s", "Full Flavor", "Box", 150.00),
    (5, "Camel Yellow 20s", "20s", "Full Flavor", "Box", 140.00),
    (5, "LD Red 20s", "20s", "Full Flavor", "Box", 120.00),
    
    # Competitors
    (6, "Bear Brand Fortified 320g", "320g", "Original", "Pouch", 125.00),
    (6, "Bear Brand Choco 320g", "320g", "Chocolate", "Pouch", 128.00),
    (7, "Nido Fortigrow 700g", "700g", "Original", "Pouch", 285.00),
    (8, "Piattos Cheese 85g", "85g", "Cheese", "Plastic", 38.00),
    (9, "Jack n Jill Chippy BBQ 110g", "110g", "BBQ", "Plastic", 30.00),
    (10, "Minola Coconut Oil 1L", "1L", "Original", "Bottle", 165.00),
    (11, "Baguio Oil 1L", "1L", "Original", "Bottle", 155.00),
    (12, "Golden Fiesta Palm Oil 1L", "1L", "Original", "Bottle", 140.00),
    (13, "UFC Banana Ketchup 320g", "320g", "Banana", "Bottle", 42.00),
    (14, "Hunts Spaghetti Sauce 1kg", "1kg", "Original", "Pouch", 98.00),
    (15, "555 Sardines 155g", "155g", "Tomato", "Can", 25.00),
    (16, "Marlboro Red 20s", "20s", "Full Flavor", "Box", 155.00),
    (16, "Philip Morris Blue 20s", "20s", "Light", "Box", 150.00),
    (17, "Lucky Strike Red 20s", "20s", "Full Flavor", "Box", 145.00),
    (17, "Dunhill Blue 20s", "20s", "Light", "Box", 165.00)
]

# === HELPER FUNCTIONS ===
def generate_psgc(region_id, province_id, city_id):
    """Generate Philippine Standard Geographic Code"""
    return f"{region_id:02d}{province_id:02d}{city_id:04d}00"

def random_store(store_id, region_data):
    region_id, region_key, region_name = region_data
    cities = region_city_map.get(region_id, [f"City-{region_id}"])
    city = random.choice(cities)
    barangay = random.choice(barangay_pool)
    
    return {
        "store_id": f"STR{store_id:06d}",
        "store_name": f"{barangay} Sari-Sari Store #{store_id % 100}",
        "store_code": f"{region_key}-{store_id:04d}",
        "channel": "store",
        "region": region_name,
        "province": city,  # Simplified for demo
        "city": city,
        "barangay": barangay,
        "address": f"{random.randint(1, 999)} {barangay} St., {city}",
        "latitude": 14.5995 + random.uniform(-2, 2),
        "longitude": 120.9842 + random.uniform(-2, 2),
        "citymun_psgc": generate_psgc(region_id, 1, store_id % 100),
        "region_psgc": f"{region_id:02d}000000",
        "is_active": True,
        "opened_date": SEED_START_DATE - timedelta(days=random.randint(180, 1825)),
        "store_size_sqm": random.randint(15, 100),
        "staff_count": random.randint(1, 5)
    }

def random_customer(customer_id):
    return {
        "customer_id": f"CUST{customer_id:08d}",
        "customer_code": f"C{customer_id:06d}",
        "mobile_number": f"09{random.randint(100000000, 999999999)}",
        "email": fake.email() if random.random() > 0.7 else None,
        "first_name": fake.first_name(),
        "last_name": fake.last_name(),
        "birthdate": fake.date_of_birth(minimum_age=18, maximum_age=65),
        "gender": random.choice(["M", "F"]),
        "customer_type": random.choice(["new", "returning", "vip"]),
        "loyalty_tier": random.choice([None, "Bronze", "Silver", "Gold"]),
        "loyalty_points": random.randint(0, 5000),
        "first_purchase_date": SEED_START_DATE - timedelta(days=random.randint(0, 365))
    }

def event_hash(data):
    """Generate hash for idempotent event ingestion"""
    json_str = json.dumps(data, sort_keys=True, default=str)
    return hashlib.sha256(json_str.encode()).digest()

def weighted_sku_selection(sku_pool, is_fmcg=True):
    """Select SKU with proper market share weighting"""
    if is_fmcg:
        # FMCG: 20% TBWA, 80% competitors
        tbwa_skus = [s for s in sku_pool if s["is_tbwa"]]
        comp_skus = [s for s in sku_pool if not s["is_tbwa"]]
        
        if random.random() < 0.20 and tbwa_skus:
            return random.choice(tbwa_skus)
        elif comp_skus:
            return random.choice(comp_skus)
    else:
        # Tobacco: 39% JTI, 61% others
        jti_skus = [s for s in sku_pool if s["brand_id"] == 5]
        other_skus = [s for s in sku_pool if s["brand_id"] != 5]
        
        if random.random() < 0.39 and jti_skus:
            return random.choice(jti_skus)
        elif other_skus:
            return random.choice(other_skus)
    
    return random.choice(sku_pool)

# === DATA GENERATION ===
def generate_data():
    print("Generating master data...")
    
    # Generate stores
    stores = []
    store_idx = 1
    for region in regions[:10]:  # Focus on major regions
        num_stores = random.randint(20, 40)
        for _ in range(num_stores):
            stores.append(random_store(store_idx, region))
            store_idx += 1
    
    # Generate customers
    customers = [random_customer(i) for i in range(1, NUM_CUSTOMERS + 1)]
    
    # Generate products/SKUs
    products = []
    for idx, (brand_id, sku_name, size, flavor, packaging, price) in enumerate(sku_definitions):
        brand = next((b for b in brands_tbwa + brands_comp if b[0] == brand_id), None)
        if brand:
            products.append({
                "product_id": f"PROD{idx+1:06d}",
                "product_name": sku_name,
                "product_code": f"SKU{idx+1:04d}",
                "barcode": f"899{random.randint(1000000000, 9999999999)}",
                "category": next(c[1] for c in categories if c[0] == brand[2]),
                "brand": brand[1],
                "brand_id": brand_id,
                "is_tbwa": brand[3],
                "unit_cost": round(price * 0.7, 2),
                "srp": price,
                "variant_size": size,
                "variant_flavor": flavor,
                "variant_packaging": packaging,
                "is_active": True
            })
    
    # Split products by category
    fmcg_products = [p for p in products if p["category"] != "Tobacco"]
    tobacco_products = [p for p in products if p["category"] == "Tobacco"]
    
    print(f"Generated {len(stores)} stores, {len(customers)} customers, {len(products)} products")
    
    # Generate transactions
    print("Generating transactions...")
    transactions = []
    bronze_events = []
    silver_transactions = []
    silver_line_items = []
    
    for txn_idx in range(NUM_TRANSACTIONS):
        if txn_idx % 1000 == 0:
            print(f"  Processing transaction {txn_idx}/{NUM_TRANSACTIONS}")
        
        # Transaction metadata
        txn_date = SEED_START_DATE + timedelta(
            days=random.randint(0, 364),
            hours=random.randint(6, 22),
            minutes=random.randint(0, 59)
        )
        
        store = random.choice(stores)
        customer = random.choice(customers) if random.random() > 0.3 else None
        
        # Determine time of day
        hour = txn_date.hour
        if 6 <= hour < 12:
            time_of_day = "morning"
        elif 12 <= hour < 18:
            time_of_day = "afternoon"
        elif 18 <= hour < 22:
            time_of_day = "evening"
        else:
            time_of_day = "night"
        
        # Generate basket (88% FMCG, 12% tobacco mix)
        basket_items = []
        num_items = random.choices([1, 2, 3, 4, 5], weights=[0.35, 0.30, 0.20, 0.10, 0.05])[0]
        
        for _ in range(num_items):
            if random.random() < 0.88:
                product = weighted_sku_selection(fmcg_products, is_fmcg=True)
            else:
                product = weighted_sku_selection(tobacco_products, is_fmcg=False)
            
            qty = random.choices([1, 2, 3], weights=[0.7, 0.2, 0.1])[0]
            basket_items.append({
                "product": product,
                "quantity": qty,
                "unit_price": product["srp"],
                "line_amount": product["srp"] * qty
            })
        
        # Calculate totals
        total_amount = sum(item["line_amount"] for item in basket_items)
        discount_amount = round(total_amount * random.uniform(0, 0.1), 2) if random.random() > 0.8 else 0
        tax_amount = round((total_amount - discount_amount) * 0.12, 2)
        net_amount = total_amount - discount_amount
        
        # Create transaction record
        transaction_id = f"TXN{txn_idx+1:08d}"
        
        # Bronze layer - raw event
        event_data = {
            "transaction_id": transaction_id,
            "store_id": store["store_id"],
            "customer_id": customer["customer_id"] if customer else None,
            "timestamp": txn_date.isoformat(),
            "items": [
                {
                    "product_id": item["product"]["product_id"],
                    "quantity": item["quantity"],
                    "price": item["unit_price"]
                }
                for item in basket_items
            ],
            "total": total_amount,
            "discount": discount_amount
        }
        
        bronze_events.append({
            "event_id": str(uuid.uuid4()),
            "event_type": "transaction",
            "event_data": event_data,
            "event_hash": event_hash(event_data),
            "source_system": "POS",
            "ingested_at": datetime.now()
        })
        
        # Silver layer - cleaned transaction
        silver_transactions.append({
            "id": str(uuid.uuid4()),
            "transaction_id": transaction_id,
            "store_id": store["store_id"],
            "ts": txn_date,
            "date_key": txn_date.date(),
            "time_of_day": time_of_day,
            "customer_id": customer["customer_id"] if customer else None,
            "customer_type": customer["customer_type"] if customer else "walk-in",
            "total_amount": total_amount,
            "discount_amount": discount_amount,
            "tax_amount": tax_amount,
            "net_amount": net_amount,
            "payment_method": random.choice(["cash", "gcash", "maya", "card"]),
            "item_count": len(basket_items),
            "unique_products": len(set(item["product"]["product_id"] for item in basket_items)),
            "units_per_transaction": sum(item["quantity"] for item in basket_items),
            "basket_size": len(basket_items),
            "peso_value": net_amount,
            "product_category": basket_items[0]["product"]["category"],  # Primary category
            "region": store["region"],
            "province": store["province"],
            "city": store["city"],
            "processed_at": datetime.now()
        })
        
        # Silver layer - line items
        for item in basket_items:
            silver_line_items.append({
                "line_id": str(uuid.uuid4()),
                "transaction_id": transaction_id,
                "product_id": item["product"]["product_id"],
                "quantity": item["quantity"],
                "unit_price": item["unit_price"],
                "line_amount": item["line_amount"],
                "discount_amount": 0
            })
    
    print("Data generation complete!")
    
    return {
        "stores": stores,
        "customers": customers,
        "products": products,
        "bronze_events": bronze_events,
        "silver_transactions": silver_transactions,
        "silver_line_items": silver_line_items
    }

# === DATABASE LOADING ===
def load_to_database(data):
    print("\nConnecting to database...")
    engine = create_engine(DB_URI)
    
    with engine.begin() as conn:
        print("Creating schema if not exists...")
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS scout"))
        
        # Load dimension tables
        print("Loading dimension tables...")
        
        # dim_store
        df_stores = pd.DataFrame(data["stores"])
        df_stores.to_sql("dim_store", schema="scout", con=conn, if_exists="replace", index=False)
        
        # dim_customer
        df_customers = pd.DataFrame(data["customers"])
        df_customers.to_sql("dim_customer", schema="scout", con=conn, if_exists="replace", index=False)
        
        # dim_product
        df_products = pd.DataFrame(data["products"])
        df_products.to_sql("dim_product", schema="scout", con=conn, if_exists="replace", index=False)
        
        # Bronze layer
        print("Loading Bronze layer...")
        df_bronze = pd.DataFrame(data["bronze_events"])
        # Convert event_data to JSON string
        df_bronze["event_data"] = df_bronze["event_data"].apply(json.dumps)
        df_bronze.to_sql("bronze_events", schema="scout", con=conn, if_exists="append", index=False)
        
        # Silver layer
        print("Loading Silver layer...")
        df_silver_txn = pd.DataFrame(data["silver_transactions"])
        df_silver_txn.to_sql("silver_transactions", schema="scout", con=conn, if_exists="append", index=False)
        
        df_silver_items = pd.DataFrame(data["silver_line_items"])
        df_silver_items.to_sql("silver_line_items", schema="scout", con=conn, if_exists="append", index=False)
        
        # Refresh materialized views
        print("Refreshing materialized views...")
        try:
            conn.execute(text("SELECT scout.refresh_gold()"))
        except Exception as e:
            print(f"Note: Gold refresh function may not exist yet: {e}")
        
        print("✅ Data loaded successfully!")
        
        # Print summary statistics
        print("\n=== Summary Statistics ===")
        result = conn.execute(text("""
            SELECT 
                COUNT(DISTINCT store_id) as stores,
                COUNT(DISTINCT customer_id) as customers,
                COUNT(DISTINCT transaction_id) as transactions,
                SUM(net_amount) as total_revenue
            FROM scout.silver_transactions
        """))
        stats = result.fetchone()
        print(f"Stores: {stats[0]}")
        print(f"Customers: {stats[1]}")
        print(f"Transactions: {stats[2]}")
        print(f"Total Revenue: ₱{stats[3]:,.2f}")

if __name__ == "__main__":
    print("Scout Analytics - Synthetic Data Generator")
    print("=========================================")
    print(f"Target: {NUM_TRANSACTIONS} transactions")
    print(f"Market Share: FMCG TBWA=20%, JTI Tobacco=39%")
    print()
    
    # Generate data
    data = generate_data()
    
    # Load to database
    load_to_database(data)
    
    print("\n✅ Seeding complete!")