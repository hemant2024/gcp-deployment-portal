"""
Main FastAPI application for GCP Deployment Portal
"""
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse

from config import get_settings
from database import init_db
from routers import auth, deployments, catalog

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)

settings = get_settings()


# ==================== Lifespan ====================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan - startup and shutdown"""
    # Startup
    logger.info("Initializing database...")
    init_db()
    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")

    yield

    # Shutdown
    logger.info(f"Shutting down {settings.APP_NAME}")


# ==================== App Creation ====================

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Enterprise GCP Deployment Portal with AI-powered approval workflows",
    lifespan=lifespan,
)

# ==================== Middleware ====================

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Trusted Host
app.add_middleware(TrustedHostMiddleware, allowed_hosts=["localhost", "127.0.0.1"])

# ==================== Exception Handlers ====================


@app.exception_handler(ValueError)
async def value_error_handler(request, exc):
    """Handle ValueError"""
    return JSONResponse(
        status_code=400,
        content={"detail": str(exc)},
    )


@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    """Handle general exceptions"""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )


# ==================== Routes ====================

@app.get("/", tags=["info"])
async def root():
    """Root endpoint"""
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running",
    }


@app.get("/health", tags=["info"])
async def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": settings.APP_NAME,
    }


@app.get("/api/docs", tags=["info"])
async def api_docs():
    """API documentation"""
    return {
        "message": "Go to /docs for interactive API documentation",
        "openapi_url": "/openapi.json",
    }


# ==================== Include Routers ====================

app.include_router(auth.router)
app.include_router(deployments.router)
app.include_router(catalog.router)


# ==================== Startup Events ====================

@app.on_event("startup")
async def startup_event():
    """Run on application startup"""
    logger.info(f"API starting at {settings.API_V1_STR}")


@app.on_event("shutdown")
async def shutdown_event():
    """Run on application shutdown"""
    logger.info("API shutdown")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.DEBUG,
        log_level="info",
    )
