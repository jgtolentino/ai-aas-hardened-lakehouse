#!/usr/bin/env python3
"""
Brand Detection ETL Pipeline
Medallion Architecture: Bronze → Silver → Gold → Platinum/AI
"""

import typer
import pandas as pd
import asyncpg
import asyncio
import logging
import os
import yaml
import json
import hashlib
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional

app = typer.Typer()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/appdb")

class BrandETL:
    def __init__(self, db_url: str):
        self.db_url = db_url
        self.connection = None
        
    async def connect(self):
        """Connect to database"""
        self.connection = await asyncpg.connect(self.db_url)
        logger.info("Connected to database")
        
    async def disconnect(self):
        """Disconnect from database"""
        if self.connection:
            await self.connection.close()
            logger.info("Disconnected from database")
            
    async def bronze_layer(self, input_dir: str) -> int:
        """Ingest raw data into bronze layer"""
        logger.info(f"Processing bronze layer from {input_dir}")
        
        csv_files = list(Path(input_dir).glob("*.csv"))
        total_rows = 0
        
        for csv_file in csv_files:
            logger.info(f"Processing {csv_file}")
            df = pd.read_csv(csv_file)
            
            for _, row in df.iterrows():
                # Convert row to JSON payload
                payload = row.to_dict()
                
                # Generate hash for deduplication
                payload_str = json.dumps(payload, sort_keys=True)
                event_hash = hashlib.sha256(payload_str.encode()).digest()
                
                await self.connection.execute("""
                    INSERT INTO scout.bronze_raw_events 
                    (payload, source_file, event_hash)
                    VALUES ($1::jsonb, $2, $3)
                    ON CONFLICT (event_hash) DO NOTHING
                """, json.dumps(payload), str(csv_file), event_hash)
                
                total_rows += 1
                
        logger.info(f"Bronze layer: Processed {total_rows} rows")
        return total_rows
        
    async def silver_layer(self) -> int:
        """Normalize data from bronze to silver"""
        logger.info("Processing silver layer")
        
        # Process raw events into normalized format
        result = await self.connection.execute("""
            INSERT INTO scout.silver_normalized_events 
            (text_input, source_file, bronze_id, normalized_at)
            SELECT 
                payload->>'text' as text_input,
                source_file,
                id as bronze_id,
                NOW() as normalized_at
            FROM scout.bronze_raw_events 
            WHERE id NOT IN (
                SELECT bronze_id FROM scout.silver_normalized_events 
                WHERE bronze_id IS NOT NULL
            )
            AND payload ? 'text'
        """)
        
        # Extract row count from result
        rows_affected = int(result.split()[-1]) if result.startswith('INSERT') else 0
        logger.info(f"Silver layer: Processed {rows_affected} rows")
        return rows_affected
        
    async def gold_layer(self, dictionary_path: str) -> int:
        """Generate brand predictions from silver to gold"""
        logger.info("Processing gold layer")
        
        # Load dictionary and get version
        dict_version = await self._load_dictionary(dictionary_path)
        
        # Get unprocessed silver records
        records = await self.connection.fetch("""
            SELECT id, text_input 
            FROM scout.silver_normalized_events 
            WHERE id NOT IN (
                SELECT silver_id FROM scout.gold_brand_predictions 
                WHERE silver_id IS NOT NULL
            )
        """)
        
        total_predictions = 0
        
        # Import brand matcher
        import sys
        sys.path.append(os.path.dirname(__file__))
        from brand_matcher import BrandMatcher
        
        matcher = BrandMatcher(dictionary_path)
        
        for record in records:
            text = record['text_input']
            if not text:
                continue
                
            # Generate prediction
            prediction = matcher.predict(text)
            
            # Insert into gold layer
            await self.connection.execute("""
                INSERT INTO scout.gold_brand_predictions 
                (silver_id, text_input, brand, confidence, model_version, dictionary_version)
                VALUES ($1, $2, $3, $4, $5, $6)
            """, 
            record['id'],
            text, 
            prediction['brand'],
            prediction['confidence'],
            prediction['model_version'],
            prediction['dictionary_version']
            )
            
            total_predictions += 1
            
        logger.info(f"Gold layer: Generated {total_predictions} predictions")
        return total_predictions
        
    async def _load_dictionary(self, dictionary_path: str) -> str:
        """Load and version dictionary"""
        try:
            with open(dictionary_path, 'r') as f:
                dictionary_data = yaml.safe_load(f)
                
            # Calculate checksum
            dict_str = json.dumps(dictionary_data, sort_keys=True)
            checksum = hashlib.sha256(dict_str.encode()).hexdigest()
            
            # Insert/update dictionary version
            await self.connection.execute("""
                INSERT INTO scout.data_dictionary_versions 
                (version, checksum, dictionary_data, created_at)
                VALUES ($1, $2, $3::jsonb, NOW())
                ON CONFLICT (version) DO UPDATE
                SET checksum = $2, dictionary_data = $3::jsonb, created_at = NOW()
            """, checksum[:8], checksum, json.dumps(dictionary_data))
            
            return checksum[:8]
            
        except Exception as e:
            logger.error(f"Dictionary loading failed: {e}")
            return "error"
            
    async def log_run_metrics(self, bronze_rows: int, silver_rows: int, gold_rows: int, status: str = "success"):
        """Log ETL run metrics"""
        await self.connection.execute("""
            INSERT INTO scout.prediction_runs 
            (bronze_rows, silver_rows, gold_rows, status, run_at)
            VALUES ($1, $2, $3, $4, NOW())
        """, bronze_rows, silver_rows, gold_rows, status)
        
        # Log individual metrics
        metrics = [
            ("etl_rows_bronze", bronze_rows),
            ("etl_rows_silver", silver_rows),
            ("etl_rows_gold", gold_rows)
        ]
        
        for metric_name, value in metrics:
            await self.connection.execute("""
                INSERT INTO scout.model_metrics (name, value, labels)
                VALUES ($1, $2, $3::jsonb)
            """, metric_name, value, json.dumps({"run_id": str(datetime.now().timestamp())}))

