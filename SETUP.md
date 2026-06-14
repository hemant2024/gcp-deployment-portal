# GCP Deployment Portal - Complete Setup Guide

A production-ready, enterprise-grade self-service cloud deployment platform for Google Cloud Platform with AI-powered approval workflows.

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start (Docker)](#quick-start-docker)
- [Manual Setup (Development)](#manual-setup-development)
- [GCP Integration](#gcp-integration)
- [Configuration](#configuration)
- [Database Initialization](#database-initialization)
- [Running the Application](#running-the-application)
- [API Documentation](#api-documentation)
- [Frontend Development](#frontend-development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### System Requirements
- Docker & Docker Compose 2.0+ (for containerized setup)
- Python 3.11+ (for manual backend setup)
- Node.js 18+ (for frontend development)
- PostgreSQL 16+ (if not using Docker)
- Git

### GCP Requirements
- GCP Project with billing enabled
- Service Account with appropriate permissions
- GCP Credentials JSON file

### Optional
- Google OAuth2 credentials for social login
- SMTP server for email notifications

---

## Quick Start (Docker)

### 1. Clone Repository
```bash
git clone https://github.com/hemant2024/gcp-deployment-portal.git
cd gcp-deployment-portal
```

### 2. Setup Environment
```bash
# Copy environment template
cp .env.example .env

# Edit .env with your configuration
nano .env
```

### 3. Start Services
```bash
# Start all services (database, backend, frontend, etc.)
docker-compose up -d

# View logs
docker-compose logs -f backend
```

### 4. Initialize Database
```bash
# The database is auto-initialized on first run
# To manually seed data:
docker-compose exec backend python -c "from database import init_db; init_db()"
```

### 5. Access Applications

| Service | URL | Credentials |
|---------|-----|-------------|
| Frontend (Portal) | http://localhost:3000 | Test user |
| API Docs | http://localhost:8000/docs | N/A |
| pgAdmin | http://localhost:5050 | admin@admin.com / admin |
| MailHog | http://localhost:8025 | N/A |
| Redis Insight | http://localhost:8001 | N/A |

---

## Manual Setup (Development)

### 1. Backend Setup

#### Create Virtual Environment
```bash
cd backend
python3.11 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

#### Install Dependencies
```bash
pip install -r requirements.txt
```

#### Create `.env` File
```bash
cp ../. env.example .env
nano .env
```

#### Initialize Database
```bash
python -c "from database import init_db; init_db()"
```

#### Start Backend
```bash
uvicorn main:app --reload --port 8000
```

### 2. Frontend Setup

#### Install Dependencies
```bash
cd frontend
npm install
```

#### Create `.env` File
```bash
echo "REACT_APP_API_URL=http://localhost:8000" > .env
```

#### Start Frontend Dev Server
```bash
npm start
```

---

## GCP Integration

### 1. Create GCP Service Account

```bash
# Set your GCP project ID
PROJECT_ID="your-project-id"

# Create service account
gcloud iam service-accounts create gcp-portal \
  --display-name="GCP Deployment Portal"

# Grant necessary roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:gcp-portal@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/compute.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:gcp-portal@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:gcp-portal@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudsql.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:gcp-portal@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.securityAdmin"
```

### 2. Create and Download Credentials

```bash
# Create key
gcloud iam service-accounts keys create gcp-credentials.json \
  --iam-account=gcp-portal@$PROJECT_ID.iam.gserviceaccount.com

# Move to backend directory
mv gcp-credentials.json backend/

# Set in .env
echo "GCP_CREDENTIALS_PATH=/app/gcp-credentials.json" >> .env
```

### 3. Enable Required APIs

```bash
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  sqladmin.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com
```

---

## Configuration

### Environment Variables

#### Backend (`backend/.env`)
```env
# Database
DATABASE_URL=postgresql://user:password@host:5432/dbname

# JWT Authentication
JWT_SECRET_KEY=your-secret-key-min-32-characters
JWT_ALGORITHM=HS256
JWT_EXPIRATION_HOURS=24

# Google OAuth (Optional)
GOOGLE_CLIENT_ID=client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=client-secret

# GCP Configuration
GCP_PROJECT_ID=my-project-id
GCP_CREDENTIALS_PATH=/path/to/gcp-credentials.json

# Email
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password

# Debug
DEBUG=false
```

#### Frontend (`frontend/.env`)
```env
REACT_APP_API_URL=http://localhost:8000
REACT_APP_GOOGLE_CLIENT_ID=client-id.apps.googleusercontent.com
```

---

## Database Initialization

### Automatic Initialization
The database schema is automatically created on the first API call.

### Manual Initialization
```bash
# Using Python
python -c "from database import init_db; init_db()"

# Using Docker
docker-compose exec backend python -c "from database import init_db; init_db()"
```

### Database Schema

**Tables:**
- `users` - User accounts and authentication
- `gcp_projects` - GCP projects accessible to users
- `deployments` - Cloud deployment requests
- `approvals` - Multi-level approval workflow
- `gcp_resources` - Tracked cloud resources
- `audit_logs` - Complete audit trail
- `service_catalog` - Available services and options

---

## Running the Application

### Development Mode

#### Using Docker Compose
```bash
# Start all services
docker-compose up -d

# View specific service logs
docker-compose logs -f backend
docker-compose logs -f frontend

# Stop all services
docker-compose down
```

#### Manual (Two Terminals)

**Terminal 1 - Backend:**
```bash
cd backend
source venv/bin/activate
uvicorn main:app --reload --port 8000
```

**Terminal 2 - Frontend:**
```bash
cd frontend
npm start
```

### Production Mode

#### Using Docker
```bash
# Build images
docker-compose -f docker-compose.yml build

# Start services
docker-compose up -d

# View status
docker-compose ps
```

#### Manual Deployment
```bash
# Backend
cd backend
gunicorn main:app -w 4 -b 0.0.0.0:8000

# Frontend
cd frontend
npm run build
serve -s build -l 3000
```

---

## API Documentation

### Interactive Docs
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

### API Endpoints

#### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login with email/password
- `POST /api/v1/auth/google-callback` - Google OAuth callback
- `POST /api/v1/auth/refresh` - Refresh access token

#### Deployments
- `POST /api/v1/deployments/gce` - Create GCE VM deployment
- `POST /api/v1/deployments/gke` - Create GKE cluster deployment
- `POST /api/v1/deployments/cloud-sql` - Create Cloud SQL deployment
- `GET /api/v1/deployments` - List deployments
- `GET /api/v1/deployments/{id}` - Get deployment details
- `POST /api/v1/deployments/{id}/submit` - Submit for approval
- `POST /api/v1/deployments/{id}/approve` - Approve deployment
- `POST /api/v1/deployments/{id}/reject` - Reject deployment
- `POST /api/v1/deployments/{id}/deploy` - Deploy approved request

#### Catalog
- `GET /api/v1/catalog` - Get complete service catalog
- `GET /api/v1/catalog/machines` - List available machine types
- `GET /api/v1/catalog/images` - List available VM images
- `GET /api/v1/catalog/networks` - List VPC networks
- `GET /api/v1/catalog/gke-versions` - List GKE versions

---

## Frontend Development

### Project Structure
```
frontend/
├── public/
├── src/
│   ├── api/           # API client
│   ├── components/    # Reusable components
│   ├── pages/         # Page components
│   ├── store/         # Zustand state management
│   ├── App.tsx        # Main app component
│   └── index.tsx      # Entry point
├── package.json
└── Dockerfile
```

### Development Scripts
```bash
# Start dev server (with hot reload)
npm start

# Build for production
npm run build

# Run tests
npm test

# Linting
npm run lint

# Format code
npm run format
```

### Key Libraries
- **React Router** - Routing
- **Material-UI** - UI components
- **Axios** - HTTP client
- **Zustand** - State management
- **Formik** - Form handling
- **Recharts** - Charts & graphs

---

## Testing

### Backend Tests
```bash
cd backend

# Run all tests
pytest

# Run with coverage
pytest --cov=.

# Run specific test file
pytest tests/test_auth.py

# Run specific test
pytest tests/test_auth.py::test_login
```

### Frontend Tests
```bash
cd frontend

# Run tests
npm test

# Run with coverage
npm test -- --coverage

# Update snapshots
npm test -- -u
```

---

## Deployment

### To Google Cloud Run

#### Backend
```bash
cd backend

# Build image
gcloud builds submit --tag gcr.io/$PROJECT_ID/gcp-portal-backend

# Deploy
gcloud run deploy gcp-portal-backend \
  --image gcr.io/$PROJECT_ID/gcp-portal-backend \
  --platform managed \
  --region us-central1 \
  --set-env-vars DATABASE_URL=<your-db-url>
```

#### Frontend
```bash
cd frontend

# Build
npm run build

# Deploy to Firebase Hosting
firebase init hosting
firebase deploy --only hosting
```

### To Kubernetes

```bash
# Install GKE cluster
gcloud container clusters create gcp-portal \
  --zone us-central1-a \
  --num-nodes 3

# Deploy using Helm (if available)
helm install gcp-portal ./helm-chart

# Or use kubectl
kubectl apply -f k8s/
```

---

## Troubleshooting

### Backend Won't Start

**Problem: `Address already in use`**
```bash
# Kill process on port 8000
lsof -ti:8000 | xargs kill -9
```

**Problem: `Database connection refused`**
```bash
# Check if PostgreSQL is running
docker-compose ps postgres

# Restart PostgreSQL
docker-compose restart postgres
```

### Frontend Not Loading

**Problem: `API connection refused`**
- Check backend is running: `curl http://localhost:8000/health`
- Verify `REACT_APP_API_URL` in frontend `.env`

**Problem: `Port 3000 already in use`**
```bash
# Kill process on port 3000
lsof -ti:3000 | xargs kill -9
```

### GCP Integration Not Working

**Problem: `Credentials not found`**
```bash
# Verify file exists
ls backend/gcp-credentials.json

# Check path in .env
cat backend/.env | grep GCP_CREDENTIALS_PATH

# Fix permissions
chmod 600 backend/gcp-credentials.json
```

**Problem: `Permission denied`**
- Verify service account has required roles
- Check IAM bindings: `gcloud projects get-iam-policy $PROJECT_ID`

### Database Issues

**Problem: `Table doesn't exist`**
```bash
# Re-initialize database
python -c "from database import reset_db; reset_db()"
```

**Problem: `Cannot connect to database`**
```bash
# Check connection string in .env
# Verify PostgreSQL service is running
docker-compose logs postgres
```

---

## Support & Documentation

- **Issues**: [GitHub Issues](https://github.com/hemant2024/gcp-deployment-portal/issues)
- **Discussions**: [GitHub Discussions](https://github.com/hemant2024/gcp-deployment-portal/discussions)
- **API Docs**: http://localhost:8000/docs
- **Architecture**: See `ARCHITECTURE.md`

---

## License

MIT License - See LICENSE file for details

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

**Last Updated**: June 2026  
**Status**: Production Ready
