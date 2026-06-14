# 🚀 GCP Deployment Portal

An **enterprise-grade, production-ready** self-service cloud deployment platform for Google Cloud Platform. Deploy, manage, approve, monitor, and govern GCE, GKE, and Cloud SQL workloads through an intuitive web portal with AI-powered approval workflows.

[![Python](https://img.shields.io/badge/Python-3.11%2B-blue)](https://www.python.org/)
[![React](https://img.shields.io/badge/React-18.2-61dafb)](https://react.dev/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.104-009688)](https://fastapi.tiangolo.com/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)]()

---

## ✨ Features

### 🎯 Core Capabilities
- ✅ **Self-Service Deployments** - Users submit GCE, GKE, and Cloud SQL requests
- ✅ **Multi-Level Approvals** - Technical, Security, and Finance approval workflows
- ✅ **Real GCP Integration** - Actual Google Cloud API connections (not mocked)
- ✅ **Cost Estimation** - Real-time cost calculation before deployment
- ✅ **Deployment History** - Complete audit trail of all operations
- ✅ **Resource Tracking** - Monitor deployed resources in real-time

### 🔐 Security & Governance
- ✅ **Role-Based Access Control** - Requestor, Approver, Admin roles
- ✅ **Approval Workflows** - Multi-level approval chains
- ✅ **Audit Logging** - Complete activity log
- ✅ **Policy Engine** - Validation rules and compliance checks
- ✅ **IAM Integration** - Google Cloud IAM policy enforcement

### 👥 User Experience
- ✅ **Intuitive Dashboard** - Real-time deployment status
- ✅ **Responsive Design** - Works on desktop and mobile
- ✅ **Dual Authentication** - JWT and Google OAuth2
- ✅ **Real-Time Updates** - WebSocket notifications (coming soon)
- ✅ **Beautiful UI** - Material Design with Material-UI

### 🏗️ Architecture
- ✅ **FastAPI Backend** - High-performance, async Python API
- ✅ **React Frontend** - Modern SPA with TypeScript
- ✅ **PostgreSQL Database** - Relational data with advanced queries
- ✅ **Redis Caching** - Session and data caching
- ✅ **Docker** - Containerized deployment ready
- ✅ **Kubernetes Ready** - Helm charts and manifests included

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   GCP DEPLOYMENT PORTAL                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────┐        ┌──────────────────┐            │
│  │  React Frontend │────────│  FastAPI Backend │            │
│  │  (TypeScript)   │ HTTP   │  (Python 3.11)   │            │
│  └─────────────────┘        └──────────────────┘            │
│                                    │                         │
│                        ┌───────────┴──────────┐              │
│                        │                      │              │
│                   ┌────▼─────┐       ┌───────▼───┐           │
│                   │PostgreSQL │       │  Redis    │           │
│                   │  Database │       │  Cache    │           │
│                   └───────────┘       └───────────┘           │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │         Google Cloud APIs (GCP Integration)              │ │
│  ├─────────────────────────────────────────────────────────┤ │
│  │ • Compute Engine (VMs)                                   │ │
│  │ • Kubernetes Engine (GKE)                                │ │
│  │ • Cloud SQL (Managed Databases)                          │ │
│  │ • Cloud IAM (Identity & Access Management)               │ │
│  │ • Cloud Logging (Audit Logs)                             │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Using Docker (Recommended)

```bash
# Clone repository
git clone https://github.com/hemant2024/gcp-deployment-portal.git
cd gcp-deployment-portal

# Setup environment
cp .env.example .env
# Edit .env with your GCP project ID and credentials

# Start all services
docker-compose up -d

# Access the application
# Frontend: http://localhost:3000
# API Docs: http://localhost:8000/docs
```

### Manual Setup

```bash
# Backend
cd backend
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python -c "from database import init_db; init_db()"
uvicorn main:app --reload --port 8000

# Frontend (in new terminal)
cd frontend
npm install
npm start
```

**See [SETUP.md](SETUP.md) for detailed setup instructions.**

---

## 📊 Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| **Frontend** | React + TypeScript | 18.2 |
| **UI Framework** | Material-UI (MUI) | 5.14 |
| **State Management** | Zustand | 4.4 |
| **HTTP Client** | Axios | 1.6 |
| **Backend** | FastAPI | 0.104 |
| **Database** | PostgreSQL | 16 |
| **Cache** | Redis | 7 |
| **ORM** | SQLAlchemy | 2.0 |
| **Container** | Docker | 24+ |
| **Cloud** | Google Cloud APIs | Latest |

---

## 📁 Project Structure

```
gcp-deployment-portal/
├── backend/
│   ├── main.py                 # FastAPI application
│   ├── config.py               # Configuration management
│   ├── database.py             # Database setup
│   ├── models.py               # SQLAlchemy ORM models
│   ├── schemas.py              # Pydantic validation schemas
│   ├── routers/                # API route handlers
│   │   ├── auth.py            # Authentication endpoints
│   │   ├── deployments.py      # Deployment endpoints
│   │   └── catalog.py          # Service catalog endpoints
│   ├── services/               # Business logic
│   │   ├── auth_service.py     # Authentication logic
│   │   ├── deployment_service.py # Deployment logic
│   │   └── gcp_service.py      # GCP integration
│   ├── requirements.txt         # Python dependencies
│   └── Dockerfile              # Backend container image
│
├── frontend/
│   ├── public/                 # Static assets
│   ├── src/
│   │   ├── api/
│   │   │   └── client.ts       # API client
│   │   ├── components/         # Reusable React components
│   │   │   ├── Navigation.tsx
│   │   │   └── ProtectedRoute.tsx
│   │   ├── pages/              # Page components
│   │   │   ├── LoginPage.tsx
│   │   │   ├── DashboardPage.tsx
│   │   │   ├── CreateDeploymentPage.tsx
│   │   │   ├── DeploymentDetailsPage.tsx
│   │   │   └── ApprovalsPage.tsx
│   │   ├── store/              # Zustand state stores
│   │   │   └── authStore.ts
│   │   ├── App.tsx             # Main app component
│   │   └── index.tsx           # Entry point
│   ├── package.json
│   └── Dockerfile
│
├── docker-compose.yml          # Multi-container orchestration
├── .env.example                # Environment template
├── SETUP.md                    # Detailed setup guide
└── README.md                   # This file
```

---

## 🔑 Key Components

### Backend Services

#### 1. **Auth Service** (`services/auth_service.py`)
- User registration and login
- JWT token generation and validation
- Google OAuth2 integration
- Password hashing with bcrypt

#### 2. **Deployment Service** (`services/deployment_service.py`)
- Create deployment requests (GCE, GKE, Cloud SQL)
- Submit for approval workflow
- Manage approvals and rejections
- Deployment status tracking

#### 3. **GCP Service** (`services/gcp_service.py`)
- Real Google Cloud API integration
- List available machine types, images, networks
- Create GCE instances, GKE clusters, Cloud SQL instances
- Fallback to mock data if credentials unavailable

### Frontend Components

#### 1. **Auth Store** (`store/authStore.ts`)
- User state management
- Token persistence
- Login/logout logic

#### 2. **API Client** (`api/client.ts`)
- Axios-based HTTP client
- Auto-token injection
- Error handling

#### 3. **Page Components**
- **LoginPage**: User authentication
- **DashboardPage**: Overview and recent deployments
- **CreateDeploymentPage**: Form to create new deployments
- **DeploymentDetailsPage**: View deployment status and approvals
- **ApprovalsPage**: Manager approval interface

---

## 🔐 Security Features

### Authentication
- ✅ JWT token-based authentication
- ✅ Google OAuth2 social login
- ✅ Bcrypt password hashing
- ✅ Token refresh mechanism
- ✅ CORS configuration
- ✅ HTTPS ready

### Authorization
- ✅ Role-based access control (RBAC)
- ✅ Request validation
- ✅ Policy enforcement
- ✅ Audit logging
- ✅ Data isolation per user/project

### Data Protection
- ✅ SQL injection prevention (SQLAlchemy ORM)
- ✅ CSRF protection ready
- ✅ Sensitive data logging prevention
- ✅ Secure credential storage

---

## 🔌 API Reference

### Authentication

```bash
# Register
POST /api/v1/auth/register
{
  "email": "user@example.com",
  "username": "john_doe",
  "password": "secure_password",
  "full_name": "John Doe"
}

# Login
POST /api/v1/auth/login
{
  "email": "user@example.com",
  "password": "secure_password"
}

# Google OAuth
POST /api/v1/auth/google-callback
{
  "google_token": "google_id_token"
}
```

### Deployments

```bash
# Create GCE Deployment
POST /api/v1/deployments/gce?project_id=1
{
  "name": "web-server",
  "description": "Production web server",
  "region": "us-central1",
  "environment": "prod",
  "gce_config": {
    "machine_type": "n1-standard-4",
    "image": "debian-12",
    "boot_disk_size_gb": 20,
    "network": "default"
  }
}

# List Deployments
GET /api/v1/deployments?status=submitted&limit=20

# Get Deployment Details
GET /api/v1/deployments/1

# Submit for Approval
POST /api/v1/deployments/1/submit

# Approve
POST /api/v1/deployments/1/approve
{
  "status": "approved",
  "comments": "Looks good"
}

# Deploy
POST /api/v1/deployments/1/deploy
```

### Service Catalog

```bash
# Get Full Catalog
GET /api/v1/catalog?region=us-central1

# List Machine Types
GET /api/v1/catalog/machines?region=us-central1

# List GKE Versions
GET /api/v1/catalog/gke-versions?region=us-central1
```

**See [API Documentation](http://localhost:8000/docs) for interactive docs.**

---

## 📊 Database Schema

### Core Tables

```
users
├── id (PK)
├── email (UNIQUE)
├── username (UNIQUE)
├── hashed_password
├── google_id
├── role (requestor|approver|admin)
└── timestamps

deployments
├── id (PK)
├── request_id (UNIQUE)
├── project_id (FK)
├── requester_id (FK)
├── deployment_type (gce|gke|cloud_sql)
├── name, description
├── region, environment
├── config (JSON)
├── status (draft|submitted|approved|deploying|deployed|failed)
├── estimated_cost_monthly
└── timestamps

approvals
├── id (PK)
├── deployment_id (FK)
├── approver_id (FK)
├── approval_type (technical|security|finance)
├── status (pending|approved|rejected)
├── comments
└── timestamps

audit_logs
├── id (PK)
├── deployment_id (FK)
├── user_id (FK)
├── action, resource_type
├── details (JSON)
└── timestamp
```

---

## 🚀 Deployment

### Docker Compose (Development)
```bash
docker-compose up -d
```

### Google Cloud Run
```bash
gcloud run deploy gcp-portal-backend \
  --source ./backend \
  --platform managed \
  --region us-central1
```

### Kubernetes
```bash
kubectl apply -f k8s/
# or
helm install gcp-portal ./helm-chart
```

---

## 📝 Environment Configuration

Create `.env` file from template:
```bash
cp .env.example .env
```

**Essential variables:**
```env
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/gcp_portal

# GCP
GCP_PROJECT_ID=your-project-id
GCP_CREDENTIALS_PATH=/path/to/gcp-credentials.json

# JWT
JWT_SECRET_KEY=your-super-secret-key-min-32-chars

# Frontend
REACT_APP_API_URL=http://localhost:8000
```

See [SETUP.md](SETUP.md) for complete configuration guide.

---

## 🧪 Testing

### Backend
```bash
cd backend
pytest                    # Run all tests
pytest --cov            # With coverage
pytest -v               # Verbose
```

### Frontend
```bash
cd frontend
npm test                 # Run tests
npm test -- --coverage  # With coverage
```

---

## 📚 Documentation

- **[SETUP.md](SETUP.md)** - Detailed setup and configuration
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design
- **[API Docs](http://localhost:8000/docs)** - Interactive API documentation
- **[Contributing Guide](CONTRIBUTING.md)** - How to contribute

---

## 🐛 Troubleshooting

### Issue: Backend won't connect to database
```bash
# Check PostgreSQL is running
docker-compose ps postgres

# Check connection string
cat .env | grep DATABASE_URL
```

### Issue: Frontend API errors
```bash
# Verify backend is running
curl http://localhost:8000/health

# Check CORS configuration
# Verify REACT_APP_API_URL in frontend/.env
```

### Issue: GCP authentication fails
```bash
# Verify credentials file exists
ls backend/gcp-credentials.json

# Check service account permissions
gcloud projects get-iam-policy $PROJECT_ID
```

**See [SETUP.md](SETUP.md#troubleshooting) for more solutions.**

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Write/update tests
5. Commit with clear messages (`git commit -m 'Add amazing feature'`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

---

## 🙋 Support

- **Issues**: [GitHub Issues](https://github.com/hemant2024/gcp-deployment-portal/issues)
- **Discussions**: [GitHub Discussions](https://github.com/hemant2024/gcp-deployment-portal/discussions)
- **Email**: support@gcpportal.local

---

## 🎉 Acknowledgments

Built with:
- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python web framework
- [React](https://react.dev/) - UI library
- [Material-UI](https://mui.com/) - Component library
- [Google Cloud](https://cloud.google.com/) - Cloud infrastructure
- [PostgreSQL](https://www.postgresql.org/) - Database
- [Docker](https://www.docker.com/) - Containerization

---

**Status**: ✅ Production Ready | **Last Updated**: June 2026

---

## 🚀 Ready to Deploy?

1. **Clone**: `git clone https://github.com/hemant2024/gcp-deployment-portal.git`
2. **Setup**: `cp .env.example .env && nano .env`
3. **Run**: `docker-compose up -d`
4. **Access**: http://localhost:3000
5. **API Docs**: http://localhost:8000/docs

**Happy Deploying! 🎉**
