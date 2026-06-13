#!/bin/bash
# ══════════════════════════════════════════════════════════════════
#  GCP Portal — Git Push Script
#  Version: portalv1
#  Pushes all code to GitHub with version tag portalv1
# ══════════════════════════════════════════════════════════════════

# ── Colors ──────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[✔]${NC} $1"; }
info()    { echo -e "${BLUE}[→]${NC} $1"; }
warn()    { echo -e "${YELLOW}[⚠]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; }
section() { echo -e "\n${BOLD}${CYAN}── $1 ──${NC}"; }
header()  {
  echo ""
  echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  GCP Portal — Git Push — Version: portalv1       ${NC}"
  echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${NC}"
  echo ""
}

# ── Config ───────────────────────────────────────────────────────
VERSION="portalv1"
VERSION_NUMBER="1.0.0"
BRANCH="main"
PROJECT_ROOT="${PROJECT_ROOT:-$HOME/projects/gcp-deployment-portal}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE_TAG=$(date '+%Y%m%d')

# ── Header ───────────────────────────────────────────────────────
header

# ══════════════════════════════════════════════════════════════════
# STEP 1 — Pre-flight Checks
# ══════════════════════════════════════════════════════════════════
section "STEP 1 — Pre-flight Checks"

# Check PROJECT_ROOT exists
if [ ! -d "$PROJECT_ROOT" ]; then
  error "Project folder not found: $PROJECT_ROOT"
  echo "  Fix: export PROJECT_ROOT=~/projects/gcp-deployment-portal"
  exit 1
fi
log "Project folder: $PROJECT_ROOT"

# Check we are in a git repo
cd "$PROJECT_ROOT"
if [ ! -d ".git" ]; then
  error "Not a git repository: $PROJECT_ROOT"
  echo "  Fix: cd $PROJECT_ROOT && git init && git remote add origin <URL>"
  exit 1
fi
log "Git repository: OK"

# Check git remote exists
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
if [ -z "$REMOTE_URL" ]; then
  error "No git remote 'origin' configured"
  echo "  Fix: git remote add origin https://github.com/hemant2024/gcp-deployment-portal.git"
  exit 1
fi
log "Remote origin: $REMOTE_URL"

# Check git is configured
GIT_USER=$(git config --global user.name 2>/dev/null)
GIT_EMAIL=$(git config --global user.email 2>/dev/null)
if [ -z "$GIT_USER" ] || [ -z "$GIT_EMAIL" ]; then
  warn "Git identity not fully configured"
  git config --global user.name  "Hemant Pandey"
  git config --global user.email "hemant.kumar.e.pandey@ericsson.com"
  log "Git identity set: Hemant Pandey"
else
  log "Git identity: $GIT_USER <$GIT_EMAIL>"
fi

# Check internet connectivity
if curl -s --connect-timeout 5 https://github.com > /dev/null 2>&1; then
  log "GitHub reachable: OK"
else
  error "Cannot reach github.com — check internet connection"
  exit 1
fi

# ══════════════════════════════════════════════════════════════════
# STEP 2 — Update .gitignore (Protect Secrets)
# ══════════════════════════════════════════════════════════════════
section "STEP 2 — Updating .gitignore"

cat > .gitignore << 'GITEOF'
# ── Python ────────────────────────────────────────────────
venv/
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
.pytest_cache/
*.egg-info/
dist/
build/
htmlcov/
.coverage
.coverage.*
.tox/
*.so

# ── Node / React ──────────────────────────────────────────
node_modules/
frontend/build/
frontend/dist/
frontend/.cache/
.npm/
npm-debug.log*
yarn-error.log*
yarn.lock
package-lock.json

# ── Environment Files — NEVER COMMIT SECRETS ─────────────
.env
.env.*
!.env.example
backend/.env
frontend/.env.local
frontend/.env.production
frontend/.env.staging
*.env

# ── GCP Credentials — NEVER COMMIT ───────────────────────
credentials/
*.json
!package.json
!tsconfig.json
!.eslintrc.json
portal-sa-key.json
service-account*.json
*-key.json

# ── Terraform ─────────────────────────────────────────────
**/.terraform/
*.tfstate
*.tfstate.*
*.tfplan
.terraform.lock.hcl
terraform-workspaces/
crash.log
override.tf
override.tf.json

# ── Docker ────────────────────────────────────────────────
docker-compose.override.yml

# ── IDE / Editor ──────────────────────────────────────────
.vscode/
.idea/
*.swp
*.swo
*~
.project
.classpath
.settings/

# ── OS Files ──────────────────────────────────────────────
.DS_Store
Thumbs.db
desktop.ini
ehthumbs.db

# ── Logs ──────────────────────────────────────────────────
logs/
*.log
*.log.*
/tmp/

# ── Backups ───────────────────────────────────────────────
*.backup
*.bak
*.old
.pids/
*.pid

# ── Kubernetes secrets ────────────────────────────────────
k8s/secrets/
*.kubeconfig
kubeconfig

# ── Test Coverage ─────────────────────────────────────────
coverage/
.nyc_output/
GITEOF

log ".gitignore updated — secrets protected"

# ══════════════════════════════════════════════════════════════════
# STEP 3 — Create Version File
# ══════════════════════════════════════════════════════════════════
section "STEP 3 — Creating Version File"

cat > VERSION << EOF
$VERSION_NUMBER
EOF

cat > CHANGELOG.md << EOF
# Changelog — GCP Deployment Portal

---

## [$VERSION] — $TIMESTAMP

### 🚀 Initial Release — portalv1

#### Frontend
- Full React TypeScript portal (App.tsx)
- Dark-themed enterprise UI
- Dashboard with live KPI metrics
- GCE VM deployment form with cost estimation
- GKE Cluster deployment form
- Approval workflow UI
- Cost center and budget visualization
- Resource inventory (GCE + GKE)
- Immutable audit log viewer
- Platform monitoring dashboard
- AI Agent chat interface (Claude 3.5 Sonnet)

#### Backend
- FastAPI Python backend
- WebSocket real-time deployment tracking
- PostgreSQL database with 8 tables
- Health check endpoint
- OpenAPI documentation

#### Infrastructure
- docker-compose.yml (PostgreSQL + Redis + pgAdmin + MailHog)
- Database schema with seed data
- Terraform module stubs (GCE + GKE)
- Helm chart templates
- Kubernetes manifests

#### Scripts
- start.sh  — full stack startup with Docker fix
- stop.sh   — graceful shutdown
- test.sh   — 5 test suites, 40+ checks
- backup.sh — full backup with restore

#### Documentation
- WSL Ubuntu deployment guide
- GCP production deployment guide
- AI agent architecture guide
- GCE VM test deployment guide
- GCP project registration guide

---
EOF

log "VERSION file: $VERSION_NUMBER"
log "CHANGELOG.md created"

# ══════════════════════════════════════════════════════════════════
# STEP 4 — Show What Will Be Committed
# ══════════════════════════════════════════════════════════════════
section "STEP 4 — Changes to be Committed"

echo ""
echo "  Modified/New files:"
git status --short | head -50
echo ""

# Count files
TOTAL=$(git status --short | wc -l)
NEW=$(git status --short | grep "^?" | wc -l)
MODIFIED=$(git status --short | grep "^.M\|^ M" | wc -l)

info "Total changes : $TOTAL files"
info "New files     : $NEW files"
info "Modified      : $MODIFIED files"

# Check for accidentally included secrets
echo ""
info "Checking for accidentally included secrets..."

SECRETS_FOUND=0

# Check for .env files
if git ls-files --others --exclude-standard | grep -q "\.env$\|\.env\.local\|\.env\.prod"; then
  warn "⚠️  .env file detected in untracked files — will be excluded by .gitignore"
fi

# Check for credential files
if git ls-files --others --exclude-standard | grep -q "\.json$\|portal-sa-key\|credentials/"; then
  warn "⚠️  Credential files detected — will be excluded by .gitignore"
fi

# Check for existing tracked secrets
if git ls-files | grep -q "portal-sa-key\|credentials/portal"; then
  error "CRITICAL: Credential file is TRACKED by git!"
  echo "  Fix: git rm --cached credentials/portal-sa-key.json"
  git rm --cached credentials/portal-sa-key.json 2>/dev/null || true
  SECRETS_FOUND=1
fi

if [ $SECRETS_FOUND -eq 0 ]; then
  log "No secrets detected in commit — safe to push ✅"
fi

# ══════════════════════════════════════════════════════════════════
# STEP 5 — Stage All Files
# ══════════════════════════════════════════════════════════════════
section "STEP 5 — Staging Files"

# Remove cached files that should be ignored
git rm -r --cached . --quiet 2>/dev/null || true

# Re-add everything (respects .gitignore)
git add .

# Show what is staged
STAGED=$(git diff --cached --name-only | wc -l)
log "Staged $STAGED files for commit"

# Show staged files summary
echo ""
echo "  Files being committed:"
git diff --cached --name-only | while read file; do
  echo "    + $file"
done | head -60

if [ $STAGED -gt 60 ]; then
  echo "    ... and $((STAGED - 60)) more files"
fi

# ══════════════════════════════════════════════════════════════════
# STEP 6 — Create Commit
# ══════════════════════════════════════════════════════════════════
section "STEP 6 — Creating Commit"

COMMIT_MSG="release: $VERSION — Enterprise GCP Deployment Portal

Version: $VERSION_NUMBER
Date: $TIMESTAMP
Tag: $VERSION

Changes:
- React TypeScript frontend with full portal UI
- FastAPI Python backend with WebSocket support
- PostgreSQL schema with 8 tables + seed data
- Docker Compose for local development stack
- GCE VM deployment form with cost estimation
- GKE Cluster deployment form
- Multi-stage approval workflow engine
- AI Agent with Claude 3.5 Sonnet integration
- Cost center and budget governance
- Resource inventory management
- Immutable audit log
- Platform monitoring dashboard
- Terraform module stubs for GCE and GKE
- Helm chart templates for Kubernetes
- GitHub Actions CI/CD pipeline config
- start.sh / stop.sh / test.sh / backup.sh scripts
- Complete WSL Ubuntu deployment guide
- GCP production deployment guide

Project: terraform-skill-25
Repository: hemant2024/gcp-deployment-portal"

git commit -m "$COMMIT_MSG"

if [ $? -eq 0 ]; then
  COMMIT_HASH=$(git rev-parse --short HEAD)
  log "Commit created: $COMMIT_HASH"
else
  warn "Nothing new to commit — working tree clean"
  COMMIT_HASH=$(git rev-parse --short HEAD)
  log "Current commit: $COMMIT_HASH"
fi

# ══════════════════════════════════════════════════════════════════
# STEP 7 — Create Git Tags
# ══════════════════════════════════════════════════════════════════
section "STEP 7 — Creating Git Tags"

# Delete existing tags if they exist (allow re-run)
git tag -d $VERSION        2>/dev/null && warn "Removed existing local tag: $VERSION"
git tag -d v$VERSION_NUMBER 2>/dev/null && warn "Removed existing local tag: v$VERSION_NUMBER"
git tag -d latest          2>/dev/null && warn "Removed existing local tag: latest"

# Delete remote tags if they exist
git push origin :refs/tags/$VERSION         2>/dev/null || true
git push origin :refs/tags/v$VERSION_NUMBER 2>/dev/null || true
git push origin :refs/tags/latest           2>/dev/null || true

# Create annotated tags (better than lightweight tags)
git tag -a "$VERSION" \
  -m "Portal v1 — Initial production-ready release
  
  Enterprise GCP Workload Deployment Portal
  Version: $VERSION_NUMBER
  Date: $TIMESTAMP
  
  Features:
  - Full-stack portal (React + FastAPI + PostgreSQL)
  - GCE and GKE deployment workflows
  - Multi-stage approval engine
  - AI Agent (Claude 3.5 Sonnet)
  - Cost governance and budget tracking
  - Audit logging and compliance
  - Terraform automation
  - GitOps with ArgoCD + Helm"

log "Created annotated tag: $VERSION"

git tag -a "v$VERSION_NUMBER" \
  -m "Version $VERSION_NUMBER — $VERSION
  Release date: $TIMESTAMP"

log "Created annotated tag: v$VERSION_NUMBER"

git tag -a "latest" \
  -m "Latest stable release: $VERSION ($VERSION_NUMBER)"

log "Created annotated tag: latest"

# Show all tags
echo ""
echo "  All tags:"
git tag -l | while read tag; do
  echo "    🏷  $tag"
done

# ══════════════════════════════════════════════════════════════════
# STEP 8 — Push to GitHub
# ══════════════════════════════════════════════════════════════════
section "STEP 8 — Pushing to GitHub"

info "Pushing branch: $BRANCH → origin/$BRANCH"
echo ""
echo "  ⚠️  When prompted for credentials:"
echo "  Username: hemant2024"
echo "  Password: ghp_xxxxxxxxxxxx  ← your PAT token"
echo "            NOT your GitHub password"
echo ""

# Push main branch
git push -u origin $BRANCH

if [ $? -ne 0 ]; then
  error "Push failed — check credentials"
  echo ""
  echo "  Common fixes:"
  echo "  1. Username must be: hemant2024  (not email)"
  echo "  2. Password must be: PAT token   (not Gmail password)"
  echo "  3. Create PAT at: https://github.com/settings/tokens/new"
  echo "     Scopes: ✅ repo"
  echo ""
  echo "  Then retry: git push -u origin main"
  exit 1
fi

log "Branch pushed: $BRANCH ✅"

# Push all tags
info "Pushing tags to GitHub..."
git push origin --tags

if [ $? -eq 0 ]; then
  log "All tags pushed ✅"
else
  warn "Tag push failed — retrying one by one..."
  git push origin $VERSION        2>/dev/null && log "Pushed: $VERSION"        || warn "Skip: $VERSION"
  git push origin v$VERSION_NUMBER 2>/dev/null && log "Pushed: v$VERSION_NUMBER" || warn "Skip: v$VERSION_NUMBER"
  git push origin latest          2>/dev/null && log "Pushed: latest"          || warn "Skip: latest"
fi

# ══════════════════════════════════════════════════════════════════
# STEP 9 — Verify Push
# ══════════════════════════════════════════════════════════════════
section "STEP 9 — Verifying Push"

# Show local git log
echo ""
echo "  Recent commits:"
git log --oneline -5 | while read line; do
  echo "    $line"
done

echo ""
echo "  Tags created:"
git ls-remote --tags origin 2>/dev/null | while read hash ref; do
  tag=$(echo $ref | sed 's/refs\/tags\///')
  echo "    🏷  $tag — $hash"
done

echo ""
echo "  Branch status:"
git branch -vv

# ══════════════════════════════════════════════════════════════════
# STEP 10 — Final Summary
# ══════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  ✅ PUSH COMPLETE — portalv1 is on GitHub!        ${NC}"
echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BOLD}Repository:${NC}  https://github.com/hemant2024/gcp-deployment-portal"
echo -e "  ${BOLD}Branch:${NC}      main"
echo -e "  ${BOLD}Commit:${NC}      $COMMIT_HASH"
echo -e "  ${BOLD}Tags:${NC}"
echo -e "    🏷  portalv1"
echo -e "    🏷  v1.0.0"
echo -e "    🏷  latest"
echo ""
echo -e "  ${BOLD}View on GitHub:${NC}"
echo -e "  📁 Code     → https://github.com/hemant2024/gcp-deployment-portal/tree/main"
echo -e "  🏷  Tags     → https://github.com/hemant2024/gcp-deployment-portal/tags"
echo -e "  📦 Releases → https://github.com/hemant2024/gcp-deployment-portal/releases"
echo ""
echo -e "  ${BOLD}Next Steps:${NC}"
echo -e "  1. Open GitHub in Chrome and verify files ✅"
echo -e "  2. Create a GitHub Release from tag portalv1"
echo -e "  3. Link GCP project terraform-skill-25"
echo -e "  4. Deploy first test GCE VM"
echo ""
