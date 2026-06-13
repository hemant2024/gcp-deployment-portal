"""
GCP Deployment Portal — FastAPI Backend
"""
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import asyncio
import structlog
import os
from dotenv import load_dotenv

load_dotenv()

logger = structlog.get_logger()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events."""
    logger.info("startup", service="gcp-portal-api", version="1.0.0-local")
    yield
    logger.info("shutdown", service="gcp-portal-api")

app = FastAPI(
    title="GCP Deployment Portal API",
    description="Enterprise-grade GCP workload deployment platform",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
    lifespan=lifespan
)

# CORS Middleware
origins = os.getenv("CORS_ORIGINS", '["http://localhost:3000"]')
import json
app.add_middleware(
    CORSMiddleware,
    allow_origins=json.loads(origins),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health Check
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "version": "1.0.0-local",
        "service": "gcp-deployment-portal",
        "environment": os.getenv("APP_ENV", "development")
    }

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except Exception:
                pass

manager = ConnectionManager()

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            await manager.broadcast(f"Client {client_id}: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket)

# Root redirect
@app.get("/")
async def root():
    return {"message": "GCP Deployment Portal API", "docs": "/api/docs"}

