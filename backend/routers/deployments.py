"""
Deployment API routes
"""
import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from schemas import (
    GCEDeploymentCreate, GKEDeploymentCreate, CloudSQLDeploymentCreate,
    DeploymentResponse, DeploymentListResponse, ApprovalResponse, ApprovalDecision
)
from models import DeploymentStatus, ApprovalStatus
from services.deployment_service import DeploymentService
from database import get_db
from routers.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/deployments", tags=["deployments"])


@router.post("/gce", response_model=DeploymentResponse)
async def create_gce_deployment(
    request_data: GCEDeploymentCreate,
    project_id: int = Query(...),
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a new GCE deployment request"""
    try:
        deployment = DeploymentService.create_gce_deployment(
            db, project_id, current_user.id, request_data
        )
        return DeploymentResponse.from_orm(deployment)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post("/gke", response_model=DeploymentResponse)
async def create_gke_deployment(
    request_data: GKEDeploymentCreate,
    project_id: int = Query(...),
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a new GKE deployment request"""
    try:
        deployment = DeploymentService.create_gke_deployment(
            db, project_id, current_user.id, request_data
        )
        return DeploymentResponse.from_orm(deployment)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post("/cloud-sql", response_model=DeploymentResponse)
async def create_cloud_sql_deployment(
    request_data: CloudSQLDeploymentCreate,
    project_id: int = Query(...),
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a new Cloud SQL deployment request"""
    try:
        deployment = DeploymentService.create_cloud_sql_deployment(
            db, project_id, current_user.id, request_data
        )
        return DeploymentResponse.from_orm(deployment)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get("/{deployment_id}", response_model=DeploymentResponse)
async def get_deployment(
    deployment_id: int,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get deployment details"""
    deployment = DeploymentService.get_deployment(db, deployment_id)
    if not deployment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Deployment not found",
        )
    return DeploymentResponse.from_orm(deployment)


@router.get("", response_model=DeploymentListResponse)
async def list_deployments(
    project_id: Optional[int] = Query(None),
    status: Optional[DeploymentStatus] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List deployments"""
    deployments, total = DeploymentService.list_deployments(
        db,
        project_id=project_id,
        requester_id=current_user.id if current_user.role == "requestor" else None,
        status=status,
        skip=skip,
        limit=limit,
    )

    return DeploymentListResponse(
        total=total,
        items=[DeploymentResponse.from_orm(d) for d in deployments],
        page=skip // limit + 1,
        page_size=limit,
    )


@router.post("/{deployment_id}/submit", response_model=DeploymentResponse)
async def submit_deployment(
    deployment_id: int,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Submit deployment for approval"""
    try:
        deployment = DeploymentService.submit_deployment(
            db, deployment_id, current_user.id
        )
        return DeploymentResponse.from_orm(deployment)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post("/{deployment_id}/approve", response_model=ApprovalResponse)
async def approve_deployment(
    deployment_id: int,
    approval_data: ApprovalDecision,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Approve deployment"""
    try:
        from models import ApprovalType
        approval = DeploymentService.approve_deployment(
            db,
            deployment_id,
            current_user.id,
            approval_type=ApprovalType.TECHNICAL,
            comments=approval_data.comments,
        )
        return ApprovalResponse.from_orm(approval)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post("/{deployment_id}/reject", response_model=ApprovalResponse)
async def reject_deployment(
    deployment_id: int,
    approval_data: ApprovalDecision,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Reject deployment"""
    try:
        from models import ApprovalType
        approval = DeploymentService.reject_deployment(
            db,
            deployment_id,
            current_user.id,
            approval_type=ApprovalType.TECHNICAL,
            comments=approval_data.comments,
        )
        return ApprovalResponse.from_orm(approval)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post("/{deployment_id}/deploy")
async def deploy_deployment(
    deployment_id: int,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Deploy approved deployment"""
    try:
        deployment = DeploymentService.mark_as_deployed(db, deployment_id)
        # TODO: Actually trigger deployment via GitHub Actions
        return {"status": "deploying", "deployment_id": deployment.id}
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.get("/{deployment_id}/approvals", response_model=list)
async def get_deployment_approvals(
    deployment_id: int,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get deployment approvals"""
    from models import Approval
    approvals = db.query(Approval).filter(
        Approval.deployment_id == deployment_id
    ).all()

    return [ApprovalResponse.from_orm(a) for a in approvals]
