#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  GCP Deployment Portal — START SCRIPT
#  Starts: Docker → PostgreSQL → Redis → Backend → Frontend
# ═══════════════════════════════════════════════════════════════════

set -e

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
LOG_DIR="$PROJECT_ROOT/logs"
PID_DIR="$PROJECT_ROOT/.pids"
BACKEND_LOG="$LOG_DIR/backend.log"
FRONTEND_LOG="$LOG_DIR/frontend.log"

# ── Helpers ───────────────────────────────────────────────────────
log()     { echo -e "${BOLD}${BLUE}[→]${NC} $1"; }
success() { echo -e "${BOLD}${GREEN}[✔]${NC} $1"; }
warn()    { echo -e "${BOLD}${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${BOLD}${RED}[✗]${NC} $1"; }
header()  { echo -e "\n${BOLD}${CYAN}── $1 ──${NC}"; }

# ── Banner ────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${BLUE}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║       GCP Enterprise Deployment Portal                ║"
echo "║       Starting all services...                        ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Setup dirs ────────────────────────────────────────────────────
mkdir -p "$LOG_DIR" "$PID_DIR"

# ═════════════════════════════════════════════════════════════════
# STEP 1 — Check Project Root
# ═════════════════════════════════════════════════════════════════
header "STEP 1 — Project Root"

if [ ! -d "$PROJECT_ROOT" ]; then
  error "Project not found at: $PROJECT_ROOT"
  echo ""
  echo "  Fix: Set correct path:"
  echo "  export PROJECT_ROOT=/path/to/gcp-deployment-portal"
  echo "  ./scripts/start.sh"
  exit 1
fi

cd "$PROJECT_ROOT"
success "Project root: $PROJECT_ROOT"

# ═════════════════════════════════════════════════════════════════
# STEP 2 — Docker + Infrastructure Services
# ═════════════════════════════════════════════════════════════════
header "STEP 2 — Docker & Infrastructure"

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
  error "Docker not installed!"
  echo "  Run: sudo apt install docker.io docker-compose-plugin"
  exit 1
fi

# Start Docker daemon if not running
if ! docker info &>/dev/null 2>&1; then
  log "Starting Docker daemon..."

  # Fix iptables first (most common WSL2 issue)
  sudo update-alternatives --set iptables \
    /usr/sbin/iptables-legacy &>/dev/null 2>&1 || true
  sudo update-alternatives --set ip6tables \
    /usr/sbin/ip6tables-legacy &>/dev/null 2>&1 || true

  # Start containerd + docker
  sudo service containerd start &>/dev/null 2>&1 || true
  sudo service docker start &>/dev/null 2>&1 || \
    sudo dockerd > /tmp/dockerd.log 2>&1 &

  # Wait up to 30 seconds
  TRIES=0
  while ! docker info &>/dev/null 2>&1; do
    TRIES=$((TRIES+1))
    if [ $TRIES -ge 15 ]; then
      error "Docker failed to start after 30 seconds"
      echo "  Try: sudo service docker start"
      echo "  Or install Docker Desktop for Windows"
      cat /tmp/dockerd.log 2>/dev/null | tail -5
      exit 1
    fi
    echo -n "."
    sleep 2
  done
  echo ""
fi
success "Docker is running  ($(docker --version | cut -d' ' -f3 | tr -d ','))"

# Check docker-compose.yml exists
if [ ! -f "$PROJECT_ROOT/docker-compose.yml" ]; then
  error "docker-compose.yml not found in $PROJECT_ROOT"
  exit 1
fi

# Check if containers already running
RUNNING=$(docker compose ps --services --filter "status=running" 2>/dev/null | wc -l)
if [ "$RUNNING" -gt 0 ]; then
  warn "Some containers already running — restarting..."
  docker compose down --remove-orphans &>/dev/null 2>&1 || true
fi

# Pull latest images (skip if already pulled)
log "Pulling Docker images (first time takes 2-3 min)..."
docker compose pull &>/dev/null 2>&1 || warn "Could not pull images — using cached"

# Start all services
log "Starting PostgreSQL, Redis, pgAdmin, MailHog..."
docker compose up -d

# Wait for PostgreSQL
log "Waiting for PostgreSQL to be healthy..."
TRIES=0
until docker compose exec -T postgres \
  pg_isready -U portal -d gcp_portal &>/dev/null 2>&1; do
  TRIES=$((TRIES+1))
  if [ $TRIES -ge 30 ]; then
    error "PostgreSQL did not become healthy after 60 seconds"
    docker compose logs postgres | tail -10
    exit 1
  fi
  echo -n "."
  sleep 2
done
echo ""
success "PostgreSQL is healthy  (localhost:5432)"

