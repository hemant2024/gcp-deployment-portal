# 🚀 Enterprise GCP Deployment Portal

An enterprise-grade self-service cloud deployment platform for
Google Cloud Platform (GCP). Deploy, manage, approve, monitor,
and govern GCE and GKE workloads through a web portal and
AI-powered chatbot.

---

## 🏗 Architecture

| Layer       | Technology                              |
|-------------|-----------------------------------------|
| Frontend    | React.js + TypeScript + Material UI     |
| Backend     | Python FastAPI + WebSockets             |
| Database    | PostgreSQL 16 / Cloud SQL               |
| AI Agent    | Anthropic Claude 3.5 Sonnet             |
| GitOps      | ArgoCD + Helm                           |
| IaC         | Terraform                               |
| Runtime     | GKE (Google Kubernetes Engine)          |
| CI/CD       | GitHub Actions                          |

---

## 👥 User Roles

- **Requestor** — Submit deployment requests
- **Technical Approver** — Review specs
- **Security Approver** — Validate compliance
- **Finance Approver** — Review costs
- **Cloud Administrator** — Execute deployments
- **Auditor** — View logs and reports

---

## 🚦 Quick Start (Local WSL)

```bash

# 1. Start infrastructure
docker compose up -d

# 2. Start backend
cd backend && source venv/bin/activate
uvicorn main:app --reload --port 8000

# 3. Start frontend
cd frontend && npm start
bash

Access:

Service	URL
Portal UI	 http://localhost:3000
API Docs	 http://localhost:8000/api/docs
pgAdmin	 http://localhost:5050
MailHog	 http://localhost:8025
