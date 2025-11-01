"""
Aura API Gateway - Central entry point for all microservices
"""

import os
import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Dict, Any
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import httpx
import uvicorn

from shared.models.base import HealthCheckResponse, BaseResponse
from shared.middleware.common import (
    RequestLoggingMiddleware,
    ErrorHandlingMiddleware,
    RateLimitingMiddleware,
    SecurityHeadersMiddleware
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Service URLs from environment
SERVICE_URLS = {
    "service-desk": os.getenv("SERVICE_DESK_URL", "http://localhost:8001"),
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management"""
    logger.info("🚀 Starting Aura API Gateway")
    
    # Startup tasks
    try:
        # Initialize HTTP client
        app.state.http_client = httpx.AsyncClient(timeout=30.0)
        logger.info("HTTP client initialized")
        
        # Check service availability
        await check_services_health()
        logger.info("Service health checks completed")
        
    except Exception as e:
        logger.error(f"Startup error: {e}")
    
    yield
    
    # Cleanup tasks
    try:
        if hasattr(app.state, 'http_client'):
            await app.state.http_client.aclose()
            logger.info("HTTP client closed")
    except Exception as e:
        logger.error(f"Cleanup error: {e}")
    
    logger.info("🛑 Aura API Gateway stopped")


# Create FastAPI app
app = FastAPI(
    title="Aura API Gateway",
    description="Central API Gateway for Aura AI-Powered IT Management Suite",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Add CORS middleware (globally enabled as required)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add custom middleware
app.add_middleware(RequestLoggingMiddleware)
app.add_middleware(ErrorHandlingMiddleware)
app.add_middleware(RateLimitingMiddleware, requests_per_minute=1000)
app.add_middleware(SecurityHeadersMiddleware)


@app.get("/", response_model=BaseResponse)
async def root():
    """Root endpoint"""
    return BaseResponse(
        message="Aura API Gateway - AI-Powered IT Management Suite",
    )


@app.get("/health", response_model=HealthCheckResponse)
async def health_check():
    """Gateway health check"""
    
    dependencies = {}
    
    # Check all microservices
    for service_name, service_url in SERVICE_URLS.items():
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{service_url}/health", timeout=5.0)
                dependencies[service_name] = "healthy" if response.status_code == 200 else "unhealthy"
        except Exception:
            dependencies[service_name] = "unhealthy"
    
    overall_status = "healthy" if all(status == "healthy" for status in dependencies.values()) else "degraded"
    
    return HealthCheckResponse(
        service_name="api-gateway",
        status=overall_status,
        version="1.0.0",
        dependencies=dependencies
    )


async def check_services_health():
    """Check health of all microservices on startup"""
    for service_name, service_url in SERVICE_URLS.items():
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{service_url}/health", timeout=10.0)
                if response.status_code == 200:
                    logger.info(f"✅ {service_name} service is healthy")
                else:
                    logger.warning(f"⚠️ {service_name} service returned status {response.status_code}")
        except Exception as e:
            logger.error(f"❌ {service_name} service is unreachable: {e}")


async def proxy_request(
    request: Request,
    service_url: str,
    path: str,
    method: str = "GET"
) -> JSONResponse:
    """Proxy request to microservice"""
    
    try:
        # Prepare request data
        headers = dict(request.headers)
        # Remove host header to avoid conflicts
        headers.pop('host', None)
        
        # Get request body for POST/PUT requests
        body = None
        if method.upper() in ["POST", "PUT", "PATCH"]:
            body = await request.body()
        
        # Get query parameters
        query_params = dict(request.query_params)
        
        # Make request to microservice
        async with httpx.AsyncClient() as client:
            response = await client.request(
                method=method,
                url=f"{service_url}{path}",
                headers=headers,
                params=query_params,
                content=body,
                timeout=30.0
            )
        
        # Return response
        return JSONResponse(
            status_code=response.status_code,
            content=response.json() if response.headers.get("content-type", "").startswith("application/json") else {"data": response.text},
            headers=dict(response.headers)
        )
        
    except httpx.TimeoutException:
        logger.error(f"Timeout calling {service_url}{path}")
        raise HTTPException(
            status_code=504,
            detail={
                "code": "SERVICE_TIMEOUT",
                "message": "Service request timed out"
            }
        )
    except httpx.ConnectError:
        logger.error(f"Connection error calling {service_url}{path}")
        raise HTTPException(
            status_code=503,
            detail={
                "code": "SERVICE_UNAVAILABLE",
                "message": "Service is currently unavailable"
            }
        )
    except Exception as e:
        logger.error(f"Error proxying request to {service_url}{path}: {e}")
        raise HTTPException(
            status_code=500,
            detail={
                "code": "PROXY_ERROR",
                "message": "Error forwarding request to service"
            }
        )


# Service Desk Routes
@app.api_route("/api/v1/tickets", methods=["GET", "POST"])
async def service_desk_tickets_root(request: Request):
    """Proxy to Service Desk - Tickets API (root)"""
    return await proxy_request(
        request,
        SERVICE_URLS["service-desk"],
        "/api/v1/tickets",
        request.method
    )

@app.api_route("/api/v1/tickets/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def service_desk_tickets_with_path(request: Request, path: str):
    """Proxy to Service Desk - Tickets API (with path)"""
    return await proxy_request(
        request,
        SERVICE_URLS["service-desk"],
        f"/api/v1/tickets/{path}",
        request.method
    )

@app.api_route("/api/v1/kb", methods=["GET", "POST"])
async def service_desk_kb_root(request: Request):
    """Proxy to Service Desk - Knowledge Base API (root)"""
    return await proxy_request(
        request,
        SERVICE_URLS["service-desk"],
        "/api/v1/kb",
        request.method
    )

@app.api_route("/api/v1/kb/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def service_desk_kb_with_path(request: Request, path: str):
    """Proxy to Service Desk - Knowledge Base API (with path)"""
    return await proxy_request(
        request,
        SERVICE_URLS["service-desk"],
        f"/api/v1/kb/{path}",
        request.method
    )

@app.api_route("/api/v1/chatbot/{path:path}", methods=["POST"])
async def service_desk_chatbot(request: Request, path: str):
    """Proxy to Service Desk - Chatbot API"""
    return await proxy_request(
        request,
        SERVICE_URLS["service-desk"],
        f"/api/v1/chatbot/{path}",
        request.method
    )

@app.api_route("/api/v1/dashboard", methods=["GET"])
async def service_desk_dashboard_root(request: Request):
    """Proxy to Service Desk - Dashboard API (root)"""
    return await proxy_request(
        request,
        SERVICE_URLS["service-desk"],
        "/api/v1/dashboard",
        request.method
    )

@app.api_route("/api/v1/dashboard/{path:path}", methods=["GET"])
async def service_desk_dashboard_with_path(request: Request, path: str):
    """Proxy to Service Desk - Dashboard API (with path)"""
    return await proxy_request(
        request,
        SERVICE_URLS["service-desk"],
        f"/api/v1/dashboard/{path}",
        request.method
    )


# Aggregated endpoints
@app.get("/api/v1/services/status")
async def get_all_services_status():
    """Get status of all microservices"""
    
    services_status = {}
    
    for service_name, service_url in SERVICE_URLS.items():
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{service_url}/health", timeout=5.0)
                if response.status_code == 200:
                    services_status[service_name] = {
                        "status": "healthy",
                        "response_time": response.elapsed.total_seconds(),
                        "details": response.json()
                    }
                else:
                    services_status[service_name] = {
                        "status": "unhealthy",
                        "error": f"HTTP {response.status_code}"
                    }
        except Exception as e:
            services_status[service_name] = {
                "status": "error",
                "error": str(e)
            }
    
    return BaseResponse(
        message="Services status retrieved successfully",
        data=services_status
    )


@app.get("/api/v1/docs/combined")
async def get_combined_documentation():
    """Get combined API documentation from all services"""
    
    docs = {}
    
    for service_name, service_url in SERVICE_URLS.items():
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{service_url}/openapi.json", timeout=10.0)
                if response.status_code == 200:
                    docs[service_name] = response.json()
        except Exception as e:
            logger.error(f"Error fetching docs from {service_name}: {e}")
            docs[service_name] = {"error": str(e)}
    
    return {
        "title": "Aura API Documentation",
        "description": "Combined API documentation for all Aura microservices",
        "version": "1.0.0",
        "services": docs
    }


if __name__ == "__main__":
    # Get configuration from environment
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    debug = os.getenv("DEBUG", "false").lower() == "true"
    
    # Run the application
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=debug,
        log_level="info",
        access_log=True
    )
