from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import httpx
import os

app = FastAPI(title="Scout API Gateway", version="1.0.0")

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

BRAND_MODEL_URL = os.getenv("BRAND_MODEL_URL", "http://brand-model:8000")

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "api-gateway"}

@app.post("/api/brand/predict")
async def predict_brand(data: dict):
    """Proxy to brand model service"""
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(f"{BRAND_MODEL_URL}/predict", json=data)
            response.raise_for_status()
            return response.json()
        except httpx.RequestError as e:
            raise HTTPException(status_code=503, detail=f"Brand model service unavailable: {str(e)}")
        except httpx.HTTPStatusError as e:
            raise HTTPException(status_code=e.response.status_code, detail=e.response.text)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)