"""Basic health and API tests."""
import pytest
from fastapi.testclient import TestClient
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from main import app

client = TestClient(app)

def test_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "version" in data
    assert "service" in data

def test_root_endpoint():
    response = client.get("/")
    assert response.status_code == 200

def test_api_docs():
    response = client.get("/api/docs")
    assert response.status_code == 200

def test_openapi_schema():
    response = client.get("/api/openapi.json")
    assert response.status_code == 200
    schema = response.json()
    assert "openapi" in schema
    assert schema["info"]["title"] == "GCP Deployment Portal API"
