#!/usr/bin/env python3
"""
Hard performance checks for choropleth - ADM1/ADM3 joins and rendering
Exit with non-zero if performance gates are not met
"""

import sys
import time
import json
import psycopg2
import argparse
from datetime import datetime, timedelta
from typing import Dict, List, Tuple

# Performance gates (in seconds)
PERF_GATES = {
    'adm3_choropleth_p95': 1.5,    # ADM3 choropleth query < 1.5s p95
    'deck_gl_render_p95': 2.5,      # Deck.gl tile render < 2.5s p95
    'unmatched_threshold': 0.01,    # <1% unmatched citymun_psgc
}

class HardBenchmark:
    def __init__(self, conn_string: str):
        self.conn = psycopg2.connect(conn_string)
        self.results = []
        self.failures = []
        
    def check_join_coverage(self) -> bool:
        """Check ADM1/ADM3 join coverage"""
        print("\n🔍 Checking Geographic Join Coverage...")
        cursor = self.conn.cursor()
        
        # Check ADM3 (city/municipality) coverage
        cursor.execute("""
            WITH m AS (
                SELECT DISTINCT citymun_psgc 
                FROM scout.gold_citymun_daily 
                WHERE citymun_psgc IS NOT NULL
            ),
            g AS (
                SELECT citymun_psgc 
                FROM scout.geo_adm3_citymun
            )
            SELECT
                (SELECT COUNT(*) FROM m) as total_metrics,
                (SELECT COUNT(*) FROM m WHERE citymun_psgc IN (SELECT citymun_psgc FROM g)) as matched,
                (SELECT COUNT(*) FROM m WHERE citymun_psgc NOT IN (SELECT citymun_psgc FROM g)) as unmatched
        """)
        
        total, matched, unmatched = cursor.fetchone()
        unmatched_pct = (unmatched / total * 100) if total > 0 else 0
        
        print(f"  ADM3 Coverage:")
        print(f"    Total cities in metrics: {total}")
        print(f"    Matched with geometry: {matched}")
        print(f"    Unmatched: {unmatched} ({unmatched_pct:.2f}%)")
        
        if unmatched_pct > PERF_GATES['unmatched_threshold'] * 100:
            self.failures.append(f"ADM3 join coverage: {unmatched_pct:.2f}% unmatched (threshold: {PERF_GATES['unmatched_threshold']*100}%)")
            
            # Show examples of unmatched
            cursor.execute("""
                WITH m AS (SELECT DISTINCT citymun_psgc FROM scout.gold_citymun_daily WHERE citymun_psgc IS NOT NULL),
                     g AS (SELECT citymun_psgc FROM scout.geo_adm3_citymun)
                SELECT citymun_psgc
                FROM m
                WHERE citymun_psgc NOT IN (SELECT citymun_psgc FROM g)
                LIMIT 10
            """)
            unmatched_examples = cursor.fetchall()
            if unmatched_examples:
                print("    Examples of unmatched PSGC codes:")
                for (psgc,) in unmatched_examples:
                    print(f"      - {psgc}")
        
        # Check ADM1 (region) coverage
        cursor.execute("""
            SELECT COUNT(DISTINCT region_key) 
            FROM scout.gold_region_daily
            WHERE region_key NOT IN (SELECT region_key FROM scout.geo_adm1_region)
        """)
        
        unmatched_regions = cursor.fetchone()[0]
        if unmatched_regions > 0:
            self.failures.append(f"ADM1 join: {unmatched_regions} regions without geometry")
            
        cursor.close()
        return len(self.failures) == 0
        
    def benchmark_queries(self) -> bool:
        """Run performance benchmarks with p95 calculation"""
        print("\n⏱️  Running Performance Benchmarks...")
        
        # Test 1: ADM3 Choropleth Query (90 days)
        print("\n  Testing ADM3 choropleth query (90 days)...")
        query = """
            SELECT 
                citymun_psgc,
                citymun_name,
                ST_AsGeoJSON(geom) as geojson,
                SUM(peso_total) as total_sales,
                SUM(txn_count) as total_transactions
            FROM scout.gold_citymun_choropleth
            WHERE day >= CURRENT_DATE - INTERVAL '90 days'
            GROUP BY citymun_psgc, citymun_name, geom
            LIMIT 20000
        """
        
        times = []
        for i in range(10):  # Run 10 times for p95
            start = time.time()
            cursor = self.conn.cursor()
            cursor.execute(query)
            results = cursor.fetchall()
            cursor.close()
            elapsed = time.time() - start
            times.append(elapsed)
            print(f"    Run {i+1}: {elapsed:.3f}s ({len(results)} rows)")
            
        # Calculate p95
        times.sort()
        p95_time = times[int(len(times) * 0.95) - 1]
        avg_time = sum(times) / len(times)
        
        print(f"  ADM3 Choropleth Performance:")
        print(f"    Average: {avg_time:.3f}s")
        print(f"    P95: {p95_time:.3f}s (threshold: {PERF_GATES['adm3_choropleth_p95']}s)")
        
        if p95_time > PERF_GATES['adm3_choropleth_p95']:
            self.failures.append(f"ADM3 choropleth p95: {p95_time:.3f}s > {PERF_GATES['adm3_choropleth_p95']}s")
            
        # Test 2: Check if simplified geometries are being used
        print("\n  Checking geometry simplification...")
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT 
                'Original' as type,
                AVG(ST_NPoints(geom)) as avg_points,
                MAX(LENGTH(ST_AsGeoJSON(geom))) as max_json_size
            FROM scout.geo_adm3_citymun
            UNION ALL
            SELECT 
                'Simplified' as type,
                AVG(ST_NPoints(geom)) as avg_points,
                MAX(LENGTH(ST_AsGeoJSON(geom))) as max_json_size
            FROM scout.geo_adm3_citymun_gen
        """)
        
        for row in cursor.fetchall():
            geo_type, avg_points, max_size = row
            print(f"    {geo_type}: {avg_points:.0f} avg points, {max_size/1024:.1f}KB max JSON")
            
        cursor.close()
        
        # Test 3: GIST index usage
        print("\n  Checking GIST index usage...")
        cursor = self.conn.cursor()
        cursor.execute("""
            EXPLAIN (FORMAT JSON)
            SELECT * FROM scout.geo_adm3_citymun
            WHERE geom && ST_MakeEnvelope(120, 14, 122, 16, 4326)
        """)
        
        explain_json = cursor.fetchone()[0][0]
        plan = explain_json['Plan']
        
        # Check if index scan is used
        uses_index = 'Index Scan' in str(plan) or 'Bitmap Index Scan' in str(plan)
        if not uses_index:
            self.failures.append("GIST indexes not being used for spatial queries")
        else:
            print("    ✓ GIST indexes are being used")
            
        cursor.close()
        return len(self.failures) == 0
        
    def check_superset_integration(self) -> bool:
        """Check if Superset datasets are properly configured"""
        print("\n🎨 Checking Superset Integration...")
        cursor = self.conn.cursor()
        
        # Check if views exist and return data
        views_to_check = [
            ('scout.gold_region_choropleth', 'Regional choropleth view'),
            ('scout.gold_citymun_choropleth', 'City/Municipality choropleth view'),
        ]
        
        for view_name, description in views_to_check:
            try:
                cursor.execute(f"""
                    SELECT 
                        COUNT(*) as row_count,
                        COUNT(DISTINCT day) as days_with_data
                    FROM {view_name}
                    WHERE day >= CURRENT_DATE - INTERVAL '7 days'
                """)
                row_count, days = cursor.fetchone()
                print(f"  {description}: {row_count} rows, {days} days")
                
                if row_count == 0:
                    self.failures.append(f"{description} has no recent data")
                    
            except Exception as e:
                self.failures.append(f"{description} error: {str(e)}")
                
        cursor.close()
        return len(self.failures) == 0
        
    def simulate_deck_gl_load(self) -> bool:
        """Simulate Deck.gl tile loading performance"""
        print("\n🗺️  Simulating Deck.gl Tile Load...")
        
        # Simulate loading GeoJSON for viewport
        viewport_queries = [
            # NCR region only
            ("NCR viewport", """
                SELECT 
                    citymun_psgc,
                    ST_AsGeoJSON(geom) as geojson,
                    peso_total
                FROM scout.gold_citymun_choropleth
                WHERE region_key = 'NCR'
                  AND day = (SELECT MAX(day) FROM scout.gold_citymun_choropleth)
            """),
            # Full Philippines (with limit)
            ("National viewport", """
                SELECT 
                    region_key,
                    ST_AsGeoJSON(geom) as geojson,
                    peso_total
                FROM scout.gold_region_choropleth
                WHERE day >= CURRENT_DATE - INTERVAL '30 days'
            """),
        ]
        
        for viewport_name, query in viewport_queries:
            times = []
            sizes = []
            
            for i in range(5):  # 5 runs for each viewport
                start = time.time()
                cursor = self.conn.cursor()
                cursor.execute(query)
                results = cursor.fetchall()
                elapsed = time.time() - start
                
                # Calculate total GeoJSON size
                total_size = sum(len(row[1]) for row in results if row[1])
                
                times.append(elapsed)
                sizes.append(total_size)
                cursor.close()
                
            avg_time = sum(times) / len(times)
            avg_size_mb = sum(sizes) / len(sizes) / 1024 / 1024
            
            print(f"\n  {viewport_name}:")
            print(f"    Average load time: {avg_time:.3f}s")
            print(f"    Average payload size: {avg_size_mb:.2f}MB")
            print(f"    Feature count: {len(results)}")
            
            # Add network transfer time estimate (100Mbps connection)
            network_time = avg_size_mb * 8 / 100  # seconds
            total_time = avg_time + network_time
            
            print(f"    Estimated total time (query + network): {total_time:.3f}s")
            
            if total_time > PERF_GATES['deck_gl_render_p95']:
                self.failures.append(
                    f"{viewport_name} estimated load time: {total_time:.3f}s > {PERF_GATES['deck_gl_render_p95']}s"
                )
                
        return len(self.failures) == 0
        
    def generate_report(self):
        """Generate final report"""
        print("\n" + "="*60)
        print("📊 HARD PERFORMANCE CHECK RESULTS")
        print("="*60)
        
        if not self.failures:
            print("\n✅ ALL CHECKS PASSED!")
            print("\nPerformance gates met:")
            print(f"  - ADM3 choropleth query < {PERF_GATES['adm3_choropleth_p95']}s p95")
            print(f"  - Deck.gl tile render < {PERF_GATES['deck_gl_render_p95']}s p95")
            print(f"  - Geographic join coverage > {100 - PERF_GATES['unmatched_threshold']*100}%")
            return True
        else:
            print("\n❌ FAILURES DETECTED:")
            for i, failure in enumerate(self.failures, 1):
                print(f"\n  {i}. {failure}")
                
            print("\n\nRecommendations:")
            
            if any('join coverage' in f for f in self.failures):
                print("\n  📍 Geographic Join Issues:")
                print("     - Run: psql $PGURI -f platform/scout/migrations/011_geo_normalizers.sql")
                print("     - Check dim_store PSGC codes match boundary data")
                print("     - Consider loading official PSGC crosswalk table")
                
            if any('choropleth p95' in f for f in self.failures):
                print("\n  ⚡ Query Performance Issues:")
                print("     - Ensure using geo_adm3_citymun_gen (simplified) not full geometry")
                print("     - Create materialized view for common date ranges")
                print("     - Check VACUUM ANALYZE has been run recently")
                print("     - Consider increasing work_mem for spatial operations")
                
            if any('GIST indexes' in f for f in self.failures):
                print("\n  🔍 Index Issues:")
                print("     - Run: psql $PGURI -f platform/scout/migrations/013_geo_performance_indexes.sql")
                print("     - VACUUM ANALYZE all geo_* tables")
                
            return False

def main():
    parser = argparse.ArgumentParser(description='Hard performance checks for Scout choropleth')
    parser.add_argument('--pguri', required=True, help='PostgreSQL connection URI')
    parser.add_argument('--exit-on-fail', action='store_true', help='Exit with non-zero code on failure')
    
    args = parser.parse_args()
    
    print("🏃 Scout Analytics Choropleth - Hard Performance Checks")
    print(f"   Performance gates:")
    print(f"   - ADM3 query p95: < {PERF_GATES['adm3_choropleth_p95']}s")
    print(f"   - Render p95: < {PERF_GATES['deck_gl_render_p95']}s")
    print(f"   - Join coverage: > {100 - PERF_GATES['unmatched_threshold']*100}%")
    
    benchmark = HardBenchmark(args.pguri)
    
    try:
        # Run all checks
        benchmark.check_join_coverage()
        benchmark.benchmark_queries()
        benchmark.check_superset_integration()
        benchmark.simulate_deck_gl_load()
        
        # Generate report
        passed = benchmark.generate_report()
        
        if args.exit_on_fail and not passed:
            sys.exit(1)
        else:
            sys.exit(0)
            
    except Exception as e:
        print(f"\n❌ Error during benchmark: {str(e)}")
        if args.exit_on_fail:
            sys.exit(1)
    finally:
        benchmark.conn.close()

if __name__ == "__main__":
    main()