@app.command()
def run_all(
    input_dir: str = typer.Option("data/incoming", help="Input directory for CSV files"),
    dictionary: str = typer.Option("packages/shared/dictionaries/brands.yaml", help="Brand dictionary path")
):
    """Run complete ETL pipeline: Bronze → Silver → Gold"""
    async def _run():
        etl = BrandETL(DATABASE_URL)
        
        try:
            await etl.connect()
            
            # Run pipeline
            bronze_rows = await etl.bronze_layer(input_dir)
            silver_rows = await etl.silver_layer()
            gold_rows = await etl.gold_layer(dictionary)
            
            # Log metrics
            await etl.log_run_metrics(bronze_rows, silver_rows, gold_rows)
            
            typer.echo(f"ETL Complete:")
            typer.echo(f"  Bronze: {bronze_rows} rows")
            typer.echo(f"  Silver: {silver_rows} rows") 
            typer.echo(f"  Gold: {gold_rows} rows")
            
        except Exception as e:
            logger.error(f"ETL failed: {e}")
            await etl.log_run_metrics(0, 0, 0, "failed")
            raise
        finally:
            await etl.disconnect()
            
    asyncio.run(_run())

@app.command()
def bronze_only(
    input_dir: str = typer.Option("data/incoming", help="Input directory for CSV files")
):
    """Run only bronze layer ingestion"""
    async def _run():
        etl = BrandETL(DATABASE_URL)
        await etl.connect()
        rows = await etl.bronze_layer(input_dir)
        await etl.disconnect()
        typer.echo(f"Bronze layer: {rows} rows processed")
        
    asyncio.run(_run())

@app.command()
def silver_only():
    """Run only silver layer normalization"""
    async def _run():
        etl = BrandETL(DATABASE_URL)
        await etl.connect()
        rows = await etl.silver_layer()
        await etl.disconnect()
        typer.echo(f"Silver layer: {rows} rows processed")
        
    asyncio.run(_run())

@app.command()
def gold_only(
    dictionary: str = typer.Option("packages/shared/dictionaries/brands.yaml", help="Brand dictionary path")
):
    """Run only gold layer predictions"""
    async def _run():
        etl = BrandETL(DATABASE_URL)
        await etl.connect()
        rows = await etl.gold_layer(dictionary)
        await etl.disconnect()
        typer.echo(f"Gold layer: {rows} predictions generated")
        
    asyncio.run(_run())

if __name__ == "__main__":
    app()