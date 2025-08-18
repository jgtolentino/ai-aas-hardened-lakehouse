from pydantic import BaseModel
from typing import Dict, List, Optional, Any
from datetime import datetime

class BrandPrediction(BaseModel):
    brand: str
    confidence: float
    model_version: str
    dictionary_version: str
    timestamp: Optional[datetime] = None

class PredictionRequest(BaseModel):
    text: str
    context: Optional[Dict[str, Any]] = {}

class PredictionResponse(BaseModel):
    brand: str
    confidence: float
    model_version: str
    dictionary_version: str
    timestamp: str

class DictionaryEntry(BaseModel):
    regex: str
    weight: float
    category: Optional[str] = None
    aliases: Optional[List[str]] = []

class BrandDictionary(BaseModel):
    version: str
    description: Optional[str] = None
    brands: Dict[str, DictionaryEntry]

class ETLRunMetrics(BaseModel):
    run_id: str
    bronze_rows: int
    silver_rows: int
    gold_rows: int
    status: str
    run_at: datetime
    duration_seconds: Optional[float] = None

class ModelMetric(BaseModel):
    name: str
    value: float
    labels: Optional[Dict[str, str]] = {}
    timestamp: Optional[datetime] = None