#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  GCP Deployment Portal — TEST SCRIPT
#  Tests: Database → Backend API → Frontend → Integration
#  Usage:
#    ./scripts/test.sh              # Run ALL tests
#    ./scripts/test.sh --db         # Database only
#    ./scripts/test.sh --api        # Backend API only
#    ./scripts/test.sh --frontend   # Frontend only
#    ./scripts/test.sh --unit       # Python unit tests only
#    ./scripts/test.sh --integration # Integration only
# ═══════════════════════════════════════════════════════════════════

# ── Colors ────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Config ────────────────────────────────────────────────────────
PROJECT_ROOT="${PROJECT_ROOT:-$HOME/projects/gcp-deployment-portal}"
BACKEND_PORT=8000
FRONTEND_PORT=3000
VITE_PORT=5173
MODE="${1:---all}"
PASS=0
FAIL=0
WARN_COUNT=0

# ── Helpers ───────────────────────────────────────────────────────
header()  { echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n  $1\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

check() {
  local label="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null 2>&1; then
    echo -e "  ${GREEN}✔${NC}  $label"
    PASS=$((PASS+1))
  else
    echo -e "  ${RED}✗${NC}  $label"
    FAIL=$((FAIL+1))
  fi
}

check_warn() {
  local label="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null 2>&1; then
    echo -e "  ${GREEN}✔${NC}  $label"
    PASS=$((PASS+1))
  else
    echo -e "  ${YELLOW}⚠${NC}  $label (optional)"
    WARN_COUNT=$((WARN_COUNT+1))
  fi
}

# ── Banner ────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║     GCP Enterprise Deployment Portal — Test Suite     ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Mode: $MODE"
echo "  Project: $PROJECT_ROOT"
echo ""

# ═════════════════════════════════════════════════════════════════
# TEST SUITE 1 — Database
# ═════════════════════════════════════════════════════════════════
run_db_tests() {
  header "TEST SUITE 1 — Database & Infrastructure"

  # Docker checks
  check "Docker daemon is running" \
    "docker info"

  check "docker-compose.yml exists" \
    "test -f $PROJECT_ROOT/docker-compose.yml"

  check "PostgreSQL container running" \
    "docker compose -f $PROJECT_ROOT/docker-compose.yml ps postgres 2>/dev/null | grep -q 'Up'"

  check "PostgreSQL accepting connections" \
    "PGPASSWORD=portal123 psql -h localhost -U portal -d gcp_portal -c 'SELECT 1' -t"

  check "Redis container running" \
    "docker compose -f $PROJECT_ROOT/docker-compose.yml ps redis 2>/dev/null | grep -q 'Up'"

  check "Redis accepting connections" \
    "redis-cli -h localhost ping | grep -q PONG"

  check "Redis write and read" \
    "redis-cli -h localhost SET test_key test_val && redis-cli -h localhost GET test_key | grep -q test_val"

  # Database table checks
  echo ""
  echo -e "  ${BOLD}Database Tables:${NC}"

  for TABLE in users gcp_projects deployment_requests approval_steps \
               resource_inventory audit_log cost_records ai_sessions; do
    check "Table exists: $TABLE" \
      "PGPASSWORD=portal123 psql -h localhost -U portal -d gcp_portal \
       -t -c \"SELECT 1 FROM information_schema.tables \
               WHERE table_name='$TABLE'\" | grep -q 1"
  done

  # Seed data checks
  echo ""
  echo -e "  ${BOLD}Seed Data:${NC}"

  check "Default users seeded" \
    "PGPASSWORD=portal123 psql -h localhost -U portal -d gcp_portal \
     -t -c 'SELECT COUNT(*) FROM users' | grep -qE '[1-9]'"

  check "GCP projects seeded" \
    "PGPASSWORD=portal123 psql -h localhost -U portal -d gcp_portal \
     -t -c 'SELECT COUNT(*) FROM gcp_projects' | grep -qE '[1-9]'"

  check "cloud_admin user exists" \
    "PGPASSWORD=portal123 psql -h localhost -U portal -d gcp_portal \
     -t -c \"SELECT 1 FROM users WHERE role='cloud_admin'\" | grep -q 1"

  check_warn "pgAdmin accessible" \
    "curl -sf http://localhost:5050"

  check_warn "MailHog accessible" \
    "curl -sf http://localhost:8025"
}

# ═════════════════════════════════════════════════════════════════
# TEST SUITE 2 — Backend API
# ═════════════════════════════════════════════════════════════════
run_api_tests() {
  header "TEST SUITE 2 — FastAPI Backend"

  # File checks
  check "backend/main.py exists" \
    "test -f $PROJECT_ROOT/backend/main.py"

  check "backend/requirements.txt exists" \
    "test -f $PROJECT_ROOT/backend/requirements.txt"

  check "backend/.env exists" \
    "test -f $PROJECT_ROOT/backend/.env"

  check "Python venv exists" \
    "test -d $PROJECT_ROOT/backend/venv"

  # Python import checks
  echo ""
  echo -e "  ${BOLD}Python Imports:${NC}"

  cd "$PROJECT_ROOT/backend"
  [ -d "venv" ] && source venv/bin/activate &>/dev/null 2>&1 || true

  for PKG in fastapi uvicorn sqlalchemy asyncpg redis anthropic pydantic; do
    check "import $PKG" \
      "python3 -c 'import $PKG'"
  done

  check "import google.cloud.storage" \
    "python3 -c 'import google.cloud.storage'"

  # Live API checks
  echo ""
  echo -e "  ${BOLD}Live API Endpoints:${NC}"

  check "Backend is running on port $BACKEND_PORT" \
    "curl -sf http://localhost:$BACKEND_PORT/health"

  check "GET /health returns 200" \
    "curl -sf -o /dev/null -w '%{http_code}' \
     http://localhost:$BACKEND_PORT/health | grep -q 200"

  check "Health response has status:healthy" \
    "curl -sf http://localhost:$BACKEND_PORT/health | grep -q healthy"

  check "Health response has version field" \
    "curl -sf http://localhost:$BACKEND_PORT/health | grep -q version"

  check "GET / returns 200" \
    "curl -sf -o /dev/null -w '%{http_code}' \
     http://localhost:$BACKEND_PORT/ | grep -q 200"

  check "GET /api/docs returns 200" \
    "curl -sf -o /dev/null -w '%{http_code}' \
     http://localhost:$BACKEND_PORT/api/docs | grep -q 200"

  check "GET /api/openapi.json returns valid JSON" \
    "curl -sf http://localhost:$BACKEND_PORT/api/openapi.json | python3 -c 'import sys,json; json.load(sys.stdin)'"

  check "OpenAPI title matches portal" \
    "curl -sf http://localhost:$BACKEND_PORT/api/openapi.json | grep -qi 'gcp'"

  check "CORS header present" \
    "curl -sf -H 'Origin: http://localhost:3000' \
     http://localhost:$BACKEND_PORT/health -I 2>&1 | grep -qi 'access-control'"

  # Response time check
  RESPONSE_MS=$(curl -sf -o /dev/null -w '%{time_total}' \
    http://localhost:$BACKEND_PORT/health 2>/dev/null | \
    awk '{printf "%.0f", $1*1000}' 2>/dev/null || echo "999")

  if [ "$RESPONSE_MS" -lt 500 ] 2>/dev/null; then
    echo -e "  ${GREEN}✔${NC}  API response time: ${RESPONSE_MS}ms (< 500ms)"
    PASS=$((PASS+1))
  else
    echo -e "  ${YELLOW}⚠${NC}  API response time: ${RESPONSE_MS}ms (slow)"
    WARN_COUNT=$((WARN_COUNT+1))
  fi

  check_warn "WebSocket endpoint exists" \
    "curl -sf http://localhost:$BACKEND_PORT/ws/test \
     -H 'Upgrade: websocket' \
     -H 'Connection: Upgrade' 2>&1 | grep -qiE '101|websocket|upgrade'"
}

# ═════════════════════════════════════════════════════════════════
# TEST SUITE 3 — Frontend
# ═════════════════════════════════════════════════════════════════
run_frontend_tests() {
  header "TEST SUITE 3 — React Frontend"

  # File checks
  check "frontend/package.json exists" \
    "test -f $PROJECT_ROOT/frontend/package.json"

  check "frontend/src/App.tsx exists" \
    "test -f $PROJECT_ROOT/frontend/src/App.tsx"

  check "node_modules installed" \
    "test -d $PROJECT_ROOT/frontend/node_modules"

  check ".env.local exists" \
    "test -f $PROJECT_ROOT/frontend/.env.local"

  # App.tsx content checks
  echo ""
  echo -e "  ${BOLD}App.tsx Content:${NC}"

  check "App.tsx has GCP Portal content" \
    "grep -q 'GCP' $PROJECT_ROOT/frontend/src/App.tsx"

  check "App.tsx has Dashboard page" \
    "grep -q 'dashboard' $PROJECT_ROOT/frontend/src/App.tsx"

  check "App.tsx has AI Agent page" \
    "grep -q 'ai-agent' $PROJECT_ROOT/frontend/src/App.tsx"

  check "App.tsx has deploy-gce page" \
    "grep -q 'deploy-gce' $PROJECT_ROOT/frontend/src/App.tsx"

  check "App.tsx has deploy-gke page" \
    "grep -q 'deploy-gke' $PROJECT_ROOT/frontend/src/App.tsx"

  # Detect framework
  if grep -q '"vite"' "$PROJECT_ROOT/frontend/package.json" 2>/dev/null; then
    ACTIVE_PORT=$VITE_PORT
  else
    ACTIVE_PORT=$FRONTEND_PORT
  fi

  # Live frontend checks
  echo ""
  echo -e "  ${BOLD}Live Frontend:${NC}"

  check "Frontend is running on port $ACTIVE_PORT" \
    "curl -sf http://localhost:$ACTIVE_PORT"

  check "Frontend returns HTML" \
    "curl -sf http://localhost:$ACTIVE_PORT | grep -qi '<!DOCTYPE html>'"

  check "Frontend has React root element" \
    "curl -sf http://localhost:$ACTIVE_PORT | grep -qi 'root'"

  # Env file content check
  echo ""
  echo -e "  ${BOLD}Environment Config:${NC}"

  if grep -q '"vite"' "$PROJECT_ROOT/frontend/package.json" 2>/dev/null; then
    check ".env.local has VITE_API_URL" \
      "grep -q 'VITE_API_URL' $PROJECT_ROOT/frontend/.env.local"
    check "API URL points to backend" \
      "grep 'VITE_API_URL' $PROJECT_ROOT/frontend/.env.local | grep -q '$BACKEND_PORT'"
  else
    check ".env.local has REACT_APP_API_URL" \
      "grep -q 'REACT_APP_API_URL' $PROJECT_ROOT/frontend/.env.local"
    check "API URL points to backend" \
      "grep 'REACT_APP_API_URL' $PROJECT_ROOT/frontend/.env.local | grep -q '$BACKEND_PORT'"
  fi

  # npm test (non-blocking)
  echo ""
  echo -e "  ${BOLD}npm Tests:${NC}"
  check_warn "npm test passes" \
    "cd $PROJECT_ROOT/frontend && npm test -- --watchAll=false --passWithNoTests 2>/dev/null"
}

# ═════════════════════════════════════════════════════════════════
# TEST SUITE 4 — Python Unit Tests
# ═════════════════════════════════════════════════════════════════
run_unit_tests() {
  header "TEST SUITE 4 — Python Unit Tests"

  cd "$PROJECT_ROOT/backend"
  [ -d "venv" ] && source venv/bin/activate &>/dev/null 2>&1 || true

  check "pytest is installed" \
    "python3 -m pytest --version"

  # Create basic test if none exist
  if [ ! -f "tests/unit/test_health.py" ]; then
    mkdir -p tests/unit tests/api
    cat > tests/unit/test_health.py << 'TESTEOF'
"""Basic health check tests for GCP Portal API."""
import pytest
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_health_returns_200():
    r = client.get("/health")
    assert r.status_code == 200

def test_health_has_status_healthy():
    r = client.get("/health")
    assert r.json()["status"] == "healthy"

def test_health_has_version():
    r = client.get("/health")
    assert "version" in r.json()

def test_root_returns_200():
    r = client.get("/")
    assert r.status_code == 200

def test_api_docs_accessible():
    r = client.get("/api/docs")
    assert r.status_code == 200

def test_openapi_json_valid():
    r = client.get("/api/openapi.json")
    assert r.status_code == 200
    data = r.json()
    assert "openapi" in data
    assert "info" in data
TESTEOF
    touch tests/__init__.py tests/unit/__init__.py tests/api/__init__.py
  fi

  check "Unit test file exists" \
    "test -f $PROJECT_ROOT/backend/tests/unit/test_health.py"

  check "pytest unit tests pass" \
    "cd $PROJECT_ROOT/backend && python3 -m pytest tests/unit/ -v --tb=short -q"

  # Show test coverage
  check_warn "Coverage report generated" \
    "cd $PROJECT_ROOT/backend && python3 -m pytest tests/ \
     --cov=. --cov-report=term-missing -q --no-header 2>/dev/null"
}

# ═════════════════════════════════════════════════════════════════
# TEST SUITE 5 — Integration
# ═════════════════════════════════════════════════════════════════
run_integration_tests() {
  header "TEST SUITE 5 — Integration Tests"

  # Backend ↔ Database
  echo -e "  ${BOLD}Backend ↔ Database:${NC}"

  check "Backend can reach PostgreSQL" \
    "cd $PROJECT_ROOT/backend && source venv/bin/activate &>/dev/null 2>&1; \
     python3 -c \"
import asyncio, asyncpg
async def t():
    c = await asyncpg.connect('postgresql://portal:portal123@localhost:5432/gcp_portal')
    r = await c.fetchval('SELECT COUNT(*) FROM users')
    await c.close()
    assert r >= 0
asyncio.run(t())
\""

  check "Backend can reach Redis" \
    "cd $PROJECT_ROOT/backend && source venv/bin/activate &>/dev/null 2>&1; \
     python3 -c \"
import redis
r = redis.Redis(host='localhost', port=6379, db=0)
assert r.ping()
\""

  # Frontend ↔ Backend
  echo ""
  echo -e "  ${BOLD}Frontend ↔ Backend:${NC}"

  if grep -q '"vite"' "$PROJECT_ROOT/frontend/package.json" 2>/dev/null; then
    ACTIVE_PORT=$VITE_PORT
  else
    ACTIVE_PORT=$FRONTEND_PORT
  fi

  check "Frontend is running" \
    "curl -sf http://localhost:$ACTIVE_PORT"

  check "Backend is running" \
    "curl -sf http://localhost:$BACKEND_PORT/health"

  check "Both ports are open simultaneously" \
    "curl -sf http://localhost:$ACTIVE_PORT && \
     curl -sf http://localhost:$BACKEND_PORT/health"

  # Port checks
  echo ""
  echo -e "  ${BOLD}Port Availability:${NC}"

  for PORT in 5432 6379 $BACKEND_PORT $ACTIVE_PORT 5050 8025; do
    check "Port $PORT is in use (service running)" \
      "ss -tlnp 2>/dev/null | grep -q ':$PORT ' || \
       netstat -tlnp 2>/dev/null | grep -q ':$PORT '"
  done

  # Git checks
  echo ""
  echo -e "  ${BOLD}Git Repository:${NC}"

  check "Git repo initialized" \
    "test -d $PROJECT_ROOT/.git"

  check "Remote origin configured" \
    "cd $PROJECT_ROOT && git remote get-url origin"

  check "Working tree clean or has commits" \
    "cd $PROJECT_ROOT && git log --oneline -1"

  check_warn "GitHub is reachable" \
    "curl -sf --max-time 5 https://github.com"

  # Disk space check
  echo ""
  echo -e "  ${BOLD}System Resources:${NC}"

  FREE_GB=$(df -BG ~ 2>/dev/null | awk 'NR==2{print $4}' | tr -d 'G' || echo "0")
  if [ "$FREE_GB" -gt 2 ] 2>/dev/null; then
    echo -e "  ${GREEN}✔${NC}  Disk space available: ${FREE_GB}GB free"
    PASS=$((PASS+1))
  else
    echo -e "  ${YELLOW}⚠${NC}  Low disk space: ${FREE_GB}GB free"
    WARN_COUNT=$((WARN_COUNT+1))
  fi

  FREE_MEM=$(free -m 2>/dev/null | awk 'NR==2{print $7}' || echo "0")
  if [ "$FREE_MEM" -gt 512 ] 2>/dev/null; then
    echo -e "  ${GREEN}✔${NC}  Memory available: ${FREE_MEM}MB free"
    PASS=$((PASS+1))
  else
    echo -e "  ${YELLOW}⚠${NC}  Low memory: ${FREE_MEM}MB free"
    WARN_COUNT=$((WARN_COUNT+1))
  fi
}

# ═════════════════════════════════════════════════════════════════
# RUN SELECTED SUITES
# ═════════════════════════════════════════════════════════════════
case "$MODE" in
  --db)          run_db_tests ;;
  --api)         run_api_tests ;;
  --frontend)    run_frontend_tests ;;
  --unit)        run_unit_tests ;;
  --integration) run_integration_tests ;;
  --all|*)
    run_db_tests
    run_api_tests
    run_frontend_tests
    run_unit_tests
    run_integration_tests
    ;;
esac

# ═════════════════════════════════════════════════════════════════
# RESULTS SUMMARY
# ═════════════════════════════════════════════════════════════════
TOTAL=$((PASS + FAIL))
echo ""
if [ $FAIL -eq 0 ]; then
  echo -e "${BOLD}${GREEN}"
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║              🎉  ALL TESTS PASSED!                     ║"
  printf "║   ✔ Passed: %-3s   ⚠ Warnings: %-3s   Total: %-3s     ║\n" "$PASS" "$WARN_COUNT" "$TOTAL"
  echo "╚════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  exit 0
else
  echo -e "${BOLD}${RED}"
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║              ❌  SOME TESTS FAILED                     ║"
  printf "║   ✔ Passed: %-3s   ✗ Failed: %-3s   Total: %-3s       ║\n" "$PASS" "$FAIL" "$TOTAL"
  echo "╠════════════════════════════════════════════════════════╣"
  echo "║  Fix failed tests then re-run: ./scripts/test.sh      ║"
  echo "╚════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  exit 1
fi
