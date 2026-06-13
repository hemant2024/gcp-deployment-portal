#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  GCP Deployment Portal — STOP SCRIPT
#  Stops: Frontend → Backend → Docker services
#  Usage:
#    ./scripts/stop.sh            # Stop app, keep DB data
#    ./scripts/stop.sh --keep-db  # Stop app only, keep DB running
#    ./scripts/stop.sh --full     # Stop everything + wipe all data
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
PID_DIR="$PROJECT_ROOT/.pids"
MODE="${1:---normal}"

# ── Helpers ───────────────────────────────────────────────────────
log()     { echo -e "${BOLD}${BLUE}[→]${NC} $1"; }
success() { echo -e "${BOLD}${GREEN}[✔]${NC} $1"; }
warn()    { echo -e "${BOLD}${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${BOLD}${RED}[✗]${NC} $1"; }
header()  { echo -e "\n${BOLD}${CYAN}── $1 ──${NC}"; }

# ── Banner ────────────────────────────────────────────────────────
echo -e "${BOLD}${RED}"
echo "╔══════════════════════════════════════════════════╗"
echo "║     GCP Portal — Stopping all services...       ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Full wipe confirmation ────────────────────────────────────────
if [ "$MODE" = "--full" ]; then
  echo -e "${BOLD}${RED}⚠  WARNING: --full will DELETE all database data!${NC}"
  read -r -p "   Are you sure? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled."
    exit 0
  fi
fi

# ═════════════════════════════════════════════════════════════════
# STOP 1 — Frontend
# ═════════════════════════════════════════════════════════════════
header "Stopping Frontend"

# Kill by PID file
if [ -f "$PID_DIR/frontend.pid" ]; then
  FE_PID=$(cat "$PID_DIR/frontend.pid" 2>/dev/null)
  if [ -n "$FE_PID" ] && kill -0 "$FE_PID" &>/dev/null 2>&1; then
    kill -15 "$FE_PID" &>/dev/null 2>&1 || true
    sleep 1
    kill -9 "$FE_PID" &>/dev/null 2>&1 || true
    success "Frontend process ($FE_PID) stopped"
  fi
  rm -f "$PID_DIR/frontend.pid"
fi

# Kill by port (fallback)
for PORT in $FRONTEND_PORT $VITE_PORT; do
  PID=$(lsof -t -i:$PORT 2>/dev/null)
  if [ -n "$PID" ]; then
    kill -9 $PID &>/dev/null 2>&1 || true
    success "Killed process on port $PORT"
  fi
done

# Kill node/npm/vite processes
pkill -f "react-scripts start"  &>/dev/null 2>&1 || true
pkill -f "vite"                  &>/dev/null 2>&1 || true
pkill -f "npm start"             &>/dev/null 2>&1 || true
success "Frontend stopped"

# ═════════════════════════════════════════════════════════════════
# STOP 2 — Backend
# ═════════════════════════════════════════════════════════════════
header "Stopping Backend"

# Kill by PID file
if [ -f "$PID_DIR/backend.pid" ]; then
  BE_PID=$(cat "$PID_DIR/backend.pid" 2>/dev/null)
  if [ -n "$BE_PID" ] && kill -0 "$BE_PID" &>/dev/null 2>&1; then
    kill -15 "$BE_PID" &>/dev/null 2>&1 || true
    sleep 1
    kill -9 "$BE_PID" &>/dev/null 2>&1 || true
    success "Backend process ($BE_PID) stopped"
  fi
  rm -f "$PID_DIR/backend.pid"
fi

# Kill by port (fallback)
PID=$(lsof -t -i:$BACKEND_PORT 2>/dev/null)
if [ -n "$PID" ]; then
  kill -9 $PID &>/dev/null 2>&1 || true
  success "Killed process on port $BACKEND_PORT"
fi

# Kill uvicorn processes
pkill -f "uvicorn main:app" &>/dev/null 2>&1 || true
success "Backend stopped"

# ═════════════════════════════════════════════════════════════════
# STOP 3 — Docker Services
# ═════════════════════════════════════════════════════════════════
if [ "$MODE" != "--keep-db" ]; then
  header "Stopping Docker Services"

  if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
    cd "$PROJECT_ROOT"

    if [ "$MODE" = "--full" ]; then
      log "Removing containers AND volumes (all DB data wiped)..."
      docker compose down -v --remove-orphans &>/dev/null 2>&1 || true
      success "All containers and volumes removed"
    else
      log "Stopping containers (keeping DB data)..."
      docker compose down --remove-orphans &>/dev/null 2>&1 || true
      success "Containers stopped (data preserved)"
    fi
  else
    warn "docker-compose.yml not found — skipping"
  fi
else
  warn "Skipping Docker stop (--keep-db flag set)"
fi

# ── Final status ──────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║        ✅  All services stopped cleanly          ║"

if [ "$MODE" = "--keep-db" ]; then
echo "║        🗄  Database still running on :5432       ║"
elif [ "$MODE" = "--full" ]; then
echo "║        🗑  All data volumes wiped                 ║"
else
echo "║        💾  Database data preserved               ║"
fi

echo "║                                                  ║"
echo "║  Restart:   ./scripts/start.sh                  ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
