#!/usr/bin/env python3
"""
Renders DW Star Schema Overview as Markdown from live database
"""
import os
import psycopg2
from datetime import datetime

# Tables to check
FACT_TABLES = [
    'fact_transactions',
    'fact_transaction_items', 
    'fact_monthly_performance'
]

DIMENSION_TABLES = [
    'dim_date',
    'dim_time',
    'dim_store',
    'dim_product',
    'dim_customer',
    'dim_payment_method'
]

MASTER_TABLES = []  # Add any master/reference tables

BRIDGE_TABLES = [
    'bridge_product_bundle'
]

def get_table_stats(conn, schema, table):
    """Get row count and status for a table"""
    try:
        with conn.cursor() as cur:
            # Check if table exists
            cur.execute("""
                SELECT EXISTS (
                    SELECT 1 FROM information_schema.tables 
                    WHERE table_schema = %s AND table_name = %s
                )
            """, (schema, table))
            exists = cur.fetchone()[0]
            
            if not exists:
                return None, '❓ Missing'
            
            # Get row count
            cur.execute(f'SELECT COUNT(*) FROM {schema}.{table}')
            count = cur.fetchone()[0]
            
            if count == 0:
                return count, '❌ Empty'
            elif count <= 1 and 'dim_' in table and table not in ['dim_date', 'dim_time']:
                return count, '⚠️ Underpopulated'
            else:
                return count, '✅ Active'
    except Exception as e:
        return None, f'❌ Error: {str(e)}'

def get_volume_summary(conn):
    """Get volume summary from fact tables"""
    try:
        with conn.cursor() as cur:
            # Transaction summary
            cur.execute("""
                SELECT 
                    MIN(d.date_actual) as min_date,
                    MAX(d.date_actual) as max_date,
                    COUNT(DISTINCT f.transaction_id) as tx_count,
                    COUNT(DISTINCT f.customer_key) as unique_customers,
                    SUM(f.transaction_amount) as total_revenue,
                    COUNT(DISTINCT f.payment_method_key) as payment_methods
                FROM dw.fact_transactions f
                JOIN dw.dim_date d ON f.date_key = d.date_key
            """)
            
            result = cur.fetchone()
            if result and result[0]:
                return {
                    'period': f"{result[0]} to {result[1]}",
                    'transactions': f"{result[2]:,}",
                    'unique_customers': f"{result[3]:,}",
                    'revenue': f"${result[4]:,.2f}" if result[4] else "$0.00",
                    'payment_methods': result[5]
                }
    except:
        pass
    
    return None

def identify_gaps(stats):
    """Identify gaps in the star schema"""
    gaps = []
    
    # Check if fact_transaction_items is empty while fact_transactions has data
    if stats.get('fact_transactions', {}).get('count', 0) > 0:
        if stats.get('fact_transaction_items', {}).get('count', 0) == 0:
            gaps.append("- `fact_transaction_items` is empty but `fact_transactions` has data")
    
    # Check for underpopulated dimensions
    for dim in DIMENSION_TABLES:
        if dim not in ['dim_date', 'dim_time']:
            status = stats.get(dim, {}).get('status', '')
            if '⚠️ Underpopulated' in status:
                gaps.append(f"- `{dim}` has only {stats[dim]['count']} record(s)")
    
    # Check for missing tables
    for table in FACT_TABLES + DIMENSION_TABLES:
        if stats.get(table, {}).get('status') == '❓ Missing':
            gaps.append(f"- `{table}` table is missing")
    
    return gaps

def render_markdown():
    """Render the complete markdown overview"""
    # Connect to database
    db_url = os.getenv('PGURL', os.getenv('DATABASE_URL', 'postgresql://localhost/postgres'))
    conn = psycopg2.connect(db_url)
    
    # Collect stats
    stats = {}
    
    # Facts
    fact_rows = []
    for table in FACT_TABLES:
        count, status = get_table_stats(conn, 'dw', table)
        stats[table] = {'count': count, 'status': status}
        count_str = f"{count:,}" if count else "-"
        fact_rows.append(f"| `{table}` | {count_str} | {status} |")
    
    # Dimensions
    dim_rows = []
    for table in DIMENSION_TABLES:
        count, status = get_table_stats(conn, 'dw', table)
        stats[table] = {'count': count, 'status': status}
        count_str = f"{count:,}" if count else "-"
        dim_rows.append(f"| `{table}` | {count_str} | {status} |")
    
    # Masters
    master_rows = []
    for table in MASTER_TABLES:
        count, status = get_table_stats(conn, 'dw', table)
        stats[table] = {'count': count, 'status': status}
        count_str = f"{count:,}" if count else "-"
        master_rows.append(f"| `{table}` | {count_str} | {status} |")
    
    # Bridges
    bridge_rows = []
    for table in BRIDGE_TABLES:
        count, status = get_table_stats(conn, 'dw', table)
        stats[table] = {'count': count, 'status': status}
        count_str = f"{count:,}" if count else "-"
        bridge_rows.append(f"| `{table}` | {count_str} | {status} |")
    
    # Get volume summary
    volume = get_volume_summary(conn)
    
    # Identify gaps
    gaps = identify_gaps(stats)
    
    # Render markdown
    print("## 📊 Data Warehouse Overview")
    print()
    print("### Facts")
    print("| Table | Records | Status |")
    print("|-------|---------|--------|")
    for row in fact_rows:
        print(row)
    print()
    
    print("### Dimensions")
    print("| Table | Records | Status |")
    print("|-------|---------|--------|")
    for row in dim_rows:
        print(row)
    print()
    
    if master_rows:
        print("### Masters")
        print("| Table | Records | Status |")
        print("|-------|---------|--------|")
        for row in master_rows:
            print(row)
        print()
    
    if bridge_rows:
        print("### Bridges")
        print("| Table | Records | Status |")
        print("|-------|---------|--------|")
        for row in bridge_rows:
            print(row)
        print()
    
    # Volume summary
    if volume:
        print("### Volume Summary")
        print(f"- **Period**: {volume['period']}")
        print(f"- **Transactions**: {volume['transactions']}")
        print(f"- **Revenue**: {volume['revenue']}")
        print(f"- **Unique Customers**: {volume['unique_customers']}")
        print(f"- **Payment Methods**: {volume['payment_methods']}")
        print()
    
    # Gaps
    if gaps:
        print("### 🔍 Gaps Detected")
        for gap in gaps:
            print(gap)
        print()
    
    print(f"_Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}_")
    
    conn.close()

if __name__ == '__main__':
    render_markdown()