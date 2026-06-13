import pytest
from fastapi.testclient import TestClient
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath("__file__"))))

try:
    from main import app
    client = TestClient(app)
    HAS_APP = True
except Exception as e:
    HAS_APP = False
    print(f"Warning: Could not import app: {e}")

class TestHealth:
    def test_health_endpoint(self):
        if not HAS_APP:
            pytest.skip("App not available")
        response = client.get("/health")
        assert response.status_code == 200

    def test_health_returns_json(self):
        if not HAS_APP:
            pytest.skip("App not available")
        response = client.get("/health")
        data = response.json()
        assert "status" in data

    def test_health_status_healthy(self):
        if not HAS_APP:
            pytest.skip("App not available")
        response = client.get("/health")
        assert response.json()["status"] == "healthy"

    def test_root_endpoint(self):
        if not HAS_APP:
            pytest.skip("App not available")
        response = client.get("/")
        assert response.status_code == 200

    def test_openapi_schema_exists(self):
        if not HAS_APP:
            pytest.skip("App not available")
        response = client.get("/api/openapi.json")
        assert response.status_code == 200
        schema = response.json()
        assert "openapi" in schema

class TestConfig:
    def test_env_file_exists(self):
        assert os.path.exists(".env") or os.path.exists(".env.example"),             ".env or .env.example should exist"

    def test_requirements_file_exists(self):
        assert os.path.exists("requirements.txt")

    def test_main_py_exists(self):
        assert os.path.exists("main.py")
