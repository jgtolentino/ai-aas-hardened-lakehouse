from fastapi import FastAPI
from pydantic import BaseModel
from rapidfuzz import process, fuzz
from typing import List

app = FastAPI(title="Brand Detection Service")

# Placeholder brand catalog
brand_catalog = ["Coca-Cola", "Pepsi", "Nike", "Adidas", "Apple", "Samsung"]


class BrandDetectionRequest(BaseModel):
    text: str
    threshold: float = 80.0


class BrandMatch(BaseModel):
    brand: str
    score: float


class BrandDetectionResponse(BaseModel):
    matches: List[BrandMatch]


@app.post("/detect", response_model=BrandDetectionResponse)
async def detect_brands(request: BrandDetectionRequest):
    matches = process.extract(
        request.text,
        brand_catalog,
        scorer=fuzz.partial_ratio,
        limit=5
    )
    
    filtered_matches = [
        BrandMatch(brand=match[0], score=match[1])
        for match in matches
        if match[1] >= request.threshold
    ]
    
    return {"matches": filtered_matches}


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "brand-model"}