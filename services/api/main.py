from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="AI-AAS API Service")


class HealthResponse(BaseModel):
    status: str
    service: str


@app.get("/health", response_model=HealthResponse)
async def health_check():
    return {"status": "healthy", "service": "api"}


@app.get("/")
async def root():
    return {"message": "AI-AAS Hardened Lakehouse API Service"}