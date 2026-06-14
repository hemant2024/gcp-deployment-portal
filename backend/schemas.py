"""
Pydantic schemas for request/response validation
"""
from typing import Optional, List, Dict, Any
from datetime import datetime
from pydantic import BaseModel, EmailStr, Field
from models import DeploymentType, DeploymentStatus, ApprovalType, ApprovalStatus


# ==================== User Schemas ====================

class UserBase(BaseModel):
    email: EmailStr
    username: str
    full_name: Optional[str] = None
    role: str = "requestor"


class UserCreate(UserBase):
    password: str


class UserGoogleAuth(BaseModel):
    google_id: str
    email: EmailStr
    full_name: str


class UserResponse(UserBase):
    id: int
    is_active: bool
    is_admin: bool
    created_at: datetime

    class Config:
        from_attributes = True


# ==================== Auth Schemas ====================

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class GoogleAuthCallback(BaseModel):
    code: str
    state: Optional[str] = None


# ==================== GCP Project Schemas ====================

class GCPProjectBase(BaseModel):
    project_id: str
    project_name: str
    organization_id: Optional[str] = None


class GCPProjectCreate(GCPProjectBase):
    pass


class GCPProjectResponse(GCPProjectBase):
    id: int
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ==================== Deployment Schemas ====================

class GCEDeploymentBase(BaseModel):
    machine_type: str
    image: str
    boot_disk_size_gb: int = 10
    network: str = "default"
    subnet: Optional[str] = None
    enable_public_ip: bool = True
    labels: Dict[str, str] = Field(default_factory=dict)
    tags: List[str] = Field(default_factory=list)


class GKEDeploymentBase(BaseModel):
    cluster_version: str
    num_nodes: int
    min_nodes: int = 1
    max_nodes: int = 10
    machine_type_gke: str
    enable_autoscaling: bool = True
    enable_workload_identity: bool = True


class CloudSQLDeploymentBase(BaseModel):
    database_version: str
    tier: str
    storage_size_gb: int = 20
    backup_enabled: bool = True
    multi_region: bool = False


class DeploymentBase(BaseModel):
    name: str
    description: Optional[str] = None
    deployment_type: DeploymentType
    region: str
    environment: str = "dev"
    estimated_cost_monthly: Optional[float] = None


class GCEDeploymentCreate(DeploymentBase):
    gce_config: GCEDeploymentBase


class GKEDeploymentCreate(DeploymentBase):
    gke_config: GKEDeploymentBase


class CloudSQLDeploymentCreate(DeploymentBase):
    cloud_sql_config: CloudSQLDeploymentBase


class DeploymentResponse(BaseModel):
    id: int
    request_id: str
    project_id: int
    name: str
    description: Optional[str]
    deployment_type: DeploymentType
    region: str
    environment: str
    status: DeploymentStatus
    estimated_cost_monthly: float
    github_pr_url: Optional[str]
    created_at: datetime
    updated_at: datetime
    submitted_at: Optional[datetime]
    approved_at: Optional[datetime]
    deployed_at: Optional[datetime]
    requester: UserResponse

    class Config:
        from_attributes = True


class DeploymentListResponse(BaseModel):
    total: int
    items: List[DeploymentResponse]
    page: int
    page_size: int


# ==================== Approval Schemas ====================

class ApprovalCreate(BaseModel):
    approval_type: ApprovalType
    comments: Optional[str] = None


class ApprovalResponse(BaseModel):
    id: int
    deployment_id: int
    approver_id: int
    approval_type: ApprovalType
    status: ApprovalStatus
    comments: Optional[str]
    created_at: datetime
    responded_at: Optional[datetime]
    approver: UserResponse

    class Config:
        from_attributes = True


class ApprovalDecision(BaseModel):
    status: ApprovalStatus
    comments: Optional[str] = None


# ==================== Catalog Schemas ====================

class ServiceCatalogItem(BaseModel):
    id: int
    service_type: str
    region: str
    option_key: str
    option_value: str
    description: Optional[str]
    pricing_per_month: float
    is_available: bool

    class Config:
        from_attributes = True


class CatalogResponse(BaseModel):
    gce_machines: List[ServiceCatalogItem]
    gke_versions: List[ServiceCatalogItem]
    cloud_sql_tiers: List[ServiceCatalogItem]
    regions: List[str]
    networks: List[str]
    images: List[str]


# ==================== GCP Resource Schemas ====================

class GCPResourceResponse(BaseModel):
    id: int
    deployment_id: int
    resource_type: str
    resource_id: str
    resource_name: str
    region: str
    resource_url: Optional[str]
    metadata: Dict[str, Any]
    current_cost_monthly: float
    created_at: datetime
    last_synced_at: datetime

    class Config:
        from_attributes = True


# ==================== Audit Log Schemas ====================

class AuditLogResponse(BaseModel):
    id: int
    deployment_id: Optional[int]
    user_id: Optional[int]
    action: str
    resource_type: str
    resource_id: Optional[str]
    details: Dict[str, Any]
    status: Optional[str]
    error_message: Optional[str]
    timestamp: datetime

    class Config:
        from_attributes = True


# ==================== Error Schemas ====================

class ErrorResponse(BaseModel):
    error: str
    detail: Optional[str] = None
    status_code: int


# ==================== Dashboard Schemas ====================

class DashboardStats(BaseModel):
    total_deployments: int
    deployments_by_status: Dict[str, int]
    deployments_by_type: Dict[str, int]
    total_monthly_cost: float
    pending_approvals: int
    recent_deployments: List[DeploymentResponse]


class UserStats(BaseModel):
    my_deployments: int
    pending_approvals: int
    my_deployments_by_status: Dict[str, int]
