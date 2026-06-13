#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  GCP Deployment Portal — Complete Backup Script
#  Backs up: Project files, PostgreSQL DB, Redis, Docker volumes,
#            credentials, .env files, git state
#  Location: ~/gcp-portal-backup/YYYY-MM-DD_HH-MM-SS/
# ═══════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()     { echo -e "${GREEN}[✔]${NC} $1"; }
info()    { echo -e "${CYAN}[→]${NC} $1"; }
warn()    { echo -e "${YELLOW}[⚠]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; }
section() { echo -e "\n${BOLD}${BLUE}── $1 ──${NC}"; }
header()  { echo -e "\n${BOLD}${CYAN}$1${NC}"; }

# ── Config ────────────────────────────────────────────────────────
PROJECT_ROOT="${PROJECT_ROOT:-$HOME/projects/gcp-deployment-portal}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_BASE="$HOME/gcp-portal-backup"
BACKUP_DIR="$BACKUP_BASE/$TIMESTAMP"
LOG_FILE="$BACKUP_DIR/backup.log"

# DB Config
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="gcp_portal"
DB_USER="portal"
DB_PASS="portal123"

# ── Start ─────────────────────────────────────────────────────────
clear
echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║     GCP DEPLOYMENT PORTAL — COMPLETE BACKUP             ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Project : $PROJECT_ROOT"
echo "║  Backup  : $BACKUP_DIR"
echo "║  Time    : $(date '+%Y-%m-%d %H:%M:%S')"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Confirm before proceeding
read -p "$(echo -e ${YELLOW}Press ENTER to start backup or Ctrl+C to cancel...${NC})" _

# ── Create backup directory structure ─────────────────────────────
section "Creating Backup Structure"
mkdir -p "$BACKUP_DIR"/{project,database,docker,credentials,config,logs,git}
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
log "Backup directory: $BACKUP_DIR"

BACKUP_SIZE=0
PASS=0
FAIL=0
SKIP=0

# ══════════════════════════════════════════════════════════════════
# STEP 1 — Project Files Backup
# ══════════════════════════════════════════════════════════════════
section "STEP 1 — Project Files"

if [ -d "$PROJECT_ROOT" ]; then
  info "Copying project files..."

  # Full project copy (excluding node_modules, venv, __pycache__)
  rsync -av \
    --exclude='node_modules/' \
    --exclude='venv/' \
    --exclude='__pycache__/' \
    --exclude='*.pyc' \
    --exclude='.pytest_cache/' \
    --exclude='htmlcov/' \
    --exclude='.coverage' \
    --exclude='frontend/build/' \
    --exclude='frontend/.cache/' \
    --exclude='.git/' \
    --exclude='logs/*.log' \
    --exclude='.pids/' \
    "$PROJECT_ROOT/" \
    "$BACKUP_DIR/project/" \
    2>/dev/null | tail -5

  log "Project files copied"
  PASS=$((PASS+1))

  # Get project file count
  FILE_COUNT=$(find "$BACKUP_DIR/project/" -type f | wc -l)
  info "Files backed up: $FILE_COUNT"

else
  warn "Project root not found: $PROJECT_ROOT"
  warn "Trying common locations..."

  for loc in \
    "$HOME/gcp-deployment-portal" \
    "$HOME/projects/portal" \
    "$HOME/portal"; do
    if [ -d "$loc" ]; then
      rsync -av --exclude='node_modules/' --exclude='venv/' \
        "$loc/" "$BACKUP_DIR/project/" 2>/dev/null | tail -3
      log "Found and backed up from: $loc"
      PASS=$((PASS+1))
      break
    fi
  done
fi

# ══════════════════════════════════════════════════════════════════
# STEP 2 — Environment Files (.env) — Critical
# ══════════════════════════════════════════════════════════════════
section "STEP 2 — Environment Files (Secrets)"

mkdir -p "$BACKUP_DIR/config/env"

# Backend .env
for env_file in \
  "$PROJECT_ROOT/backend/.env" \
  "$PROJECT_ROOT/backend/.env.example" \
  "$PROJECT_ROOT/frontend/.env.local" \
  "$PROJECT_ROOT/frontend/.env" \
  "$PROJECT_ROOT/.env"; do

  if [ -f "$env_file" ]; then
    fname=$(basename "$env_file")
    dname=$(basename $(dirname "$env_file"))
    cp "$env_file" "$BACKUP_DIR/config/env/${dname}_${fname}"
    log "Backed up: $env_file"
    PASS=$((PASS+1))
  else
    warn "Not found: $env_file"
    SKIP=$((SKIP+1))
  fi
done

# ══════════════════════════════════════════════════════════════════
# STEP 3 — PostgreSQL Database Backup
# ══════════════════════════════════════════════════════════════════
section "STEP 3 — PostgreSQL Database"

mkdir -p "$BACKUP_DIR/database"

# Check if postgres is running
if docker ps 2>/dev/null | grep -q "gcp-portal-postgres"; then
  info "PostgreSQL container is running — creating dump..."

  # Full database dump (SQL format)
  PGPASSWORD=$DB_PASS pg_dump \
    -h $DB_HOST \
    -p $DB_PORT \
    -U $DB_USER \
    -d $DB_NAME \
    --verbose \
    --clean \
    --if-exists \
    --create \
    -f "$BACKUP_DIR/database/gcp_portal_full.sql" \
    2>/dev/null

  if [ -f "$BACKUP_DIR/database/gcp_portal_full.sql" ]; then
    SQL_SIZE=$(du -sh "$BACKUP_DIR/database/gcp_portal_full.sql" | cut -f1)
    log "Full SQL dump created ($SQL_SIZE)"
    PASS=$((PASS+1))
  fi

  # Schema-only dump
  PGPASSWORD=$DB_PASS pg_dump \
    -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    --schema-only \
    -f "$BACKUP_DIR/database/gcp_portal_schema.sql" \
    2>/dev/null
  log "Schema-only dump created"
  PASS=$((PASS+1))

  # Data-only dump
  PGPASSWORD=$DB_PASS pg_dump \
    -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    --data-only \
    -f "$BACKUP_DIR/database/gcp_portal_data.sql" \
    2>/dev/null
  log "Data-only dump created"
  PASS=$((PASS+1))

  # Table-by-table backup
  mkdir -p "$BACKUP_DIR/database/tables"
  TABLES=$(PGPASSWORD=$DB_PASS psql \
    -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -tAc "SELECT tablename FROM pg_tables WHERE schemaname='public';" \
    2>/dev/null)

  for TABLE in $TABLES; do
    PGPASSWORD=$DB_PASS psql \
      -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
      -c "\COPY $TABLE TO '$BACKUP_DIR/database/tables/${TABLE}.csv' CSV HEADER" \
      2>/dev/null && \
      log "  Table backup: $TABLE" || \
      warn "  Skipped table: $TABLE"
  done

  # Database stats
  info "Database stats:"
  PGPASSWORD=$DB_PASS psql \
    -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
    -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size FROM pg_tables WHERE schemaname='public' ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;" \
    2>/dev/null || true

else
  warn "PostgreSQL container not running"
  warn "Starting postgres to create backup..."

  # Try to start postgres
  cd "${PROJECT_ROOT:-$HOME/projects/gcp-deployment-portal}" 2>/dev/null || true
  docker compose up -d postgres 2>/dev/null && sleep 8

  if docker ps 2>/dev/null | grep -q "gcp-portal-postgres"; then
    PGPASSWORD=$DB_PASS pg_dump \
      -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME \
      --clean --create \
      -f "$BACKUP_DIR/database/gcp_portal_full.sql" \
      2>/dev/null && log "Database dump created after starting container" \
      || warn "Could not dump database"
  else
    warn "Could not start PostgreSQL — skipping DB backup"
    echo "NOTE: Start postgres and run backup again for DB backup" \
      > "$BACKUP_DIR/database/DB_BACKUP_SKIPPED.txt"
    SKIP=$((SKIP+1))
  fi
fi

# ══════════════════════════════════════════════════════════════════
# STEP 4 — Docker Compose Config
# ══════════════════════════════════════════════════════════════════
section "STEP 4 — Docker Configuration"

mkdir -p "$BACKUP_DIR/docker"

# docker-compose.yml
for dc_file in \
  "$PROJECT_ROOT/docker-compose.yml" \
  "$PROJECT_ROOT/docker-compose.override.yml" \
  "$PROJECT_ROOT/docker-compose.prod.yml"; do
  if [ -f "$dc_file" ]; then
    cp "$dc_file" "$BACKUP_DIR/docker/"
    log "Backed up: $(basename $dc_file)"
    PASS=$((PASS+1))
  fi
done

# Dockerfiles
find "${PROJECT_ROOT:-$HOME/projects/gcp-deployment-portal}" \
  -name "Dockerfile*" \
  -not -path "*/node_modules/*" \
  -not -path "*/venv/*" \
  2>/dev/null | while read df; do
  rel_path="${df#$PROJECT_ROOT/}"
  dir_path=$(dirname "$rel_path")
  mkdir -p "$BACKUP_DIR/docker/$dir_path"
  cp "$df" "$BACKUP_DIR/docker/$dir_path/"
  log "  Dockerfile: $rel_path"
done

# Running container state
if command -v docker &>/dev/null; then
  docker ps -a --format \
    "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" \
    > "$BACKUP_DIR/docker/container_state.txt" 2>/dev/null
  docker compose \
    -f "${PROJECT_ROOT:-$HOME/projects/gcp-deployment-portal}/docker-compose.yml" \
    config > "$BACKUP_DIR/docker/compose_resolved.yml" 2>/dev/null || true
  log "Container state saved"
  PASS=$((PASS+1))
fi

# ══════════════════════════════════════════════════════════════════
# STEP 5 — GCP Credentials Backup
# ══════════════════════════════════════════════════════════════════
section "STEP 5 — GCP Credentials"

mkdir -p "$BACKUP_DIR/credentials"

# Check multiple locations for credential files
for cred_dir in \
  "$PROJECT_ROOT/credentials" \
  "$HOME/.config/gcloud" \
  "$PROJECT_ROOT/backend/credentials"; do

  if [ -d "$cred_dir" ]; then
    cp -r "$cred_dir" "$BACKUP_DIR/credentials/$(basename $cred_dir)" 2>/dev/null
    log "Credentials backed up from: $cred_dir"
    PASS=$((PASS+1))
  fi
done

# gcloud active config
if command -v gcloud &>/dev/null; then
  gcloud config list > "$BACKUP_DIR/credentials/gcloud_config.txt" 2>/dev/null
  gcloud projects list > "$BACKUP_DIR/credentials/gcloud_projects.txt" 2>/dev/null
  log "gcloud config saved"
fi

# Warn about credential security
echo "⚠️  SECURITY NOTICE: This backup contains GCP credentials." \
  > "$BACKUP_DIR/credentials/SECURITY_NOTICE.txt"
echo "Keep this backup folder secure and never share it." \
  >> "$BACKUP_DIR/credentials/SECURITY_NOTICE.txt"

# ══════════════════════════════════════════════════════════════════
# STEP 6 — Git State
# ══════════════════════════════════════════════════════════════════
section "STEP 6 — Git State"

mkdir -p "$BACKUP_DIR/git"

if [ -d "$PROJECT_ROOT/.git" ]; then

  # Save git status
  cd "$PROJECT_ROOT"
  git status > "$BACKUP_DIR/git/git_status.txt" 2>/dev/null
  git log --oneline -20 > "$BACKUP_DIR/git/git_log.txt" 2>/dev/null
  git branch -a > "$BACKUP_DIR/git/git_branches.txt" 2>/dev/null
  git remote -v > "$BACKUP_DIR/git/git_remotes.txt" 2>/dev/null
  git diff > "$BACKUP_DIR/git/git_uncommitted_changes.diff" 2>/dev/null
  git stash list > "$BACKUP_DIR/git/git_stash.txt" 2>/dev/null

  # Full git bundle (contains entire git history)
  git bundle create \
    "$BACKUP_DIR/git/portal_full_repo.bundle" \
    --all \
    2>/dev/null && \
    log "Full git bundle created (contains all history)" || \
    warn "Git bundle failed — saving patch instead"

  log "Git state saved"
  PASS=$((PASS+1))

  # Show current git status
  info "Current git status:"
  git status --short | head -10 || true

else
  warn "No .git directory found"
  SKIP=$((SKIP+1))
fi

# ══════════════════════════════════════════════════════════════════
# STEP 7 — Scripts and Config Files
# ══════════════════════════════════════════════════════════════════
section "STEP 7 — Scripts and Config"

# Save scripts
if [ -d "$PROJECT_ROOT/scripts" ]; then
  cp -r "$PROJECT_ROOT/scripts" "$BACKUP_DIR/config/"
  log "Scripts backed up"
  PASS=$((PASS+1))
fi

# Save docs
if [ -d "$PROJECT_ROOT/docs" ]; then
  cp -r "$PROJECT_ROOT/docs" "$BACKUP_DIR/config/"
  log "Docs backed up"
fi

# Save Terraform modules
if [ -d "$PROJECT_ROOT/terraform" ]; then
  rsync -av \
    --exclude='.terraform/' \
    --exclude='*.tfstate' \
    --exclude='*.tfstate.backup' \
    "$PROJECT_ROOT/terraform/" \
    "$BACKUP_DIR/config/terraform/" \
    2>/dev/null | tail -3
  log "Terraform modules backed up"
  PASS=$((PASS+1))
fi

# Save Helm charts
if [ -d "$PROJECT_ROOT/helm" ]; then
  cp -r "$PROJECT_ROOT/helm" "$BACKUP_DIR/config/"
  log "Helm charts backed up"
fi

# Save k8s manifests
if [ -d "$PROJECT_ROOT/k8s" ]; then
  cp -r "$PROJECT_ROOT/k8s" "$BACKUP_DIR/config/"
  log "k8s manifests backed up"
fi

# ══════════════════════════════════════════════════════════════════
# STEP 8 — System State Snapshot
# ══════════════════════════════════════════════════════════════════
section "STEP 8 — System State Snapshot"

mkdir -p "$BACKUP_DIR/logs"

{
  echo "=== SYSTEM SNAPSHOT ==="
  echo "Date     : $(date)"
  echo "Hostname : $(hostname)"
  echo "User     : $(whoami)"
  echo "WSL      : $(uname -r)"
  echo ""
  echo "=== DISK SPACE ==="
  df -h ~
  echo ""
  echo "=== MEMORY ==="
  free -h
  echo ""
  echo "=== DOCKER ==="
  docker --version 2>/dev/null || echo "Docker not available"
  docker compose version 2>/dev/null || echo "Docker Compose not available"
  docker ps -a 2>/dev/null || echo "Docker not running"
  echo ""
  echo "=== NODE ==="
  node --version 2>/dev/null || echo "Node not installed"
  npm --version 2>/dev/null || echo "npm not installed"
  echo ""
  echo "=== PYTHON ==="
  python3 --version 2>/dev/null || echo "Python not installed"
  pip3 --version 2>/dev/null || echo "pip not installed"
  echo ""
  echo "=== TERRAFORM ==="
  terraform version 2>/dev/null || echo "Terraform not installed"
  echo ""
  echo "=== GCLOUD ==="
  gcloud version 2>/dev/null | head -3 || echo "gcloud not installed"
  gcloud config get project 2>/dev/null || echo "No project set"
  echo ""
  echo "=== INSTALLED PYTHON PACKAGES ==="
  [ -f "$PROJECT_ROOT/backend/venv/bin/pip" ] && \
    "$PROJECT_ROOT/backend/venv/bin/pip" freeze 2>/dev/null || \
    pip3 freeze 2>/dev/null | head -30
  echo ""
  echo "=== GIT CONFIG ==="
  git config --global --list 2>/dev/null
} > "$BACKUP_DIR/logs/system_snapshot.txt" 2>&1

log "System snapshot saved"
PASS=$((PASS+1))

# ══════════════════════════════════════════════════════════════════
# STEP 9 — Create Restore Script
# ══════════════════════════════════════════════════════════════════
section "STEP 9 — Creating Restore Script"

cat > "$BACKUP_DIR/RESTORE.sh" << 'RESTOREEOF'
#!/bin/bash
# ═══════════════════════════════════════════════════════════
#  GCP Portal — RESTORE Script
#  Run this to restore from this backup
# ═══════════════════════════════════════════════════════════

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESTORE_TARGET="${1:-$HOME/projects/gcp-deployment-portal}"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║     GCP PORTAL — RESTORE                        ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║  From : $SCRIPT_DIR"
echo "║  To   : $RESTORE_TARGET"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

read -p "$(echo -e ${RED}WARNING: This will overwrite existing files. Continue? [y/N]: ${NC})" confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

echo -e "\n${CYAN}[1] Restoring project files...${NC}"
mkdir -p "$RESTORE_TARGET"
rsync -av "$SCRIPT_DIR/project/" "$RESTORE_TARGET/" | tail -5
echo -e "${GREEN}✔ Project files restored${NC}"

echo -e "\n${CYAN}[2] Restoring .env files...${NC}"
[ -f "$SCRIPT_DIR/config/env/backend_.env" ] && \
  cp "$SCRIPT_DIR/config/env/backend_.env" "$RESTORE_TARGET/backend/.env" && \
  echo -e "${GREEN}✔ backend/.env restored${NC}"
[ -f "$SCRIPT_DIR/config/env/frontend_.env.local" ] && \
  cp "$SCRIPT_DIR/config/env/frontend_.env.local" "$RESTORE_TARGET/frontend/.env.local" && \
  echo -e "${GREEN}✔ frontend/.env.local restored${NC}"

echo -e "\n${CYAN}[3] Starting PostgreSQL...${NC}"
cd "$RESTORE_TARGET"
docker compose up -d postgres
echo "Waiting for PostgreSQL..."
sleep 10

echo -e "\n${CYAN}[4] Restoring database...${NC}"
if [ -f "$SCRIPT_DIR/database/gcp_portal_full.sql" ]; then
  PGPASSWORD=portal123 psql \
    -h localhost -p 5432 -U portal -d postgres \
    -c "DROP DATABASE IF EXISTS gcp_portal;" 2>/dev/null || true
  PGPASSWORD=portal123 psql \
    -h localhost -p 5432 -U portal \
    -f "$SCRIPT_DIR/database/gcp_portal_full.sql"
  echo -e "${GREEN}✔ Database restored from SQL dump${NC}"
else
  echo "No database dump found — applying fresh schema..."
  [ -f "$RESTORE_TARGET/docs/schema.sql" ] && \
    PGPASSWORD=portal123 psql \
      -h localhost -p 5432 -U portal -d gcp_portal \
      -f "$RESTORE_TARGET/docs/schema.sql"
fi

echo -e "\n${CYAN}[5] Restoring credentials...${NC}"
[ -d "$SCRIPT_DIR/credentials/credentials" ] && \
  cp -r "$SCRIPT_DIR/credentials/credentials" "$RESTORE_TARGET/" && \
  echo -e "${GREEN}✔ Credentials restored${NC}"

echo -e "\n${CYAN}[6] Reinstalling dependencies...${NC}"
cd "$RESTORE_TARGET/backend"
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt --quiet
echo -e "${GREEN}✔ Python packages installed${NC}"

cd "$RESTORE_TARGET/frontend"
npm install --silent
echo -e "${GREEN}✔ Node packages installed${NC}"

echo ""
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✅ RESTORE COMPLETE!${NC}"
echo -e "${GREEN}${BOLD}═══════════════════════════════════════════${NC}"
echo ""
echo "  Next steps:"
echo "  1. cd $RESTORE_TARGET"
echo "  2. ./scripts/start.sh"
echo ""
RESTOREEOF

chmod +x "$BACKUP_DIR/RESTORE.sh"
log "Restore script created: $BACKUP_DIR/RESTORE.sh"
PASS=$((PASS+1))

# ══════════════════════════════════════════════════════════════════
# STEP 10 — Create Compressed Archive
# ══════════════════════════════════════════════════════════════════
section "STEP 10 — Creating Compressed Archive"

info "Compressing backup..."
cd "$BACKUP_BASE"
tar -czf "${TIMESTAMP}_gcp_portal_backup.tar.gz" "$TIMESTAMP/" 2>/dev/null
ARCHIVE_SIZE=$(du -sh "${TIMESTAMP}_gcp_portal_backup.tar.gz" | cut -f1)
log "Archive created: ${TIMESTAMP}_gcp_portal_backup.tar.gz ($ARCHIVE_SIZE)"
PASS=$((PASS+1))

# Also create a LATEST symlink
ln -sfn "$TIMESTAMP" "$BACKUP_BASE/LATEST" 2>/dev/null || true

# ══════════════════════════════════════════════════════════════════
# STEP 11 — Create Backup Manifest
# ══════════════════════════════════════════════════════════════════
section "STEP 11 — Backup Manifest"

TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

cat > "$BACKUP_DIR/MANIFEST.txt" << MANIFESTEOF
═══════════════════════════════════════════════════════════
  GCP DEPLOYMENT PORTAL — BACKUP MANIFEST
═══════════════════════════════════════════════════════════
  Backup ID   : $TIMESTAMP
  Created     : $(date)
  Total Size  : $TOTAL_SIZE
  Source      : $PROJECT_ROOT
  Destination : $BACKUP_DIR

CONTENTS:
  📁 project/          — All source code (no node_modules/venv)
  📁 database/         — PostgreSQL dumps (SQL + CSV per table)
  📁 docker/           — docker-compose.yml + Dockerfiles
  📁 credentials/      — GCP service account keys + gcloud config
  📁 config/           — .env files, Terraform, Helm, k8s, scripts
  📁 git/              — Git bundle (full history), status, log
  📁 logs/             — System snapshot
  📄 RESTORE.sh        — Run this to restore everything
  📄 MANIFEST.txt      — This file

RESTORE INSTRUCTIONS:
  1. Copy backup to target machine
  2. cd $BACKUP_DIR
  3. chmod +x RESTORE.sh
  4. ./RESTORE.sh [optional: target path]

BACKUP STATS:
  Passed  : $PASS steps
  Skipped : $SKIP steps
  Failed  : $FAIL steps

SECURITY WARNING:
  ⚠️  This backup contains sensitive data:
      - GCP service account keys
      - Database credentials
      - API keys (.env files)
  Keep this backup SECURE and never share publicly.
═══════════════════════════════════════════════════════════
MANIFESTEOF

log "Manifest created"

# ══════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════════════╗"
echo "║            ✅ BACKUP COMPLETE!                           ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo -e "║  ${NC}Location : $BACKUP_DIR${BOLD}${GREEN}"
echo -e "║  ${NC}Archive  : $BACKUP_BASE/${TIMESTAMP}_gcp_portal_backup.tar.gz${BOLD}${GREEN}"
echo -e "║  ${NC}Latest   : $BACKUP_BASE/LATEST → (symlink)${BOLD}${GREEN}"
echo -e "║  ${NC}Size     : $TOTAL_SIZE${BOLD}${GREEN}"
echo -e "║  ${NC}Steps    : ✔ $PASS passed  ⚠ $SKIP skipped  ✗ $FAIL failed${BOLD}${GREEN}"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  📁 BACKUP CONTENTS:                                    ║"
echo "║     project/     ← All source code                     ║"
echo "║     database/    ← PostgreSQL dump + CSV tables         ║"
echo "║     credentials/ ← GCP keys + gcloud config            ║"
echo "║     config/      ← .env files + Terraform + Helm        ║"
echo "║     git/         ← Full git bundle + history            ║"
echo "║     RESTORE.sh   ← One-click restore script             ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  TO RESTORE:                                            ║"
echo "║    cd $BACKUP_DIR"
echo "║    ./RESTORE.sh                                         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo "All backup files:"
find "$BACKUP_DIR" -type f | sort | sed 's|'"$BACKUP_DIR"'/||' | \
  awk '{print "  📄 " $0}'
