# 📦 GCP Portal V1 → V2 Upgrade Guide

**Current Version**: V1.0.0  
**Target Version**: V2.0.0  
**Upgrade Type**: Major (Real deployment + Approval workflow)  

---

## 🚀 Quick Upgrade (5 minutes)

```bash
# 1. Stop V1 services
docker-compose down

# 2. Backup database
docker-compose exec postgres pg_dump gcp_portal > backup_v1.sql

# 3. Update code
cd gcp-deployment-portal
git pull origin main

# 4. Update environment
cp .env.example .env

# 5. Migrate database
docker-compose up -d postgres
sleep 10
docker-compose run --rm backend python scripts/migrate_v1_to_v2.py

# 6. Start V2
docker-compose up -d

# 7. Verify
curl http://localhost:8000/health
```

---

## 📋 Pre-Upgrade Checklist

Before upgrading, ensure:

- ✅ All V1 deployments documented
- ✅ Database backup created
- ✅ GCP service account ready
- ✅ No active deployment requests
- ✅ Team notified

---

## 🔄 What Changed (V1 → V2)

### New Features

| Feature | V1 | V2 |
|---------|----|----|
| Real GCP Deployment | ❌ Mock | ✅ Real |
| Approval Workflow | ❌ Basic | ✅ Full Multi-level |
| Cost Tracking | ❌ Estimated | ✅ Real from GCP |
| Audit Logging | ❌ Minimal | ✅ Complete |
| Resource Lifecycle | ❌ No | ✅ Full |
| Frontend Pages | 2 pages | 7 pages |
| API Endpoints | 10 | 23 |

---

## ✅ Post-Upgrade Verification

### Frontend
```bash
# 1. Visit http://localhost:3000
# 2. Create account
# 3. Go to Dashboard
# 4. Create GCE deployment
# 5. Submit for approval
# 6. Approve in Approvals page
# 7. Click Deploy
```

### Backend
```bash
curl http://localhost:8000/health
curl http://localhost:8000/api/v1/deployments
```

### GCP Integration
```bash
curl http://localhost:8000/api/v1/catalog/machines?region=us-central1
```

---

## 🔄 Rollback Procedure

If you need to rollback to V1:

```bash
# 1. Stop V2
docker-compose down

# 2. Restore V1 database
docker-compose up -d postgres
psql -U postgres gcp_portal < backup_v1.sql

# 3. Revert code
git checkout v1.0.0
git pull

# 4. Restart V1
docker-compose up -d
```

---

**V2 is now production-ready! 🎉**
