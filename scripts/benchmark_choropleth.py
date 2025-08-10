#!/usr/bin/env python3
"""
Choropleth Performance Benchmark Script
Tests the performance of geographic queries and provides optimization recommendations
"""

import time
import json
import psycopg2
import pandas as pd
from datetime import datetime, timedelta
import matplotlib.pyplot as plt
import seaborn as sns
from typing import Dict, List, Tuple
import argparse

class ChoroплethBenchmark:
    def __init__(self, conn_string: str):
        self.conn = psycopg2.connect(conn_string)
        self.results = []
        
    def benchmark_query(self, name: str, query: str, params=None) -> Dict:
        """Execute a query and measure performance"""
        cursor = self.conn.cursor()
        
        # Warm up cache
        cursor.execute(query, params)
        cursor.fetchall()
        
        # Actual benchmark
        start_time = time.time()
        cursor.execute(f"EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) {query}", params)
        explain_result = cursor.fetchone()[0][0]
        end_time = time.time()
        
        # Get result count
        cursor.execute(query, params)
        results = cursor.fetchall()
        row_count = len(results)
        
        # Calculate data size
        if results and len(results[0]) > 0:
            # Estimate size of GeoJSON if present
            total_size = sum(len(str(row)) for row in results)
        else:
            total_size = 0
            
        cursor.close()
        
        return {
            'name': name,
            'execution_time': end_time - start_time,
            'planning_time': explain_result['Planning Time'],
            'execution_time_pg': explain_result['Execution Time'],
            'row_count': row_count,
            'data_size_bytes': total_size,
            'buffers_hit': explain_result['Plan'].get('Shared Hit Blocks', 0),
            'buffers_read': explain_result['Plan'].get('Shared Read Blocks', 0)
        }
    
    def run_benchmarks(self):
        """Run all benchmark tests"""
        print("🏃 Running choropleth performance benchmarks...")
        
        # Test 1: Region choropleth (last 30 days)
        self.results.append(self.benchmark_query(
            "Region Choropleth - 30 days",
            """
            SELECT 
                region_key,
                region_name,
                ST_AsGeoJSON(geom) as geojson,
                SUM(peso_total) as total_sales,
                SUM(txn_count) as total_transactions
            FROM scout.gold_region_choropleth
            WHERE day >= CURRENT_DATE - INTERVAL '30 days'
            GROUP BY region_key, region_name, geom
            """
        ))
        
        # Test 2: City/Municipality choropleth (NCR only)
        self.results.append(self.benchmark_query(
            "City Choropleth - NCR",
            """
            SELECT 
                citymun_psgc,
                citymun_name,
                ST_AsGeoJSON(geom) as geojson,
                SUM(peso_total) as total_sales
            FROM scout.gold_citymun_choropleth
            WHERE region_key = 'NCR'
              AND day >= CURRENT_DATE - INTERVAL '7 days'
            GROUP BY citymun_psgc, citymun_name, geom
            """
        ))
        
        # Test 3: All cities (stress test)
        self.results.append(self.benchmark_query(
            "City Choropleth - All Philippines",
            """
            SELECT 
                citymun_psgc,
                ST_AsGeoJSON(geom) as geojson,
                peso_total
            FROM scout.gold_citymun_choropleth
            WHERE day = (SELECT MAX(day) FROM scout.gold_citymun_choropleth)
            LIMIT 500
            """
        ))
        
        # Test 4: Spatial query (point in polygon)
        self.results.append(self.benchmark_query(
            "Point in Polygon Query",
            """
            SELECT 
                region_key,
                region_name
            FROM scout.geo_adm1_region
            WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(%s, %s), 4326))
            """,
            (121.0, 14.5)
        ))
        
        # Test 5: Date range aggregation
        self.results.append(self.benchmark_query(
            "Weekly Aggregation",
            """
            SELECT 
                region_key,
                DATE_TRUNC('week', day) as week,
                SUM(peso_total) as weekly_sales
            FROM scout.gold_region_daily
            WHERE day >= CURRENT_DATE - INTERVAL '90 days'
            GROUP BY region_key, week
            """
        ))
        
    def analyze_geometry_sizes(self):
        """Analyze geometry complexity and sizes"""
        cursor = self.conn.cursor()
        
        print("\n📏 Analyzing geometry sizes...")
        
        cursor.execute("""
            SELECT 
                'Original' as type,
                AVG(ST_NPoints(geom)) as avg_points,
                MAX(ST_NPoints(geom)) as max_points,
                AVG(LENGTH(ST_AsGeoJSON(geom))) as avg_json_size,
                MAX(LENGTH(ST_AsGeoJSON(geom))) as max_json_size
            FROM scout.geo_adm1_region
            UNION ALL
            SELECT 
                'Simplified' as type,
                AVG(ST_NPoints(geom)) as avg_points,
                MAX(ST_NPoints(geom)) as max_points,
                AVG(LENGTH(ST_AsGeoJSON(geom))) as avg_json_size,
                MAX(LENGTH(ST_AsGeoJSON(geom))) as max_json_size
            FROM scout.geo_adm1_region_gen
        """)
        
        results = cursor.fetchall()
        geometry_df = pd.DataFrame(results, columns=['Type', 'Avg Points', 'Max Points', 'Avg JSON Size', 'Max JSON Size'])
        print(geometry_df.to_string(index=False))
        
        cursor.close()
        
    def check_index_usage(self):
        """Check if indexes are being used effectively"""
        cursor = self.conn.cursor()
        
        print("\n🔍 Checking index usage...")
        
        cursor.execute("""
            SELECT 
                indexrelname,
                idx_scan,
                idx_tup_read,
                pg_size_pretty(pg_relation_size(indexrelid)) as index_size
            FROM pg_stat_user_indexes
            WHERE schemaname = 'scout'
              AND tablename LIKE 'geo_%'
              AND idx_scan > 0
            ORDER BY idx_scan DESC
            LIMIT 10
        """)
        
        results = cursor.fetchall()
        if results:
            index_df = pd.DataFrame(results, columns=['Index Name', 'Scans', 'Tuples Read', 'Size'])
            print(index_df.to_string(index=False))
        else:
            print("No index usage found - indexes may need to be created or queries optimized")
            
        cursor.close()
        
    def generate_report(self):
        """Generate performance report with recommendations"""
        print("\n📊 Performance Benchmark Results")
        print("=" * 80)
        
        # Convert results to DataFrame
        df = pd.DataFrame(self.results)
        
        # Display results
        for _, row in df.iterrows():
            print(f"\n{row['name']}:")
            print(f"  Execution Time: {row['execution_time']:.3f}s")
            print(f"  Rows Returned: {row['row_count']:,}")
            print(f"  Data Size: {row['data_size_bytes']:,} bytes")
            print(f"  Cache Hit Ratio: {row['buffers_hit']/(row['buffers_hit']+row['buffers_read']+0.01):.1%}")
        
        # Performance recommendations
        print("\n💡 Performance Recommendations:")
        print("-" * 80)
        
        slow_queries = df[df['execution_time'] > 1.0]
        if not slow_queries.empty:
            print("\n⚠️  Slow Queries Detected:")
            for _, query in slow_queries.iterrows():
                print(f"  - {query['name']} took {query['execution_time']:.2f}s")
                if query['row_count'] > 1000:
                    print(f"    Consider: Creating a materialized view for this query")
                if query['data_size_bytes'] > 1_000_000:
                    print(f"    Consider: Further simplifying geometries (current: {query['data_size_bytes']:,} bytes)")
        
        # Cache effectiveness
        avg_hit_ratio = df.apply(lambda r: r['buffers_hit']/(r['buffers_hit']+r['buffers_read']+0.01), axis=1).mean()
        if avg_hit_ratio < 0.9:
            print(f"\n⚠️  Low cache hit ratio: {avg_hit_ratio:.1%}")
            print("  Consider: Increasing shared_buffers in PostgreSQL configuration")
        
        # Large result sets
        large_results = df[df['row_count'] > 10000]
        if not large_results.empty:
            print("\n⚠️  Large Result Sets:")
            for _, query in large_results.iterrows():
                print(f"  - {query['name']} returned {query['row_count']:,} rows")
                print(f"    Consider: Pagination or aggregation at higher levels")
        
        print("\n✅ Benchmark complete!")
        
    def create_performance_plots(self, output_dir: str = '.'):
        """Create visualization plots for performance metrics"""
        df = pd.DataFrame(self.results)
        
        # Execution time chart
        plt.figure(figsize=(10, 6))
        plt.barh(df['name'], df['execution_time'])
        plt.xlabel('Execution Time (seconds)')
        plt.title('Query Execution Times')
        plt.tight_layout()
        plt.savefig(f"{output_dir}/choropleth_execution_times.png")
        plt.close()
        
        # Data size vs execution time
        plt.figure(figsize=(10, 6))
        plt.scatter(df['data_size_bytes']/1024, df['execution_time'], s=df['row_count'])
        plt.xlabel('Data Size (KB)')
        plt.ylabel('Execution Time (seconds)')
        plt.title('Data Size vs Execution Time (bubble size = row count)')
        plt.tight_layout()
        plt.savefig(f"{output_dir}/choropleth_size_vs_time.png")
        plt.close()
        
        print(f"\n📈 Performance plots saved to {output_dir}/")

def main():
    parser = argparse.ArgumentParser(description='Benchmark Scout Analytics choropleth performance')
    parser.add_argument('--host', default='localhost', help='PostgreSQL host')
    parser.add_argument('--port', default='5432', help='PostgreSQL port')
    parser.add_argument('--database', default='scout_analytics', help='Database name')
    parser.add_argument('--user', default='scout_viewer', help='Database user')
    parser.add_argument('--password', default='viewer_pass', help='Database password')
    parser.add_argument('--output-dir', default='.', help='Directory for output files')
    
    args = parser.parse_args()
    
    # Build connection string
    conn_string = f"host={args.host} port={args.port} dbname={args.database} user={args.user} password={args.password}"
    
    # Run benchmarks
    benchmark = ChoroplethBenchmark(conn_string)
    
    try:
        benchmark.run_benchmarks()
        benchmark.analyze_geometry_sizes()
        benchmark.check_index_usage()
        benchmark.generate_report()
        benchmark.create_performance_plots(args.output_dir)
    finally:
        benchmark.conn.close()

if __name__ == "__main__":
    main()