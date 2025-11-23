# DevOps Portfolio Project - Medical Practice Management System

[![CI/CD Pipeline](https://github.com/akthm/demo-k8s-gitops/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/akthm/demo-k8s-gitops/actions)
[![Infrastructure](https://img.shields.io/badge/Infrastructure-AWS%20EKS-orange)](https://aws.amazon.com/eks/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.34-blue)](https://kubernetes.io/)

> A comprehensive DevOps implementation showcasing modern cloud-native architecture, GitOps workflows, and production-grade infrastructure automation.

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Architecture](#-architecture)
- [Technology Stack](#-technology-stack)
- [Repository Structure](#-repository-structure)
- [Implementation Features](#-implementation-features)
- [Getting Started](#-getting-started)
- [CI/CD Pipeline](#-cicd-pipeline)
- [Infrastructure](#-infrastructure)
- [Monitoring & Observability](#-monitoring--observability)
- [Security](#-security)
- [Bonus Features Implemented](#-bonus-features-implemented)
- [Cost Optimization](#-cost-optimization)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Project Overview

This portfolio project demonstrates enterprise-level DevOps practices through a complete microservices application deployment. The project implements a Medical Practice Management System with patient records, appointments, and messaging features, showcasing:

- **Full-stack development** with Python Flask backend and React frontend
- **Complete CI/CD automation** using GitHub Actions
- **Infrastructure as Code** with Terraform on AWS
- **Container orchestration** with Kubernetes (EKS)
- **GitOps workflow** with ArgoCD
- **Production-grade security** with External Secrets Operator and AWS Secrets Manager
- **Observability stack** with monitoring and logging

### Core Objectives Achieved

✅ Functional SaaS application with REST API  
✅ Automated CI/CD workflow with testing  
✅ Infrastructure as Code for AWS deployment  
✅ Kubernetes-based microservices architecture  
✅ Professional documentation and architecture diagrams  
✅ Production-ready security and secrets management  
✅ GitOps deployment automation  

---

## 🏗️ Architecture

### Application Architecture (3-Tier)

```
┌─────────────────────────────────────────────────────────────┐
│                      Internet / Users                        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                   AWS Application Load Balancer             │
│                    (Kubernetes Ingress)                      │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┴
         │                                
         ▼                                
┌──────────────────┐            ┌──────────────────┐
│  Nginx Frontend  │            │  Flask Backend   │
│   (React SPA)    │◄──────────►│   (REST API)     │
│  Port: 80        │            │   Port: 8000     │
└──────────────────┘            └────────┬─────────┘
                                         │
                                         ▼
                                ┌──────────────────┐
                                │  MySQL Database  │
                                │  (Persistent)    │
                                │  Port: 3306      │
                                └──────────────────┘
```

### Complete DevOps Workflow

![Complete DevOps Workflow](./docs/images/devops-workflow.png)

*Figure: End-to-end CI/CD pipeline from code commit to production deployment*

---

## 🛠️ Technology Stack

### Core Technologies

| Category | Technology | Purpose |
|----------|-----------|---------|
| **Project Management** | Trello | Task tracking and organization |
| **Source Control** | GitHub | Version control (3 private repos) |
| **Backend** | Python Flask | REST API with SQLAlchemy ORM |
| **Frontend** | React + Nginx | Single Page Application |
| **Database** | MySQL 9.4 | Persistent data storage |
| **Containerization** | Docker + ECR | Application packaging |
| **Infrastructure** | Terraform | Infrastructure as Code |
| **Cloud Provider** | AWS | EKS, VPC, S3, ECR, Secrets Manager |
| **Orchestration** | Kubernetes (EKS) | Container orchestration |
| **CI/CD** | GitHub Actions | Automated pipeline |
| **GitOps** | ArgoCD | Declarative deployment |
| **Secrets** | External Secrets Operator | AWS Secrets Manager integration |
| **Package Management** | Helm 3 | Kubernetes package manager |

### AWS Services Used

- **Compute**: EKS (Kubernetes), EC2 (worker nodes)
- **Container**: ECR (Docker registry)
- **Storage**: S3 (Terraform state), EBS (persistent volumes)
- **Networking**: VPC, Subnets, Internet Gateway, NAT Gateway, Security Groups
- **Security**: IAM Roles, Policies, IRSA (IAM Roles for Service Accounts), Secrets Manager
- **Load Balancing**: Application Load Balancer (via Kubernetes Ingress)

---

## 📁 Repository Structure

The project is organized across three private Git repositories:

### 1. Application Repository
**Repository**: `akthm/demo-back` (Private)

```
demo-back/
├── .github/
│   └── workflows/
│       └── ci-cd.yml              # GitHub Actions pipeline
├── app.py                         # Flask application entry point
├── models.py                      # SQLAlchemy database models
├── repository.py                  # Data access layer
├── config.py                      # Application configuration
├── requirements.txt               # Python dependencies
├── Dockerfile                     # Multi-stage Docker build
├── docker-compose.yml             # Local development environment
├── tests/
│   ├── unit/                      # Unit tests
│   └── integration/               # Integration tests
└── README.md                      # Application documentation
```

**Features**:
- REST API with 15+ endpoints (CRUD operations)
- SQLAlchemy ORM with MySQL backend
- JWT authentication (RS256 with key rotation)
- Role-based access control (ADMIN, DOCTOR, PATIENT)
- Comprehensive error handling and validation
- Multi-stage Dockerfile for optimized images
- Docker Compose for local development

### 2. Infrastructure Repository
**Repository**: `akthm/terraform-eks` (Private)

```
terraform-eks/
├── main.tf                        # Root module configuration
├── variables.tf                   # Input variables
├── outputs.tf                     # Output values
├── providers.tf                   # Provider configuration
├── backend.tf                     # S3 backend for state
├── vpc.tf                         # VPC and networking
├── eks.tf                         # EKS cluster configuration
├── irsa.tf                        # IAM Roles for Service Accounts
├── ecr.tf                         # ECR repositories
├── secrets.tf                     # AWS Secrets Manager resources
├── terraform.tfvars               # Variable values
└── README.md                      # Infrastructure documentation
```

**Infrastructure Provisioned**:
- EKS cluster (1.28) with 2 nodes (t3a.medium)
- VPC with public/private subnets across 2 AZs
- NAT Gateway for private subnet internet access
- ECR repositories for Docker images
- IAM roles with IRSA for External Secrets Operator
- AWS Secrets Manager for sensitive data

### 3. GitOps Repository (Cluster Resources)
**Repository**: `akthm/demo-k8s-gitops` (Private)

```
charts/
├── backend/
│   ├── apps/
│   │   └── staging/
│   │       ├── external-secrets-operator.yaml    # ArgoCD app for ESO
│   │       ├── flask-backend.yaml                # ArgoCD app for backend
│   │       └── nginx-front.yaml                  # ArgoCD app for frontend
│   └── helm-charts/
│       ├── external-secrets-operator/            # ESO Helm chart
│       │   ├── Chart.yaml
│       │   ├── values.yaml
│       │   ├── values.stage.yaml
│       │   └── templates/
│       │       ├── namespace.yaml
│       │       ├── serviceaccount.yaml
│       │       ├── cluster-secret-store.yaml
│       │       └── secret-store.yaml
│       ├── flask-app/                            # Backend Helm chart
│       │   ├── Chart.yaml
│       │   ├── values.yaml
│       │   ├── values.stage.yaml
│       │   └── templates/
│       │       ├── deployment.yaml
│       │       ├── service.yaml
│       │       ├── configmap.yaml
│       │       ├── rbac.yaml
│       │       ├── hpa.yaml
│       │       ├── external-secret-*.yaml        # 4 ExternalSecrets
│       │       └── networkpolicy.yaml
│       └── nginx-front/                          # Frontend Helm chart
│           ├── Chart.yaml
│           ├── values.yaml
│           └── templates/
│               ├── deployment.yaml
│               ├── service.yaml
│               ├── configmap-nginx.yaml
│               ├── ingress.yaml
│               └── hpa.yaml
├── docs/
│   └── AWS_SECRETS_SETUP.md                      # Secrets management guide
├── scripts/
│   ├── setup-aws-secrets.sh                      # Automated secret creation
│   ├── setup-local.sh                            # Local environment setup
│   └── validate-deployment.sh                    # Deployment validation
└── README.md                                      # This file
```

---

## ✨ Implementation Features

### Core Requirements ✅

1. **Functional REST API Application**
   - 15+ REST endpoints for patient, appointment, and message management
   - Complete CRUD operations with database persistence
   - JWT authentication with RS256 algorithm
   - Role-based access control (RBAC)

2. **Complete CI/CD Workflow**
   - Automated testing (unit + integration)
   - Docker image building and tagging
   - ECR publishing
   - Automated GitOps repository updates
   - ArgoCD automatic deployment

3. **Infrastructure as Code**
   - 100% Terraform-managed infrastructure
   - AWS EKS cluster with Auto Scaling
   - Complete networking (VPC, subnets, NAT)
   - IAM roles with IRSA for security

4. **Kubernetes Orchestration**
   - Multi-tier application deployment
   - Persistent storage with StatefulSets
   - Service discovery and load balancing
   - Resource limits and autoscaling (HPA)

5. **Professional Documentation**
   - Comprehensive README files in all repos
   - Architecture diagrams (application + workflow)
   - API documentation
   - Deployment guides

---

## 🚀 Getting Started

### Prerequisites

- **Local Development**:
  - Docker Desktop
  - Docker Compose
  - Python 3.12+
  - Node.js 18+ (for frontend)
  - Git

- **Infrastructure Deployment**:
  - AWS CLI configured
  - Terraform 1.5+
  - kubectl
  - Helm 3.x
  - ArgoCD CLI (optional)

### Local Development

1. **Clone the application repository**:
   ```bash
   git clone https://github.com/akthm/demo-back.git
   cd demo-back
   ```

2. **Start the application stack**:
   ```bash
   docker-compose up -d
   ```

3. **Access the application**:
   - Backend API: http://localhost:5000
   - Frontend UI: http://localhost:3000
   - MySQL: localhost:3306

4. **Run tests**:
   ```bash
   # Unit tests
   docker-compose exec backend pytest tests/unit/

   # Integration tests
   docker-compose exec backend pytest tests/integration/
   ```

### Infrastructure Deployment

1. **Clone infrastructure repository**:
   ```bash
   git clone https://github.com/akthm/terraform-eks.git
   cd terraform-eks
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Plan infrastructure**:
   ```bash
   terraform plan -out=tfplan
   ```

4. **Apply infrastructure**:
   ```bash
   terraform apply tfplan
   ```

5. **Configure kubectl**:
   ```bash
   aws eks update-kubeconfig --name demo-eks-cluster --region ap-south-1
   ```

### GitOps Deployment

1. **Clone GitOps repository**:
   ```bash
   git clone https://github.com/akthm/demo-k8s-gitops.git
   cd demo-k8s-gitops/charts
   ```

2. **Create AWS secrets** (one-time setup):
   ```bash
   cd scripts
   chmod +x setup-aws-secrets.sh
   ./setup-aws-secrets.sh
   ```

3. **Deploy with ArgoCD**:
   ```bash
   # Deploy External Secrets Operator first
   kubectl apply -f backend/apps/staging/external-secrets-operator.yaml

   # Wait for ESO to be ready
   kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets-system --timeout=300s

   # Deploy backend
   kubectl apply -f backend/apps/staging/flask-backend.yaml

   # Deploy frontend
   kubectl apply -f backend/apps/staging/nginx-front.yaml
   ```

4. **Access ArgoCD UI**:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   # Access at https://localhost:8080
   # Username: admin
   # Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

---

## 🔄 CI/CD Pipeline

### Pipeline Stages

The GitHub Actions workflow runs on every push to `main`:

```yaml
1. Clone/Pull
   └─> Checkout code from GitHub

2. Build
   └─> Install Python dependencies
   └─> Validate code syntax

3. Unit Tests
   └─> Run pytest with coverage
   └─> Generate test reports

4. Package
   └─> Build Docker image
   └─> Tag with semantic version and commit SHA

5. Integration Tests
   └─> Start docker-compose stack
   └─> Run API endpoint tests
   └─> Verify database connectivity
   └─> Cleanup test environment

6. Publish to ECR
   └─> Authenticate with AWS ECR
   └─> Push Docker image with tags
   └─> Update image manifest

7. Update GitOps
   └─> Clone charts repository
   └─> Update Helm values with new image tag
   └─> Commit and push changes
   └─> Trigger ArgoCD sync

8. Deploy Notification
   └─> ArgoCD detects changes
   └─> Automatic deployment to EKS
   └─> Health checks and rollout status
```

### Semantic Versioning

Images are tagged with:
- Semantic version: `v1.0.16`
- Git commit SHA: `abc1234`
- Branch name: `main`
- Latest tag: `latest`

### Branch Strategy

- **main**: Full CI/CD pipeline with deployment
- **feature/***: CI only (build, test, package) - no deployment

---

## 🏗️ Infrastructure

### EKS Cluster Configuration

**Cluster Specifications**:
- Kubernetes version: 1.28
- Node group: 2x t3a.medium instances
- Auto Scaling: Min 1, Desired 2, Max 3
- Container runtime: containerd
- Network plugin: Amazon VPC CNI

**Networking**:
- VPC CIDR: 10.0.0.0/16
- Public subnets: 2 (across AZs for HA)
- Private subnets: 2 (for worker nodes)
- NAT Gateway: 1 (cost optimization)
- Internet Gateway: 1

**Security**:
- IRSA enabled for pod-level IAM permissions
- Security groups with least-privilege access
- Private cluster endpoint access
- Network policies for pod-to-pod communication

### Terraform Modules

```hcl
# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"
  
  cluster_name    = "demo-eks-cluster"
  cluster_version = "1.28"
  
  # IRSA for External Secrets Operator
  enable_irsa = true
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  cidr = "10.0.0.0/16"
  azs  = ["ap-south-1a", "ap-south-1b"]
}
```

### Cost Management

**Daily Workflow**:
```bash
# Start of day
terraform apply

# End of day
terraform destroy
```

**Monthly Estimate** (ap-south-1 region):
- EKS control plane: ~$73/month
- EC2 instances (2x t3a.medium): ~$60/month
- NAT Gateway: ~$33/month
- EBS volumes: ~$10/month
- **Total**: ~$176/month (if running 24/7)

**Cost Optimization**:
- Destroy infrastructure daily when not in use
- Use Spot instances for dev/test (bonus feature)
- Single NAT Gateway instead of HA setup
- Right-sized instances (t3a.medium)

---

## 📊 Monitoring & Observability

### Logging

**Application Logs**:
- Structured JSON logging in Flask
- Log levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
- Correlation IDs for request tracing

**Kubernetes Logs**:
```bash
# View application logs
kubectl logs -f deployment/flask-app -n backend

# View all pods in namespace
kubectl logs -f -l app=flask-app -n backend

# View MySQL logs
kubectl logs -f statefulset/flask-app-db -n backend
```

### Health Checks

**Liveness Probes**:
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 5000
  initialDelaySeconds: 30
  periodSeconds: 10
```

**Readiness Probes**:
```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Metrics

**Resource Monitoring**:
```bash
# Pod resource usage
kubectl top pods -n backend

# Node resource usage
kubectl top nodes
```

---

## 🔒 Security

### Secrets Management Architecture

**External Secrets Operator** manages all sensitive data:

```
AWS Secrets Manager (Source of Truth)
        │
        ├─> staging/backend/database
        │   └─> Credentials for MySQL
        │
        ├─> staging/backend/flask-app
        │   └─> API keys, encryption keys
        │
        ├─> staging/backend/admin
        │   └─> Initial admin credentials
        │
        └─> staging/backend/jwt-keys
            └─> RSA key pair for JWT signing

                    │
                    ▼
        External Secrets Operator
            (In-cluster sync)
                    │
                    ▼
        Kubernetes Secrets (Auto-synced)
                    │
        ├─> flask-app-db-credentials
        ├─> flask-app-secret
        ├─> flask-app-admin-credentials
        └─> flask-app-jwt-keys
                    │
                    ▼
            Application Pods
        (Environment variables)
```

**Benefits**:
- ✅ Secrets never stored in Git
- ✅ Automatic rotation support
- ✅ Centralized management in AWS
- ✅ Audit trail in AWS CloudTrail
- ✅ Encryption at rest and in transit

### AWS Secrets Created

1. **Database Credentials** (`staging/backend/database`):
   ```json
   {
     "DB_USER": "flask_user",
     "DB_PASSWORD": "<auto-generated>",
     "DB_HOST": "flask-app-db.backend.svc.cluster.local",
     "DB_PORT": "3306",
     "DB_NAME": "flask_staging"
   }
   ```

2. **Application Secrets** (`staging/backend/flask-app`):
   ```json
   {
     "SECRET_KEY": "<random-256-bit>",
     "API_TEST_KEY": "<random-key>",
     "DATABASE_ENCRYPTION_KEY": "<base64-encoded>"
   }
   ```

3. **Admin Credentials** (`staging/backend/admin`):
   ```json
   {
     "INITIAL_ADMIN_USER": "<secure-password>"
   }
   ```

4. **JWT Keys** (`staging/backend/jwt-keys`):
   ```json
   {
     "JWT_PRIVATE_KEY": "<RSA-4096-private-key>",
     "JWT_PUBLIC_KEY": "<RSA-4096-public-key>"
   }
   ```

### RBAC Configuration

**Service Account Permissions**:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: flask-app-secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames:
    - flask-app-db-credentials
    - flask-app-secret
    - flask-app-admin-credentials
    - flask-app-jwt-keys
  verbs: ["get", "list"]
```

### Network Security

**Network Policies**:
```yaml
# Backend → MySQL only
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-db-access
spec:
  podSelector:
    matchLabels:
      app: flask-app
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: mysql
    ports:
    - protocol: TCP
      port: 3306
```

---

## 🎁 Bonus Features Implemented

### Beginner Bonuses

✅ **1. Multi-stage Dockerfile**
- Stage 1: Build stage with all dependencies
- Stage 2: Runtime stage with minimal footprint
- Result: 60% smaller image size (from 1.2GB to 480MB)

✅ **2. Custom Application Code**
- ~800 lines of Python code
- 15+ REST API endpoints:
  - `GET /patients` - List all patients
  - `POST /patients` - Create patient
  - `GET /patients/{id}` - Get patient by ID
  - `PUT /patients/{id}` - Update patient
  - `DELETE /patients/{id}` - Delete patient
  - `GET /appointments` - List appointments
  - `POST /appointments` - Create appointment
  - `GET /messages` - List messages
  - `POST /messages` - Send message
  - Authentication endpoints (login, register, refresh token)

✅ **3. Semantic Versioning**
- Git tags with MAJOR.MINOR.PATCH format
- Docker images tagged with semantic versions
- Automated versioning in CI pipeline
- Current version: `v1.0.19`

### Intermediate Bonuses

✅ **4. Git Branching Strategy**
- `main` branch: Full CI/CD with deployment
- `feature/*` branches: CI only (no deployment)
- Branch protection rules enabled
- Pull request reviews required

✅ **5. Nginx Reverse Proxy (3-Tier Architecture)**
- Nginx serves static React frontend
- Nginx routes `/api/*` to Flask backend
- Kubernetes Ingress Controller
- TLS termination at load balancer

✅ **6. Helm Charts**
- Custom Helm charts for all applications
- Umbrella chart pattern with subcharts
- Values files for different environments (dev/stage/prod)
- Templates with proper labels and annotations

### Advanced Bonuses

✅ **7. Infrastructure Fully Managed by Terraform**
- Custom VPC module
- EKS cluster module
- ECR repositories
- IAM roles and policies
- IRSA configuration
- AWS Secrets Manager resources
- Single `terraform apply` provisions everything

✅ **8. Secrets Management (External Secrets Operator)**
- Integration with AWS Secrets Manager
- 4 ExternalSecret resources auto-syncing
- Secrets never stored in Git
- Automatic rotation support
- Sync wave ordering for dependencies

✅ **9. GitOps with ArgoCD**
- ArgoCD deployed via Terraform
- App of Apps pattern implemented
- Automatic sync from Git repository
- Self-healing enabled
- Automated pruning of removed resources

✅ **10. Fully Automated CI/CD with GitOps**
- GitHub Actions builds and tests
- Pushes image to ECR with version tag
- Updates Helm chart in GitOps repo
- ArgoCD detects change and deploys
- Zero manual intervention required

✅ **11. App of Apps Pattern**
- Parent ArgoCD application manages all child apps
- External Secrets Operator (sync-wave: -1)
- Backend application (sync-wave: 0)
- Frontend application (sync-wave: 1)
- Centralized management and deployment

### Additional Enhancements

✅ **Horizontal Pod Autoscaling (HPA)**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

✅ **Pod Disruption Budgets**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: flask-app
```

✅ **Resource Limits and Requests**
```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

✅ **ConfigMaps for Configuration**
- Environment-specific settings
- Feature flags
- Application tuning parameters

✅ **Persistent Storage**
- StatefulSet for MySQL
- EBS volumes via Storage Class
- 5Gi storage for staging environment

---

## 💰 Cost Optimization

### Infrastructure Costs

**Estimated Monthly Costs** (if running 24/7):
```
EKS Control Plane:        $73.00
EC2 (2x t3a.medium):      $60.00
NAT Gateway:              $33.00
EBS Volumes (10GB):       $10.00
ECR Storage:               $1.00
Secrets Manager:           $0.40
--------------------------------------
Total:                   ~$177.40/month
```

### Cost-Saving Strategies

1. **Destroy When Not in Use**:
   ```bash
   # End of day
   terraform destroy -auto-approve
   
   # Cost: $0 when destroyed
   ```

2. **Right-Sized Instances**:
   - Using t3a.medium (AMD) instead of t3.medium saves 10%
   - 2 nodes sufficient for staging workload

3. **Single NAT Gateway**:
   - Production: 2 NAT Gateways for HA = $66/month
   - Staging: 1 NAT Gateway = $33/month
   - Savings: $33/month

4. **Minimal EBS Storage**:
   - Only persistent storage for MySQL
   - GP3 volumes (cheaper than GP2)

5. **ECR Lifecycle Policies**:
   - Keep only last 10 images
   - Delete untagged images after 7 days

### Daily Workflow for Cost Control

```bash
#!/bin/bash
# Morning: Start infrastructure
cd terraform-eks
terraform apply -auto-approve

# Wait for cluster to be ready
aws eks update-kubeconfig --name demo-eks-cluster --region ap-south-1

# Deploy applications via ArgoCD
kubectl apply -f charts/backend/apps/staging/

# Evening: Destroy infrastructure
cd terraform-eks
terraform destroy -auto-approve
```

**Daily Cost**: ~$6/day (8 hours of usage)  
**Monthly Cost** (22 working days): ~$132/month

---

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. MySQL Pod CrashLoopBackOff

**Symptoms**:
```bash
kubectl get pods -n backend
# flask-app-db-0   0/1     CrashLoopBackOff
```

**Diagnosis**:
```bash
kubectl logs flask-app-db-0 -n backend
kubectl describe pod flask-app-db-0 -n backend
```

**Common Causes**:
- Password mismatch between secret and persisted data
- Startup probe timeout too short
- Missing secret keys (mysql-password, mysql-root-password)

**Solution**:
```bash
# Delete pod and PVC to force clean initialization
kubectl delete pod flask-app-db-0 -n backend
kubectl delete pvc data-flask-app-db-0 -n backend

# Pod will recreate with correct password from AWS Secrets Manager
```

#### 2. ExternalSecret Not Syncing

**Symptoms**:
```bash
kubectl get externalsecret -n backend
# STATUS: SecretSyncedError
```

**Diagnosis**:
```bash
kubectl describe externalsecret flask-app-db-credentials -n backend
```

**Common Causes**:
- IRSA role not configured correctly
- AWS secret doesn't exist
- Secret key mismatch
- Template rendering error (unescaped Helm templates)

**Solution**:
```bash
# Verify IRSA configuration
kubectl describe sa external-secrets -n external-secrets-system

# Check AWS secret exists
aws secretsmanager get-secret-value --secret-id staging/backend/database --region ap-south-1

# Delete and recreate ExternalSecret
kubectl delete externalsecret flask-app-db-credentials -n backend
kubectl apply -f backend/helm-charts/flask-app/templates/external-secret-database.yaml
```

#### 3. ArgoCD Application OutOfSync

**Symptoms**:
```bash
kubectl get applications -n argocd
# STATUS: OutOfSync
```

**Diagnosis**:
```bash
argocd app get flask-backend
argocd app diff flask-backend
```

**Solution**:
```bash
# Manual sync
argocd app sync flask-backend

# Enable auto-sync
argocd app set flask-backend --sync-policy automated
```

#### 4. ConfigMap Validation Error

**Symptoms**:
```
Error: ConfigMap.data values must be strings
```

**Cause**: Boolean or numeric values not quoted in values.yaml

**Solution**:
```yaml
# Wrong:
config:
  DEBUG: false
  DB_PORT: 3306

# Correct:
config:
  DEBUG: "false"
  DB_PORT: "3306"
```

#### 5. Terraform Destroy Hangs

**Symptoms**:
```bash
terraform destroy
# Stuck on "Destroying AWS Load Balancer..."
```

**Cause**: Kubernetes-created Load Balancers not deleted

**Solution**:
```bash
# Delete all Kubernetes services of type LoadBalancer
kubectl delete svc --all -n backend
kubectl delete svc --all -n frontend

# Delete all Ingress resources
kubectl delete ingress --all --all-namespaces

# Wait 2 minutes, then retry destroy
terraform destroy -auto-approve
```

### Verification Commands

```bash
# Check all pods are running
kubectl get pods --all-namespaces

# Check ExternalSecrets status
kubectl get externalsecret -n backend

# Check ArgoCD applications
kubectl get applications -n argocd

# Test backend API
curl http://<ALB-DNS>/api/health

# Test frontend
curl http://<ALB-DNS>/

# View application logs
kubectl logs -f deployment/flask-app -n backend

# Check resource usage
kubectl top pods -n backend
kubectl top nodes
```

---

## 📚 Additional Resources

### Documentation Links

- **Application Repository**: `https://github.com/akthm/demo-back` (Private)
- **Infrastructure Repository**: `https://github.com/akthm/terraform-eks` (Private)
- **GitOps Repository**: `https://github.com/akthm/demo-k8s-gitops` (Private)

### External Documentation

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [External Secrets Operator](https://external-secrets.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Charts Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

## 🎓 Learning Outcomes

Through this project, the following DevOps competencies were demonstrated:

### Technical Skills
✅ Infrastructure as Code (Terraform)  
✅ Container Orchestration (Kubernetes)  
✅ CI/CD Pipeline Development (GitHub Actions)  
✅ GitOps Practices (ArgoCD)  
✅ Secrets Management (External Secrets Operator)  
✅ Cloud Platform Expertise (AWS)  
✅ Application Development (Python Flask, React)  
✅ Database Management (MySQL)  
✅ Networking & Security (VPC, IAM, RBAC)  

### Best Practices
✅ Immutable infrastructure  
✅ Declarative configuration  
✅ Version control everything  
✅ Automated testing and deployment  
✅ Security by default  
✅ Observability and monitoring  
✅ Documentation-driven development  
✅ Cost optimization  

---

## 👤 Author

**Akthm**  
DevOps Engineer Portfolio Project  

**Contact**:
- GitHub: [@akthm](https://github.com/akthm)
- LinkedIn: [@akthm-daas](https://linkedin.com/in/akthm-daas)
- Email: [akthm.daas@gmail.com]

---

## 📄 License

This project is for educational and portfolio purposes.

---

## 🙏 Acknowledgments

- **Develeap** for the comprehensive DevOps training program
- **AWS** for providing cloud infrastructure
- **Open Source Community** for amazing tools (Kubernetes, ArgoCD, Helm, Terraform)

---

**Last Updated**: November 23, 2025  
**Version**: 1.0.19  
**Status**: ✅ Production Ready
