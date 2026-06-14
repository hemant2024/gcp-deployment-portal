"""
Service catalog API routes
"""
import logging
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from schemas import CatalogResponse, ServiceCatalogItem
from services.gcp_service import GCPService
from database import get_db
from routers.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/catalog", tags=["catalog"])


@router.get("/machines")
async def list_machine_types(
    region: str = "us-central1",
    current_user = Depends(get_current_user),
):
    """Get available GCE machine types for a region"""
    try:
        gcp = GCPService("gcp-project-id")  # TODO: Use actual project ID
        machines = gcp.list_machine_types(region)
        return {"items": machines, "region": region}
    except Exception as e:
        return {"error": str(e), "items": []}


@router.get("/images")
async def list_images(
    family: str = "debian-12",
    current_user = Depends(get_current_user),
):
    """Get available VM images"""
    try:
        gcp = GCPService("gcp-project-id")
        images = gcp.list_images(family)
        return {"items": images, "family": family}
    except Exception as e:
        return {"error": str(e), "items": []}


@router.get("/networks")
async def list_networks(
    current_user = Depends(get_current_user),
):
    """Get available VPC networks"""
    try:
        gcp = GCPService("gcp-project-id")
        networks = gcp.list_networks()
        return {"items": networks}
    except Exception as e:
        return {"error": str(e), "items": []}


@router.get("/gke-versions")
async def list_gke_versions(
    region: str = "us-central1",
    current_user = Depends(get_current_user),
):
    """Get available GKE versions"""
    try:
        gcp = GCPService("gcp-project-id")
        versions = gcp.list_gke_versions(region)
        return {"items": versions, "region": region}
    except Exception as e:
        return {"error": str(e), "items": []}


@router.get("", response_model=CatalogResponse)
async def get_full_catalog(
    region: str = "us-central1",
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get complete service catalog"""
    try:
        gcp = GCPService("gcp-project-id")

        # Get all catalog items
        machines = gcp.list_machine_types(region)
        gke_versions = gcp.list_gke_versions(region)
        images = gcp.list_images()
        networks = gcp.list_networks()

        # Extract data
        machine_names = [m["name"] for m in machines]
        image_names = [i["name"] for i in images]
        network_names = [n["name"] for n in networks]

        # Format as ServiceCatalogItems
        gce_machines = [
            ServiceCatalogItem(
                id=i,
                service_type="gce",
                region=region,
                option_key=m["name"],
                option_value=m["name"],
                description=f"{m['cpu_count']} CPU, {m['memory_mb']}MB RAM",
                pricing_per_month=25.0,  # Mock pricing
                is_available=True,
            )
            for i, m in enumerate(machines)
        ]

        gke_tiers = [
            ServiceCatalogItem(
                id=i,
                service_type="gke",
                region=region,
                option_key=version,
                option_value=version,
                description=f"Kubernetes {version}",
                pricing_per_month=150.0,
                is_available=True,
            )
            for i, version in enumerate(gke_versions)
        ]

        cloud_sql_tiers = [
            ServiceCatalogItem(
                id=i,
                service_type="cloud_sql",
                region=region,
                option_key=tier,
                option_value=tier,
                description=f"Cloud SQL Tier {tier}",
                pricing_per_month=50.0 * (i + 1),
                is_available=True,
            )
            for i, tier in enumerate(["db-f1-micro", "db-n1-standard-1", "db-n1-standard-2"])
        ]

        return CatalogResponse(
            gce_machines=gce_machines,
            gke_versions=gke_tiers,
            cloud_sql_tiers=cloud_sql_tiers,
            regions=[
                "us-central1",
                "us-east1",
                "us-west1",
                "europe-west1",
                "asia-east1",
            ],
            networks=network_names,
            images=image_names,
        )
    except Exception as e:
        logger.error(f"Error getting catalog: {e}")
        # Return mock catalog on error
        return CatalogResponse(
            gce_machines=[],
            gke_versions=[],
            cloud_sql_tiers=[],
            regions=["us-central1", "us-east1", "europe-west1"],
            networks=["default", "production"],
            images=["debian-12", "ubuntu-2204-lts"],
        )