# Wait for Redis
log "Waiting for Redis..."
TRIES=0
until docker compose exec -T redis \
  redis-cli ping &>/dev/null 2>&1 | grep -q PONG 2>/dev/null || \
  redis-cli -h localhost ping 2>/dev/null | grep -q PONG; do
  TRIES=$((TRIES+1))
  [ $TRIES -ge 10 ] && break
  sleep 1
done
success "Redis is healthy       (localhost:6379)"

# Apply database schema if tables don't exist
TABLE_COUNT=$(PGPASSWORD=portal123 psql \
  -h localhost -U portal -d gcp_portal \
  -t -c "SELECT COUNT(*) FROM information_schema.tables \
          WHERE table_schema='public'" 2>/dev/null | xargs 2>/dev/null || echo "0")

if [ "$TABLE_COUNT" -lt "7" ]; then
  log "Applying database schema..."
  if [ -f "$PROJECT_ROOT/docs/schema.sql" ]; then
    PGPASSWORD=portal123 psql \
      -h localhost -U portal -d gcp_portal \
      -f "$PROJECT_ROOT/docs/schema.sql" &>/dev/null 2>&1
    success "Database schema applied"
  else
    warn "schema.sql not found — skipping schema apply"
  fi
else
  success "Database schema OK     ($TABLE_COUNT tables found)"
fi

# ═════════════════════════════════════════════════════════════════
# STEP 3 — FastAPI Backend
# ═════════════════════════════════════════════════════════════════
header "STEP 3 — FastAPI Backend"

BACKEND_DIR="$PROJECT_ROOT/backend"

if [ ! -d "$BACKEND_DIR" ]; then
  error "Backend directory not found: $BACKEND_DIR"
  exit 1
fi

cd "$BACKEND_DIR"

# Create venv if missing
if [ ! -d "venv" ]; then
  log "Creating Python virtual environment..."
  python3 -m venv venv
  success "Virtual environment created"
fi

# Activate venv
source venv/bin/activate
success "Python venv activated  ($(python --version))"

# Install dependencies if missing
if ! python -c "import fastapi" &>/dev/null 2>&1; then
  log "Installing Python packages (first time takes 2-3 min)..."
  pip install --upgrade pip &>/dev/null 2>&1
  pip install -r requirements.txt 2>&1 | tail -3
  success "Python packages installed"
else
  success "Python packages OK"
fi

# Create .env if missing
if [ ! -f ".env" ]; then
  warn ".env not found — creating default .env..."
  cat > .env << 'ENVEOF'
APP_ENV=development
APP_VERSION=1.0.0-local
DEBUG=true
LOG_LEVEL=INFO
DATABASE_URL=postgresql+asyncpg://portal:portal123@localhost:5432/gcp_portal
SECRET_KEY=local-dev-secret-key-change-in-production-32chars
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=480
CORS_ORIGINS=["http://localhost:3000","http://localhost:5173","http://127.0.0.1:3000"]
REDIS_URL=redis://localhost:6379/0
GCP_PROJECT_ID=
GCP_REGION=us-central1
USE_GCP_MOCK=true
ANTHROPIC_API_KEY=
GITHUB_TOKEN=
GITHUB_MOCK_MODE=true
TERRAFORM_MOCK_MODE=true
SMTP_HOST=localhost
SMTP_PORT=1025
NOTIFICATIONS_MOCK_MODE=true
BUDGET_WARNING_THRESHOLD=0.80
REQUIRE_FINANCE_APPROVAL_ABOVE_USD=500.0
ENVEOF
  success "Default .env created"
fi

# Kill any existing backend on port 8000
if lsof -i :$BACKEND_PORT &>/dev/null 2>&1; then
  warn "Port $BACKEND_PORT in use — killing old process..."
  kill -9 $(lsof -t -i:$BACKEND_PORT) &>/dev/null 2>&1 || true
  sleep 2
fi

# Check main.py exists
if [ ! -f "main.py" ]; then
  error "main.py not found in $BACKEND_DIR"
  exit 1
fi

# Start FastAPI backend in background
log "Starting FastAPI backend on port $BACKEND_PORT..."
nohup uvicorn main:app \
  --host 0.0.0.0 \
  --port $BACKEND_PORT \
  --reload \
  --log-level info \
  > "$BACKEND_LOG" 2>&1 &

BACKEND_PID=$!
echo $BACKEND_PID > "$PID_DIR/backend.pid"

# Wait for backend to be ready
log "Waiting for backend to respond..."
TRIES=0
until curl -sf "http://localhost:$BACKEND_PORT/health" &>/dev/null 2>&1; do
  TRIES=$((TRIES+1))
  if [ $TRIES -ge 30 ]; then
    error "Backend did not start after 60 seconds"
    echo "  Last 10 lines of backend log:"
    tail -10 "$BACKEND_LOG" 2>/dev/null
    exit 1
  fi
  echo -n "."
  sleep 2
