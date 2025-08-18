from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import Counter, Histogram, generate_latest
from pydantic import BaseModel
from typing import Dict, List, Optional
import asyncpg
import os
import time
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Prometheus metrics
prediction_counter = Counter('brand_predictions_total', 'Total brand predictions', ['status'])
prediction_duration = Histogram('brand_prediction_duration_seconds', 'Brand prediction duration')
api_requests = Counter('api_requests_total', 'Total API requests', ['method', 'endpoint', 'status'])

app = FastAPI(title="Brand Detection API", version="1.0.0")

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection pool
db_pool = None

class PredictionRequest(BaseModel):
    text: str
    context: Optional[Dict] = {}
    transaction_id: Optional[str] = None
    product_id: Optional[int] = None
    sku_id: Optional[int] = None
    store_id: Optional[str] = None
    region: Optional[str] = None

class PredictionResponse(BaseModel):
    brand: str
    confidence: float
    model_version: str
    dictionary_version: str
    timestamp: str
    prediction_id: Optional[int] = None

class DictionaryUpsertRequest(BaseModel):
    brands: Dict[str, Dict]
    version: str

class FeedbackRequest(BaseModel):
    prediction_id: int
    true_brand: str
    labeled_by: Optional[str] = None
    confidence_score: Optional[float] = None
    notes: Optional[str] = None

@app.on_event("startup")
async def startup():
    global db_pool
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@postgres:5432/appdb")
    db_pool = await asyncpg.create_pool(DATABASE_URL)
    logger.info("Database pool created")

@app.on_event("shutdown")
async def shutdown():
    global db_pool
    if db_pool:
        await db_pool.close()
        logger.info("Database pool closed")

@app.get("/healthz")
async def health():
    """Health check endpoint"""
    return {"status": "healthy"}

@app.get("/readyz")
async def ready():
    """Readiness check endpoint"""
    try:
        async with db_pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        return {"status": "ready"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Database not ready: {str(e)}")

@app.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest()

@app.post("/predict", response_model=PredictionResponse)
async def predict_brand(request: PredictionRequest):
    """Predict brand from text"""
    start_time = time.time()
    
    try:
        # Import brand matcher
        from brand_matcher import BrandMatcher
        matcher = BrandMatcher()
        
        # Perform prediction
        result = matcher.predict(request.text)
        
        # Log to database
        import json
        async with db_pool.acquire() as conn:
            await conn.execute("""
                INSERT INTO scout.gold_brand_predictions 
                (text_input, brand, confidence, model_version, dictionary_version, context)
                VALUES ($1, $2, $3, $4, $5, $6::jsonb)
            """, 
            request.text, 
            result['brand'], 
            result['confidence'],
            result['model_version'],
            result['dictionary_version'],
            json.dumps(request.context)
            )
            
            # Log metrics
            await conn.execute("""
                INSERT INTO scout.model_metrics (name, value, labels)
                VALUES ('prediction_count', 1, $1::jsonb)
            """, json.dumps({'brand': result['brand'], 'confidence': str(result['confidence'])}))
        
        # Update Prometheus metrics
        prediction_counter.labels(status='success').inc()
        prediction_duration.observe(time.time() - start_time)
        
        return PredictionResponse(
            brand=result['brand'],
            confidence=result['confidence'],
            model_version=result['model_version'],
            dictionary_version=result['dictionary_version'],
            timestamp=datetime.utcnow().isoformat()
        )
        
    except Exception as e:
        prediction_counter.labels(status='error').inc()
        logger.error(f"Prediction error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/dictionary/upsert")
async def upsert_dictionary(request: DictionaryUpsertRequest):
    """Update brand dictionary"""
    try:
        import hashlib
        import json
        
        # Calculate checksum
        checksum = hashlib.sha256(json.dumps(request.brands, sort_keys=True).encode()).hexdigest()
        
        async with db_pool.acquire() as conn:
            # Insert new version
            await conn.execute("""
                INSERT INTO scout.data_dictionary_versions 
                (version, checksum, dictionary_data, created_at)
                VALUES ($1, $2, $3, NOW())
                ON CONFLICT (version) DO UPDATE
                SET checksum = $2, dictionary_data = $3, created_at = NOW()
            """, request.version, checksum, request.brands)
        
        return {"status": "success", "version": request.version, "checksum": checksum}
        
    except Exception as e:
        logger.error(f"Dictionary upsert error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

# Middleware to track API metrics
@app.middleware("http")
async def track_metrics(request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    
    api_requests.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    
    return response