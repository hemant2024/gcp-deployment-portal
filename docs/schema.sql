-- GCP Deployment Portal Schema
-- Run this file to create all tables

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           VARCHAR(255) UNIQUE NOT NULL,
    full_name       VARCHAR(255) NOT NULL,
    role            VARCHAR(50) NOT NULL CHECK (role IN (
                        'requestor','technical_approver',
                        'security_approver','finance_approver',
                        'cloud_admin','auditor')),
    department      VARCHAR(100),
    is_active       BOOLEAN DEFAULT true,
    last_login      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- GCP Projects table
CREATE TABLE IF NOT EXISTS gcp_projects (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id      VARCHAR(100) UNIQUE NOT NULL,
    display_name    VARCHAR(255),
    environment     VARCHAR(20) CHECK (environment IN ('dev','staging','prod')),
    monthly_budget  DECIMAL(12,2),
    department      VARCHAR(100),
    cost_center     VARCHAR(50),
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Deployment Requests table
CREATE TABLE IF NOT EXISTS deployment_requests (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_number          VARCHAR(20) UNIQUE NOT NULL,
    resource_type           VARCHAR(10) NOT NULL CHECK (resource_type IN ('GCE','GKE')),
    resource_name           VARCHAR(255) NOT NULL,
    project_id              VARCHAR(100) NOT NULL,
    environment             VARCHAR(20) NOT NULL,
    region                  VARCHAR(50),
    zone                    VARCHAR(50),
    configuration           JSONB NOT NULL DEFAULT '{}',
    status                  VARCHAR(30) NOT NULL DEFAULT 'submitted' CHECK (status IN (
                                'submitted','pending_approval','approved',
                                'planning','deploying','validating',
                                'completed','failed','cancelled')),
    estimated_cost_monthly  DECIMAL(12,2),
    actual_cost_monthly     DECIMAL(12,2),
    requestor_id            UUID REFERENCES users(id),
    business_justification  TEXT,
    terraform_plan_output   TEXT,
    terraform_apply_output  TEXT,
    github_pr_number        INTEGER,
    github_pr_url           VARCHAR(500),
    terraform_state_path    VARCHAR(500),
    error_message           TEXT,
    deployed_at             TIMESTAMPTZ,
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

-- Approval Steps table
CREATE TABLE IF NOT EXISTS approval_steps (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id      UUID NOT NULL REFERENCES deployment_requests(id) ON DELETE CASCADE,
    step_order      INTEGER NOT NULL,
    approver_role   VARCHAR(50) NOT NULL,
    approver_id     UUID REFERENCES users(id),
    status          VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
                        'pending','approved','rejected','skipped','escalated')),
    comments        TEXT,
    sla_hours       INTEGER DEFAULT 8,
    due_at          TIMESTAMPTZ,
    actioned_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Resource Inventory table
CREATE TABLE IF NOT EXISTS resource_inventory (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    resource_name   VARCHAR(255) NOT NULL,
    resource_type   VARCHAR(10) NOT NULL,
    project_id      VARCHAR(100) NOT NULL,
    environment     VARCHAR(20),
    region          VARCHAR(50),
    zone            VARCHAR(50),
    status          VARCHAR(30) DEFAULT 'RUNNING',
    internal_ip     VARCHAR(50),
    external_ip     VARCHAR(50),
    machine_type    VARCHAR(100),
    os_image        VARCHAR(255),
    labels          JSONB DEFAULT '{}',
    metadata        JSONB DEFAULT '{}',
    monthly_cost    DECIMAL(12,2),
    request_id      UUID REFERENCES deployment_requests(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW(),
    last_synced_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Audit Log table (immutable)
CREATE TABLE IF NOT EXISTS audit_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type      VARCHAR(100) NOT NULL,
    actor_id        UUID REFERENCES users(id),
    actor_email     VARCHAR(255),
    resource_id     VARCHAR(255),
    resource_type   VARCHAR(50),
    description     TEXT,
    metadata        JSONB DEFAULT '{}',
    ip_address      VARCHAR(45),
    user_agent      VARCHAR(500),
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Cost Records table
CREATE TABLE IF NOT EXISTS cost_records (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    resource_id     UUID REFERENCES resource_inventory(id),
    project_id      VARCHAR(100),
    cost_date       DATE NOT NULL,
    daily_cost      DECIMAL(12,4),
    monthly_cost    DECIMAL(12,2),
    currency        VARCHAR(3) DEFAULT 'USD',
    cost_breakdown  JSONB DEFAULT '{}',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- AI Agent Sessions table
CREATE TABLE IF NOT EXISTS ai_sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID REFERENCES users(id),
    session_token   VARCHAR(255) UNIQUE NOT NULL,
    conversation    JSONB DEFAULT '[]',
    context         JSONB DEFAULT '{}',
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_deployment_requests_status
    ON deployment_requests(status);
CREATE INDEX IF NOT EXISTS idx_deployment_requests_requestor
    ON deployment_requests(requestor_id);
CREATE INDEX IF NOT EXISTS idx_deployment_requests_project
    ON deployment_requests(project_id);
CREATE INDEX IF NOT EXISTS idx_approval_steps_request
    ON approval_steps(request_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_actor
    ON audit_log(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created
    ON audit_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inventory_project
    ON resource_inventory(project_id, resource_type);

-- Seed default users
INSERT INTO users (email, full_name, role, department) VALUES
    ('hemant.pandey@company.com',  'Hemant Pandey',    'cloud_admin',        'Platform'),
    ('alice.chen@company.com',     'Alice Chen',        'requestor',          'Engineering'),
    ('tech.approver@company.com',  'Tech Approver',    'technical_approver', 'Platform'),
    ('sec.approver@company.com',   'Sec Approver',     'security_approver',  'Security'),
    ('fin.approver@company.com',   'Finance Approver', 'finance_approver',   'Finance'),
    ('auditor@company.com',        'Auditor User',     'auditor',            'Compliance')
ON CONFLICT (email) DO NOTHING;

-- Seed GCP projects
INSERT INTO gcp_projects (project_id, display_name, environment, monthly_budget, department) VALUES
    ('prod-project-001',    'Production Project 1', 'prod',    50000.00, 'Engineering'),
    ('staging-project-001', 'Staging Project 1',    'staging',  8000.00, 'Engineering'),
    ('dev-project-001',     'Dev Project 1',        'dev',      5000.00, 'Engineering')
ON CONFLICT (project_id) DO NOTHING;
