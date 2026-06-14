#!/bin/bash
#
# GCP Portal V1 → V2 Upgrade Script
# Complete automated upgrade from V1 to V2
#

set -e

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║  GCP PORTAL V1 → V2 UPGRADE                       ║"
echo "║  Automated Migration & Deployment                 ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed."
    exit 1
fi
echo "✓ Docker found"

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed."
    exit 1
fi
echo "✓ Docker Compose found"

echo ""
echo "Backing up V1 data..."
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

if docker-compose ps postgres | grep -q "postgres"; then
    docker-compose exec -T postgres pg_dump -U postgres gcp_portal > "$BACKUP_DIR/v1_database.sql"
    echo "✓ Database backed up"
fi

if [ -f ".env" ]; then
    cp .env "$BACKUP_DIR/.env.v1.backup"
    echo "✓ Environment file backed up"
fi

echo ""
echo "Stopping V1 services..."
docker-compose down
echo "✓ V1 services stopped"

echo ""
echo "Pulling V2 code..."
git pull origin main
echo "✓ V2 code pulled"

echo ""
echo "Starting PostgreSQL..."
docker-compose up -d postgres
sleep 10
echo "✓ PostgreSQL started"

echo ""
echo "Running migration..."
docker-compose run --rm backend python scripts/migrate_v1_to_v2.py
echo "✓ Migration completed"

echo ""
echo "Starting V2 services..."
docker-compose up -d
sleep 15
echo "✓ All services started"

echo ""
echo "Checking service health..."
if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "✓ API is healthy"
fi

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║  ✅ UPGRADE COMPLETE!                             ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "Access your V2 Portal:"
echo "  Frontend:  http://localhost:3000"
echo "  API Docs:  http://localhost:8000/docs"
echo "  pgAdmin:   http://localhost:5050"
echo ""
echo "Backup Information:"
echo "  Location: $BACKUP_DIR/"
echo ""
