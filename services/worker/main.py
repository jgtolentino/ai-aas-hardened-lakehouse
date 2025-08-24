#!/usr/bin/env python3
"""
Worker Service
Handles background tasks: SRP updates, ML evaluation, DW refresh
"""

import asyncio
import asyncpg
import os
import logging
import json
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import aiohttp
import schedule
from prometheus_client import Counter, Histogram, Gauge, start_http_server

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus metrics
task_counter = Counter('worker_tasks_total', 'Total worker tasks', ['task_type', 'status'])
task_duration = Histogram('worker_task_duration_seconds', 'Task duration', ['task_type'])
srp_prices_gauge = Gauge('srp_prices_total', 'Total SRP prices in catalog')
ml_accuracy_gauge = Gauge('ml_model_accuracy', 'ML model accuracy', ['model_name'])
dw_rows_gauge = Gauge('dw_table_rows', 'DW table row counts', ['table_name'])

class WorkerService:
    def __init__(self, db_url: str):
        self.db_url = db_url
        self.pool = None
        
    async def connect(self):
        """Initialize database connection pool"""
        self.pool = await asyncpg.create_pool(self.db_url)
        logger.info("Database pool created")
        
    async def disconnect(self):
        """Close database connections"""
        if self.pool:
            await self.pool.close()
            logger.info("Database pool closed")
    
    @task_duration.labels(task_type='srp_update').time()
    async def update_srp_catalog(self):
        """Fetch latest SRP data from manufacturers"""
        logger.info("Starting SRP catalog update")
        try:
            # Simulated SRP data fetch (replace with actual manufacturer APIs)
            srp_updates = [
                {
                    'source': 'unilever_api',
                    'brand': 'Dove',
                    'product': 'Dove Beauty Bar 135g',
                    'gtin': '4800888141019',
                    'srp': 65.00,
                    'currency': 'PHP',
                    'effective_date': datetime.now().date().isoformat()
                },
                {
                    'source': 'pg_api', 
                    'brand': 'Safeguard',
                    'product': 'Safeguard Pure White 135g',
                    'gtin': '4902430641340',
                    'srp': 48.00,
                    'currency': 'PHP',
                    'effective_date': datetime.now().date().isoformat()
                },
                {
                    'source': 'nestle_api',
                    'brand': 'Nescafe',
                    'product': 'Nescafe Classic 100g',
                    'gtin': '4800361381468',
                    'srp': 185.00,
                    'currency': 'PHP',
                    'effective_date': datetime.now().date().isoformat()
                }
            ]
            
            # Insert updates to database
            async with self.pool.acquire() as conn:
                for srp in srp_updates:
                    await conn.execute("""
                        INSERT INTO reference.srp_prices 
                        (source, brand, product, gtin, srp, currency, effective_date)
                        VALUES ($1, $2, $3, $4, $5, $6, $7::date)
                        ON CONFLICT (source, gtin, effective_date) DO UPDATE
                        SET srp = EXCLUDED.srp,
                            product = EXCLUDED.product,
                            brand = EXCLUDED.brand
                    """, 
                    srp['source'], srp['brand'], srp['product'], srp['gtin'],
                    srp['srp'], srp['currency'], srp['effective_date']
                    )
                
                # Update metrics
                count = await conn.fetchval("SELECT COUNT(*) FROM reference.v_latest_srp")
                srp_prices_gauge.set(count)
                
            task_counter.labels(task_type='srp_update', status='success').inc()
            logger.info(f"SRP catalog updated with {len(srp_updates)} items")
            
        except Exception as e:
            task_counter.labels(task_type='srp_update', status='error').inc()
            logger.error(f"SRP update failed: {e}")
    
    @task_duration.labels(task_type='ml_evaluation').time()
    async def evaluate_ml_models(self):
        """Compute ML model performance metrics"""
        logger.info("Starting ML model evaluation")
        try:
            async with self.pool.acquire() as conn:
                # Compute daily metrics
                await conn.execute("SELECT ml.compute_daily_metrics()")
                
                # Get accuracy for each model
                results = await conn.fetch("""
                    SELECT 
                        model_name,
                        COUNT(*) as total_predictions,
                        SUM(CASE WHEN p.predicted_class = l.true_class THEN 1 ELSE 0 END)::float / COUNT(*) as accuracy
                    FROM ml.prediction_events p
                    LEFT JOIN ml.prediction_labels l ON p.id = l.prediction_id
                    WHERE l.true_class IS NOT NULL
                    AND p.timestamp >= NOW() - INTERVAL '24 hours'
                    GROUP BY model_name
                """)
                
                for row in results:
                    ml_accuracy_gauge.labels(model_name=row['model_name']).set(row['accuracy'])
                    logger.info(f"Model {row['model_name']}: {row['accuracy']:.2%} accuracy")
                
                # Update calibration bins
                await conn.execute("""
                    INSERT INTO ml.calibration_bins (model_name, model_version, bin_lower, bin_upper, 
                                                     mean_predicted_confidence, fraction_positive, bin_count)
                    SELECT 
                        model_name,
                        model_version,
                        FLOOR(confidence * 10) / 10.0 as bin_lower,
                        FLOOR(confidence * 10) / 10.0 + 0.1 as bin_upper,
                        AVG(confidence) as mean_predicted_confidence,
                        AVG(CASE WHEN l.true_class = p.predicted_class THEN 1.0 ELSE 0.0 END) as fraction_positive,
                        COUNT(*) as bin_count
                    FROM ml.prediction_events p
                    JOIN ml.prediction_labels l ON p.id = l.prediction_id
                    WHERE p.timestamp >= NOW() - INTERVAL '7 days'
                    GROUP BY model_name, model_version, FLOOR(confidence * 10) / 10.0
                    ON CONFLICT (model_name, model_version, bin_lower) DO UPDATE
                    SET mean_predicted_confidence = EXCLUDED.mean_predicted_confidence,
                        fraction_positive = EXCLUDED.fraction_positive,
                        bin_count = EXCLUDED.bin_count,
                        updated_at = NOW()
                """)
                
            task_counter.labels(task_type='ml_evaluation', status='success').inc()
            logger.info("ML model evaluation completed")
            
        except Exception as e:
            task_counter.labels(task_type='ml_evaluation', status='error').inc()
            logger.error(f"ML evaluation failed: {e}")
    
    @task_duration.labels(task_type='dw_refresh').time()
    async def refresh_dw_tables(self):
        """Refresh data warehouse aggregations"""
        logger.info("Starting DW refresh")
        try:
            async with self.pool.acquire() as conn:
                # Refresh fact tables
                tables = [
                    ('dw.fact_transactions', 'scout.gold_transactions'),
                    ('dw.fact_transaction_items', 'scout.gold_transaction_items'),
                    ('dw.fact_monthly_performance', None)  # Computed from fact_transactions
                ]
                
                for target_table, source_table in tables:
                    if source_table:
                        # Simple ETL from gold to DW (implement proper incremental logic)
                        logger.info(f"Refreshing {target_table} from {source_table}")
                        # This is a placeholder - implement actual ETL logic
                        
                    # Get row count
                    count = await conn.fetchval(f"SELECT COUNT(*) FROM {target_table}")
                    dw_rows_gauge.labels(table_name=target_table).set(count)
                    logger.info(f"{target_table}: {count} rows")
                
                # Update dimension tables
                dimensions = ['dim_date', 'dim_time', 'dim_store', 'dim_product', 'dim_customer']
                for dim in dimensions:
                    count = await conn.fetchval(f"SELECT COUNT(*) FROM dw.{dim}")
                    dw_rows_gauge.labels(table_name=f'dw.{dim}').set(count)
                
            task_counter.labels(task_type='dw_refresh', status='success').inc()
            logger.info("DW refresh completed")
            
        except Exception as e:
            task_counter.labels(task_type='dw_refresh', status='error').inc()
            logger.error(f"DW refresh failed: {e}")
    
    async def run_scheduled_tasks(self):
        """Run tasks on schedule"""
        # SRP updates - every 6 hours
        schedule.every(6).hours.do(lambda: asyncio.create_task(self.update_srp_catalog()))
        
        # ML evaluation - every hour
        schedule.every(1).hours.do(lambda: asyncio.create_task(self.evaluate_ml_models()))
        
        # DW refresh - daily at 2 AM
        schedule.every().day.at("02:00").do(lambda: asyncio.create_task(self.refresh_dw_tables()))
        
        # Run initial tasks
        await self.update_srp_catalog()
        await self.evaluate_ml_models()
        await self.refresh_dw_tables()
        
        # Keep running scheduled tasks
        while True:
            schedule.run_pending()
            await asyncio.sleep(60)  # Check every minute

async def main():
    # Configuration
    db_url = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@localhost:5434/suqi-db')
    metrics_port = int(os.getenv('METRICS_PORT', '9092'))
    
    # Start Prometheus metrics server
    start_http_server(metrics_port)
    logger.info(f"Metrics server started on port {metrics_port}")
    
    # Initialize worker
    worker = WorkerService(db_url)
    await worker.connect()
    
    try:
        # Run scheduled tasks
        await worker.run_scheduled_tasks()
    except KeyboardInterrupt:
        logger.info("Shutting down worker...")
    finally:
        await worker.disconnect()

if __name__ == '__main__':
    asyncio.run(main())