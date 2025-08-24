"""
Brand Detection Package
Shared types and utilities for brand detection across services
"""

from .types import (
    BrandPrediction,
    PredictionRequest, 
    PredictionResponse,
    DictionaryEntry,
    BrandDictionary,
    ETLRunMetrics,
    ModelMetric
)

__version__ = "1.0.0"
__all__ = [
    "BrandPrediction",
    "PredictionRequest",
    "PredictionResponse", 
    "DictionaryEntry",
    "BrandDictionary",
    "ETLRunMetrics",
    "ModelMetric"
]