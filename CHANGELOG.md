# Changelog — GCP Deployment Portal

---

## [portalv1] — 2026-06-13 14:24:37

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
