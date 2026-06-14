"""
Deployment service - handles deployment request logic
"""
import logging
import uuid
from datetime import datetime
from typing import Dict, Any, Optional, List
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_
from models import (
    Deployment, DeploymentStatus, DeploymentType, Approval,
    ApprovalStatus, ApprovalType, User, AuditLog, GCPProject
)
from schemas import (
    GCEDeploymentCreate, GKEDeploymentCreate, CloudSQLDeploymentCreate,
    DeploymentResponse
)

logger = logging.getLogger(__name__)


class DeploymentService:
    """Service for managing deployments"""

    @staticmethod
    def generate_request_id() -> str:
        """Generate unique request ID"""
        return f"REQ-{uuid.uuid4().hex[:8].upper()}"

    @staticmethod
    def create_gce_deployment(
        db: Session,
        project_id: int,
        requester_id: int,
        request_data: GCEDeploymentCreate,
    ) -> Deployment:
        """Create GCE deployment request"""
        deployment = Deployment(
            request_id=DeploymentService.generate_request_id(),
            project_id=project_id,
            requester_id=requester_id,
            deployment_type=DeploymentType.GCE,
            name=request_data.name,
            description=request_data.description,
            region=request_data.region,
            environment=request_data.environment,
            machine_type=request_data.gce_config.machine_type,
            image=request_data.gce_config.image,
            boot_disk_size_gb=request_data.gce_config.boot_disk_size_gb,
            network=request_data.gce_config.network,
            subnet=request_data.gce_config.subnet,
            enable_public_ip=request_data.gce_config.enable_public_ip,
            labels=request_data.gce_config.labels,
            tags=request_data.gce_config.tags,
            estimated_cost_monthly=request_data.estimated_cost_monthly or 25.0,
            status=DeploymentStatus.DRAFT,
        )

        db.add(deployment)
        db.commit()
        db.refresh(deployment)

        logger.info(f"Created GCE deployment: {deployment.request_id}")
        DeploymentService._create_audit_log(
            db, deployment.id, requester_id, "CREATE", "Deployment",
            {"type": "GCE", "name": deployment.name}
        )

        return deployment

    @staticmethod
    def create_gke_deployment(
        db: Session,
        project_id: int,
        requester_id: int,
        request_data: GKEDeploymentCreate,
    ) -> Deployment:
        """Create GKE deployment request"""
        deployment = Deployment(
            request_id=DeploymentService.generate_request_id(),
            project_id=project_id,
            requester_id=requester_id,
            deployment_type=DeploymentType.GKE,
            name=request_data.name,
            description=request_data.description,
            region=request_data.region,
            environment=request_data.environment,
            cluster_version=request_data.gke_config.cluster_version,
            num_nodes=request_data.gke_config.num_nodes,
            min_nodes=request_data.gke_config.min_nodes,
            max_nodes=request_data.gke_config.max_nodes,
            machine_type_gke=request_data.gke_config.machine_type_gke,
            enable_autoscaling=request_data.gke_config.enable_autoscaling,
            enable_workload_identity=request_data.gke_config.enable_workload_identity,
            estimated_cost_monthly=request_data.estimated_cost_monthly or 150.0,
            status=DeploymentStatus.DRAFT,
        )

        db.add(deployment)
        db.commit()
        db.refresh(deployment)

        logger.info(f"Created GKE deployment: {deployment.request_id}")
        DeploymentService._create_audit_log(
            db, deployment.id, requester_id, "CREATE", "Deployment",
            {"type": "GKE", "name": deployment.name}
        )

        return deployment

    @staticmethod
    def create_cloud_sql_deployment(
        db: Session,
        project_id: int,
        requester_id: int,
        request_data: CloudSQLDeploymentCreate,
    ) -> Deployment:
        """Create Cloud SQL deployment request"""
        deployment = Deployment(
            request_id=DeploymentService.generate_request_id(),
            project_id=project_id,
            requester_id=requester_id,
            deployment_type=DeploymentType.CLOUD_SQL,
            name=request_data.name,
            description=request_data.description,
            region=request_data.region,
            environment=request_data.environment,
            database_version=request_data.cloud_sql_config.database_version,
            tier=request_data.cloud_sql_config.tier,
            storage_size_gb=request_data.cloud_sql_config.storage_size_gb,
            backup_enabled=request_data.cloud_sql_config.backup_enabled,
            multi_region=request_data.cloud_sql_config.multi_region,
            estimated_cost_monthly=request_data.estimated_cost_monthly or 50.0,
            status=DeploymentStatus.DRAFT,
        )

        db.add(deployment)
        db.commit()
        db.refresh(deployment)

        logger.info(f"Created Cloud SQL deployment: {deployment.request_id}")
        DeploymentService._create_audit_log(
            db, deployment.id, requester_id, "CREATE", "Deployment",
            {"type": "Cloud SQL", "name": deployment.name}
        )

        return deployment

    @staticmethod
    def get_deployment(db: Session, deployment_id: int) -> Optional[Deployment]:
        """Get deployment by ID"""
        return db.query(Deployment).filter(Deployment.id == deployment_id).first()

    @staticmethod
    def get_deployment_by_request_id(db: Session, request_id: str) -> Optional[Deployment]:
        """Get deployment by request ID"""
        return db.query(Deployment).filter(Deployment.request_id == request_id).first()

    @staticmethod
    def list_deployments(
        db: Session,
        project_id: Optional[int] = None,
        requester_id: Optional[int] = None,
        status: Optional[DeploymentStatus] = None,
        deployment_type: Optional[DeploymentType] = None,
        skip: int = 0,
        limit: int = 20,
    ) -> tuple[List[Deployment], int]:
        """List deployments with filters"""
        query = db.query(Deployment)

        if project_id:
            query = query.filter(Deployment.project_id == project_id)
        if requester_id:
            query = query.filter(Deployment.requester_id == requester_id)
        if status:
            query = query.filter(Deployment.status == status)
        if deployment_type:
            query = query.filter(Deployment.deployment_type == deployment_type)

        total = query.count()
        deployments = query.order_by(Deployment.created_at.desc()).offset(skip).limit(limit).all()

        return deployments, total

    @staticmethod
    def submit_deployment(db: Session, deployment_id: int, requester_id: int) -> Deployment:
        """Submit deployment for approval"""
        deployment = DeploymentService.get_deployment(db, deployment_id)
        if not deployment:
            raise ValueError("Deployment not found")

        if deployment.requester_id != requester_id:
            raise ValueError("Only requester can submit deployment")

        if deployment.status != DeploymentStatus.DRAFT:
            raise ValueError("Only draft deployments can be submitted")

        deployment.status = DeploymentStatus.SUBMITTED
        deployment.submitted_at = datetime.utcnow()

        # Create approval requests
        approvers = db.query(User).filter(
            User.role.in_(["approver", "admin"])
        ).all()

        for approver in approvers:
            approval = Approval(
                deployment_id=deployment.id,
                approver_id=approver.id,
                approval_type=ApprovalType.TECHNICAL,
                status=ApprovalStatus.PENDING,
            )
            db.add(approval)

        db.commit()
        db.refresh(deployment)

        logger.info(f"Submitted deployment: {deployment.request_id}")
        DeploymentService._create_audit_log(
            db, deployment.id, requester_id, "SUBMIT", "Deployment",
            {"request_id": deployment.request_id}
        )

        return deployment

    @staticmethod
    def approve_deployment(
        db: Session,
        deployment_id: int,
        approver_id: int,
        approval_type: ApprovalType = ApprovalType.TECHNICAL,
        comments: Optional[str] = None,
    ) -> Approval:
        """Approve deployment"""
        deployment = DeploymentService.get_deployment(db, deployment_id)
        if not deployment:
            raise ValueError("Deployment not found")

        approval = db.query(Approval).filter(
            and_(
                Approval.deployment_id == deployment_id,
                Approval.approver_id == approver_id,
                Approval.approval_type == approval_type,
            )
        ).first()

        if not approval:
            raise ValueError("Approval record not found")

        approval.status = ApprovalStatus.APPROVED
        approval.comments = comments
        approval.responded_at = datetime.utcnow()

        # Check if all approvals done
        pending_approvals = db.query(Approval).filter(
            and_(
                Approval.deployment_id == deployment_id,
                Approval.status == ApprovalStatus.PENDING,
            )
        ).count()

        if pending_approvals == 0:
            deployment.status = DeploymentStatus.APPROVED
            deployment.approved_at = datetime.utcnow()
            logger.info(f"All approvals received for: {deployment.request_id}")

        db.commit()
        db.refresh(approval)

        logger.info(f"Approved deployment: {deployment.request_id}")
        DeploymentService._create_audit_log(
            db, deployment.id, approver_id, "APPROVE", "Deployment",
            {"approval_type": approval_type.value, "comments": comments}
        )

        return approval

    @staticmethod
    def reject_deployment(
        db: Session,
        deployment_id: int,
        approver_id: int,
        approval_type: ApprovalType = ApprovalType.TECHNICAL,
        comments: Optional[str] = None,
    ) -> Approval:
        """Reject deployment"""
        deployment = DeploymentService.get_deployment(db, deployment_id)
        if not deployment:
            raise ValueError("Deployment not found")

        approval = db.query(Approval).filter(
            and_(
                Approval.deployment_id == deployment_id,
                Approval.approver_id == approver_id,
                Approval.approval_type == approval_type,
            )
        ).first()

        if not approval:
            raise ValueError("Approval record not found")

        approval.status = ApprovalStatus.REJECTED
        approval.comments = comments
        approval.responded_at = datetime.utcnow()

        deployment.status = DeploymentStatus.FAILED
        db.commit()
        db.refresh(approval)

        logger.info(f"Rejected deployment: {deployment.request_id}")
        DeploymentService._create_audit_log(
            db, deployment.id, approver_id, "REJECT", "Deployment",
            {"approval_type": approval_type.value, "reason": comments}
        )

        return approval

    @staticmethod
    def mark_as_deployed(db: Session, deployment_id: int) -> Deployment:
        """Mark deployment as successfully deployed"""
        deployment = DeploymentService.get_deployment(db, deployment_id)
        if not deployment:
            raise ValueError("Deployment not found")

        deployment.status = DeploymentStatus.DEPLOYED
        deployment.deployed_at = datetime.utcnow()

        db.commit()
        db.refresh(deployment)

        logger.info(f"Marked as deployed: {deployment.request_id}")
        DeploymentService._create_audit_log(
            db, deployment.id, None, "DEPLOY", "Deployment",
            {"request_id": deployment.request_id}
        )

        return deployment

    @staticmethod
    def _create_audit_log(
        db: Session,
        deployment_id: Optional[int],
        user_id: Optional[int],
        action: str,
        resource_type: str,
        details: Dict[str, Any],
    ) -> AuditLog:
        """Create audit log entry"""
        log = AuditLog(
            deployment_id=deployment_id,
            user_id=user_id,
            action=action,
            resource_type=resource_type,
            details=details,
            status="SUCCESS",
        )
        db.add(log)
        db.commit()
        return log
