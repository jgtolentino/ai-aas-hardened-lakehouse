#!/usr/bin/env python3
"""
Scout Analytics v5.2 - SLA Performance Measurement Script
Measures P95 performance metrics against defined SLA thresholds
"""

import argparse
import json
import os
import time
import statistics
from datetime import datetime
from typing import Dict, List, Tuple
import psycopg2
from psycopg2.extras import RealDictCursor
import requests
from urllib.parse import urlparse

# SLA Thresholds (in milliseconds)
SLA_THRESHOLDS = {
    "geo_query": 1500,
    "dashboard_kpis": 3000,
    "brand_analysis": 2000,
    "edge_health": 1000,
    "sales_trend": 2000,
    "api_response": 500,
    "dashboard_load": 3000
}

class ScoutSLAMeasurer:
    def __init__(self, db_url: str, api_url: str = None, env: str = "staging"):
        self.db_url = db_url
        self.api_url = api_url
        self.env = env
        self.results = {
            "timestamp": datetime.now().isoformat(),
            "environment": env,
            "sla_thresholds": SLA_THRESHOLDS,
            "measurements": {},
            "summary": {}
        }
        
    def connect_db(self):
        """Connect to the database"""
        return psycopg2.connect(self.db_url, cursor_factory=RealDictCursor)
        
    def measure_query_performance(self, query: str, params: tuple = None, 
                                  iterations: int = 10) -> Dict[str, float]:
        """Measure query performance over multiple iterations"""
        timings = []
        
        with self.connect_db() as conn:
            with conn.cursor() as cur:
                # Warm up
                cur.execute(query, params)
                cur.fetchall()
                
                # Actual measurements
                for _ in range(iterations):
                    start = time.perf_counter()
                    cur.execute(query, params)
                    cur.fetchall()
                    end = time.perf_counter()
                    timings.append((end - start) * 1000)  # Convert to ms
        
        return {
            "min_ms": min(timings),
            "max_ms": max(timings),
            "avg_ms": statistics.mean(timings),
            "median_ms": statistics.median(timings),
            "p95_ms": statistics.quantiles(timings, n=20)[18],  # 95th percentile
            "iterations": iterations
        }
    
    def measure_geo_query(self) -> Dict[str, float]:
        """Measure geographic boundary query performance"""
        query = """
        SELECT 
            adm2_name,
            ST_AsGeoJSON(ST_Simplify(geometry, 0.01)) as geojson
        FROM scout.geo_adm2_boundaries
        WHERE adm1_name = %s
        LIMIT 10
        """
        return self.measure_query_performance(query, ('Metro Manila',))
    
    def measure_dashboard_kpis(self) -> Dict[str, float]:
        """Measure dashboard KPI query performance"""
        query = """
        SELECT * FROM scout.get_dashboard_kpis(%s::date, %s::date)
        """
        return self.measure_query_performance(
            query, 
            ('2025-08-01', '2025-08-24')
        )
    
    def measure_brand_analysis(self) -> Dict[str, float]:
        """Measure brand analysis query performance"""
        query = """
        SELECT 
            b.brand_name,
            COUNT(DISTINCT t.transaction_id) as transaction_count,
            SUM(ti.quantity) as total_quantity,
            SUM(ti.sales_amount) as total_sales
        FROM scout.silver_transactions t
        JOIN scout.silver_transaction_items ti ON t.transaction_id = ti.transaction_id
        JOIN scout.dim_sku s ON ti.sku_id = s.sku_id
        JOIN scout.ref_brands b ON s.brand_id = b.brand_id
        WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY b.brand_name
        ORDER BY total_sales DESC
        LIMIT 20
        """
        return self.measure_query_performance(query)
    
    def measure_edge_health(self) -> Dict[str, float]:
        """Measure edge device health query performance"""
        query = """
        SELECT 
            d.device_id,
            d.device_name,
            h.connectivity_status,
            h.last_sync_at,
            h.pending_records
        FROM scout.edge_devices d
        LEFT JOIN scout.edge_health h ON d.device_id = h.device_id
        WHERE h.created_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour'
        LIMIT 100
        """
        return self.measure_query_performance(query)
    
    def measure_sales_trend(self) -> Dict[str, float]:
        """Measure sales trend query performance"""
        query = """
        SELECT * FROM scout.get_sales_trend(30, 'daily')
        """
        return self.measure_query_performance(query)
    
    def measure_api_response(self) -> Dict[str, float]:
        """Measure API response times"""
        if not self.api_url:
            return {"error": "API URL not provided"}
        
        timings = []
        endpoints = [
            "/rest/v1/rpc/get_dashboard_kpis",
            "/rest/v1/rpc/get_sales_trend",
            "/rest/v1/scout.edge_devices?limit=10"
        ]
        
        for endpoint in endpoints:
            for _ in range(5):
                start = time.perf_counter()
                try:
                    response = requests.get(
                        f"{self.api_url}{endpoint}",
                        headers={"apikey": os.environ.get("SUPABASE_ANON_KEY", "")},
                        timeout=10
                    )
                    response.raise_for_status()
                    end = time.perf_counter()
                    timings.append((end - start) * 1000)
                except Exception as e:
                    print(f"API error for {endpoint}: {e}")
        
        if timings:
            return {
                "min_ms": min(timings),
                "max_ms": max(timings),
                "avg_ms": statistics.mean(timings),
                "p95_ms": statistics.quantiles(timings, n=20)[18] if len(timings) > 20 else max(timings),
                "endpoints_tested": len(endpoints)
            }
        else:
            return {"error": "All API calls failed"}
    
    def check_sla_compliance(self, metric_name: str, p95_value: float) -> Tuple[bool, str]:
        """Check if a metric meets SLA threshold"""
        threshold = SLA_THRESHOLDS.get(metric_name, float('inf'))
        passed = p95_value <= threshold
        status = "PASS" if passed else "FAIL"
        return passed, f"{status} (P95: {p95_value:.0f}ms / SLA: {threshold}ms)"
    
    def run_all_measurements(self):
        """Run all performance measurements"""
        measurements = {
            "geo_query": self.measure_geo_query,
            "dashboard_kpis": self.measure_dashboard_kpis,
            "brand_analysis": self.measure_brand_analysis,
            "edge_health": self.measure_edge_health,
            "sales_trend": self.measure_sales_trend,
        }
        
        if self.api_url:
            measurements["api_response"] = self.measure_api_response
        
        total_tests = len(measurements)
        passed_tests = 0
        
        for name, measure_func in measurements.items():
            print(f"Measuring {name}...")
            try:
                result = measure_func()
                self.results["measurements"][name] = result
                
                if "p95_ms" in result:
                    passed, status = self.check_sla_compliance(name, result["p95_ms"])
                    result["sla_status"] = status
                    if passed:
                        passed_tests += 1
                    print(f"  → {status}")
                else:
                    print(f"  → Error: {result.get('error', 'Unknown error')}")
            except Exception as e:
                self.results["measurements"][name] = {"error": str(e)}
                print(f"  → Error: {e}")
        
        # Summary
        self.results["summary"] = {
            "total_tests": total_tests,
            "passed_tests": passed_tests,
            "failed_tests": total_tests - passed_tests,
            "compliance_percentage": (passed_tests / total_tests * 100) if total_tests > 0 else 0,
            "overall_status": "PASS" if passed_tests == total_tests else "FAIL"
        }
        
        print(f"\n{'='*50}")
        print(f"Overall SLA Compliance: {self.results['summary']['compliance_percentage']:.1f}%")
        print(f"Status: {self.results['summary']['overall_status']}")
        print(f"{'='*50}")
    
    def save_results(self, output_file: str):
        """Save results to JSON file"""
        with open(output_file, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"\nResults saved to: {output_file}")

def main():
    parser = argparse.ArgumentParser(description="Measure Scout Analytics SLA performance")
    parser.add_argument("--db-url", default=os.environ.get("DATABASE_URL"), 
                        help="Database connection URL")
    parser.add_argument("--api-url", default=os.environ.get("SUPABASE_URL"),
                        help="Supabase API URL")
    parser.add_argument("--env", default="staging", 
                        choices=["local", "staging", "production"],
                        help="Environment being tested")
    parser.add_argument("--output", default="sla_metrics.json",
                        help="Output file for results")
    
    args = parser.parse_args()
    
    if not args.db_url:
        print("Error: Database URL not provided. Set DATABASE_URL or use --db-url")
        return 1
    
    measurer = ScoutSLAMeasurer(args.db_url, args.api_url, args.env)
    
    try:
        measurer.run_all_measurements()
        measurer.save_results(args.output)
        return 0 if measurer.results["summary"]["overall_status"] == "PASS" else 1
    except Exception as e:
        print(f"Fatal error: {e}")
        return 2

if __name__ == "__main__":
    exit(main())