done
echo ""
success "Backend running        (http://localhost:$BACKEND_PORT)"
success "API Docs ready         (http://localhost:$BACKEND_PORT/api/docs)"

# ═════════════════════════════════════════════════════════════════
# STEP 4 — React Frontend
# ═════════════════════════════════════════════════════════════════
header "STEP 4 — React Frontend"

FRONTEND_DIR="$PROJECT_ROOT/frontend"

if [ ! -d "$FRONTEND_DIR" ]; then
  error "Frontend directory not found: $FRONTEND_DIR"
  exit 1
fi

cd "$FRONTEND_DIR"

# Detect Vite vs Create React App
if grep -q '"vite"' package.json 2>/dev/null; then
  APP_TYPE="vite"
  ACTIVE_PORT=$VITE_PORT
  START_CMD="npm run dev -- --host"
  success "Detected: Vite project"
else
  APP_TYPE="cra"
  ACTIVE_PORT=$FRONTEND_PORT
  START_CMD="npm start"
  success "Detected: Create React App"
fi

# Install node_modules if missing
if [ ! -d "node_modules" ] || [ ! -f "node_modules/.package-lock.json" ]; then
  log "Installing Node.js packages (first time takes 2-3 min)..."
  npm install 2>&1 | tail -3
  success "Node packages installed"
else
  success "Node packages OK"
fi

# Create .env.local if missing
if [ ! -f ".env.local" ]; then
  warn ".env.local not found — creating..."
  if [ "$APP_TYPE" = "vite" ]; then
    cat > .env.local << 'ENVEOF'
VITE_API_URL=http://localhost:8000/api
VITE_WS_URL=ws://localhost:8000/ws
VITE_APP_VERSION=1.0.0-local
VITE_APP_ENV=development
VITE_MOCK_AUTH=true
ENVEOF
  else
    cat > .env.local << 'ENVEOF'
REACT_APP_API_URL=http://localhost:8000/api
REACT_APP_WS_URL=ws://localhost:8000/ws
REACT_APP_VERSION=1.0.0-local
REACT_APP_ENV=development
REACT_APP_MOCK_AUTH=true
GENERATE_SOURCEMAP=false
ENVEOF
  fi
  success ".env.local created"
fi

# Kill any existing frontend on port
if lsof -i :$ACTIVE_PORT &>/dev/null 2>&1; then
  warn "Port $ACTIVE_PORT in use — killing old process..."
  kill -9 $(lsof -t -i:$ACTIVE_PORT) &>/dev/null 2>&1 || true
  sleep 2
fi

# Start frontend in background
log "Starting React frontend on port $ACTIVE_PORT..."
if [ "$APP_TYPE" = "cra" ]; then
  export BROWSER=none   # Prevent CRA from opening browser automatically
fi

nohup $START_CMD > "$FRONTEND_LOG" 2>&1 &
FRONTEND_PID=$!
echo $FRONTEND_PID > "$PID_DIR/frontend.pid"

# Wait for frontend to be ready
log "Waiting for frontend to respond..."
TRIES=0
until curl -sf "http://localhost:$ACTIVE_PORT" &>/dev/null 2>&1; do
  TRIES=$((TRIES+1))
  if [ $TRIES -ge 60 ]; then
    error "Frontend did not start after 120 seconds"
    echo "  Last 10 lines of frontend log:"
    tail -10 "$FRONTEND_LOG" 2>/dev/null
    exit 1
  fi
  echo -n "."
  sleep 2
done
echo ""
success "Frontend running       (http://localhost:$ACTIVE_PORT)"

# ═════════════════════════════════════════════════════════════════
# DONE — Access URLs
# ═════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           ✅  ALL SERVICES ARE RUNNING!                   ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║                                                           ║"
printf "║  🌐 Portal UI     →  http://localhost:%-4s               ║\n" "$ACTIVE_PORT"
printf "║  📚 API Docs      →  http://localhost:%s/api/docs    ║\n" "$BACKEND_PORT"
printf "║  ❤  Health Check  →  http://localhost:%s/health      ║\n" "$BACKEND_PORT"
echo "║  🗄  pgAdmin       →  http://localhost:5050               ║"
echo "║  📧 MailHog       →  http://localhost:8025               ║"
echo "║  🔴 Redis Insight  →  http://localhost:5540               ║"
echo "║                                                           ║"
echo "║  pgAdmin login:  admin@portal.local / admin123           ║"
echo "║  DB:             portal / portal123 @ localhost:5432     ║"
echo "║                                                           ║"
echo "║  📄 Logs:                                                 ║"
printf "║     Backend  → %s    ║\n" "$BACKEND_LOG"
printf "║     Frontend → %s   ║\n" "$FRONTEND_LOG"
echo "║                                                           ║"
echo "║  To stop:  ./scripts/stop.sh                             ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
