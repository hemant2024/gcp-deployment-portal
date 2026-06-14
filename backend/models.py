"""
SQLAlchemy ORM models for GCP Deployment Portal
"""
from datetime import datetime
from typing import Optional
from sqlalchemy import (
    Column, String, Integer, Float, DateTime, Boolean, Text,
    ForeignKey, Enum, JSON, Index
)
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
import enum

Base = declarative_base()


class User(Base):
    """User account model"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    username = Column(String(100), unique=True, index=True, nullable=False)
    full_name = Column(String(255))
    hashed_password = Column(String(255))  # NULL for OAuth users
    google_id = Column(String(255), unique=True, index=True)  # For Google OAuth
    is_active = Column(Boolean, default=True)
    is_admin = Column(Boolean, default=False)
    role = Column(String(50), default="requestor")  # requestor, approver, admin
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    deployments = relationship("Deployment", back_populates="requester")
    approvals = relationship("Approval", back_populates="approver")

    __table_args__ = (
        Index("idx_email", "email"),
        Index("idx_google_id", "google_id"),
    )


class GCPProject(Base):
    """GCP projects accessible to users"""
    __tablename__ = "gcp_projects"

    id = Column(Integer, primary_key=True, index=True)
    project_id = Column(String(255), unique=True, index=True, nullable=False)
    project_name = Column(String(255), nullable=False)
    organization_id = Column(String(255), index=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    deployments = relationship("Deployment", back_populates="gcp_project")

    __table_args__ = (
        Index("idx_project_id", "project_id"),
    )


class DeploymentType(str, enum.Enum):
    """Deployment types"""
    GCE = "gce"
    GKE = "gke"
    CLOUD_SQL = "cloud_sql"


class DeploymentStatus(str, enum.Enum):
    """Deployment status"""
    DRAFT = "draft"
    SUBMITTED = "submitted"
    APPROVED = "approved"
    DEPLOYING = "deploying"
    DEPLOYED = "deployed"
    FAILED = "failed"
    DESTROYED = "destroyed"


class Deployment(Base):
    """Cloud deployment requests"""
    __tablename__ = "deployments"

    id = Column(Integer, primary_key=True, index=True)
    request_id = Column(String(50), unique=True, index=True, nullable=False)
    project_id = Column(Integer, ForeignKey("gcp_projects.id"), nullable=False)
    requester_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    # Deployment details
    deployment_type = Column(Enum(DeploymentType), nullable=False)
    name = Column(String(255), nullable=False)
    description = Column(Text)
    region = Column(String(50), nullable=False)
    environment = Column(String(50), default="dev")  # dev, staging, prod

    # GCE specific
    machine_type = Column(String(100))
    image = Column(String(100))
    boot_disk_size_gb = Column(Integer, default=10)
    network = Column(String(100))
    subnet = Column(String(100))
    enable_public_ip = Column(Boolean, default=True)
    labels = Column(JSON, default={})
    tags = Column(JSON, default=[])

    # GKE specific
    cluster_version = Column(String(50))
    num_nodes = Column(Integer)
    min_nodes = Column(Integer)
    max_nodes = Column(Integer)
    machine_type_gke = Column(String(100))
    enable_autoscaling = Column(Boolean, default=True)
    enable_workload_identity = Column(Boolean, default=True)

    # Cloud SQL specific
    database_version = Column(String(50))
    tier = Column(String(100))
    storage_size_gb = Column(Integer, default=20)
    backup_enabled = Column(Boolean, default=True)
    multi_region = Column(Boolean, default=False)

    # Cost & Status
    estimated_cost_monthly = Column(Float, default=0.0)
    status = Column(Enum(DeploymentStatus), default=DeploymentStatus.DRAFT)
    github_pr_url = Column(String(255))
    terraform_state = Column(JSON, default={})

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    submitted_at = Column(DateTime)
    approved_at = Column(DateTime)
    deployed_at = Column(DateTime)

    # Relationships
    gcp_project = relationship("GCPProject", back_populates="deployments")
    requester = relationship("User", back_populates="deployments")
    approvals = relationship("Approval", back_populates="deployment")
    logs = relationship("AuditLog", back_populates="deployment")

    __table_args__ = (
        Index("idx_request_id", "request_id"),
        Index("idx_project_id", "project_id"),
        Index("idx_requester_id", "requester_id"),
        Index("idx_status", "status"),
        Index("idx_created_at", "created_at"),
    )


class ApprovalType(str, enum.Enum):
    """Approval types"""
    TECHNICAL = "technical"
    SECURITY = "security"
    FINANCE = "finance"


class ApprovalStatus(str, enum.Enum):
    """Approval status"""
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class Approval(Base):
    """Deployment approvals"""
    __tablename__ = "approvals"

    id = Column(Integer, primary_key=True, index=True)
    deployment_id = Column(Integer, ForeignKey("deployments.id"), nullable=False)
    approver_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    approval_type = Column(Enum(ApprovalType), nullable=False)
    status = Column(Enum(ApprovalStatus), default=ApprovalStatus.PENDING)
    comments = Column(Text)

    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    responded_at = Column(DateTime)

    # Relationships
    deployment = relationship("Deployment", back_populates="approvals")
    approver = relationship("User", back_populates="approvals")

    __table_args__ = (
        Index("idx_deployment_id", "deployment_id"),
        Index("idx_approver_id", "approver_id"),
        Index("idx_status", "status"),
    )


class AuditLog(Base):
    """Audit trail for all actions"""
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    deployment_id = Column(Integer, ForeignKey("deployments.id"), nullable=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    action = Column(String(100), nullable=False)
    resource_type = Column(String(100), nullable=False)
    resource_id = Column(String(255))
    details = Column(JSON, default={})
    status = Column(String(50))
    error_message = Column(Text)
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)

    # Relationships
    deployment = relationship("Deployment", back_populates="logs")

    __table_args__ = (
        Index("idx_deployment_id", "deployment_id"),
        Index("idx_timestamp", "timestamp"),
        Index("idx_action", "action"),
    )


class GCPResource(Base):
    """Tracked GCP resources created by deployments"""
    __tablename__ = "gcp_resources"

    id = Column(Integer, primary_key=True, index=True)
    deployment_id = Column(Integer, ForeignKey("deployments.id"), nullable=False)
    resource_type = Column(String(100), nullable=False)  # instance, cluster, database
    resource_id = Column(String(255), nullable=False)
    resource_name = Column(String(255), nullable=False)
    region = Column(String(50), nullable=False)
    resource_url = Column(String(500))
    metadata = Column(JSON, default={})

    # Cost tracking
    current_cost_monthly = Column(Float, default=0.0)

    created_at = Column(DateTime, default=datetime.utcnow)
    last_synced_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        Index("idx_deployment_id", "deployment_id"),
        Index("idx_resource_id", "resource_id"),
    )


class ServiceCatalog(Base):
    """Available services and configurations"""
    __tablename__ = "service_catalog"

    id = Column(Integer, primary_key=True, index=True)
    service_type = Column(String(100), nullable=False)  # gce, gke, cloud_sql
    region = Column(String(50), nullable=False)
    option_key = Column(String(255), nullable=False)
    option_value = Column(String(255), nullable=False)
    description = Column(Text)
    pricing_per_month = Column(Float, default=0.0)
    is_available = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        Index("idx_service_type", "service_type"),
        Index("idx_region", "region"),
    )
