# Flask + Nginx Kubernetes Deployment - Staging Ready

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Security Implementation](#security-implementation)
- [Configuration Management](#configuration-management)
- [Deployment Guide](#deployment-guide)
- [Verification & Troubleshooting](#verification--troubleshooting)
- [Best Practices](#best-practices)

---

## Overview

This project contains production-ready Kubernetes deployment manifests and Helm charts for a Flask backend API with Nginx frontend service. The configuration is optimized for staging environment deployment with security best practices, using ArgoCD for GitOps-based deployment orchestration.

**Key Features:**
- 🐳 Containerized Flask backend with Gunicorn
- 📦 Nginx React SPA reverse proxy with API gateway
- 🔐 Security-hardened with pod security contexts, RBAC, and network policies
- 📊 Health checks (liveness & readiness probes)
- 🔄 Blue-green deployment support via ArgoCD
- 📈 Horizontal Pod Autoscaling (HPA) ready
- 🔑 JWT authentication support (RS256)
- 🗄️ MySQL database integration
- 🤝 External secrets management (AWS Secrets Manager)
- 🛡️ Network policies for microsegmentation

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────┐          ┌──────────────────────┐  │
│  │  frontend namespace │          │  backend namespace   │  │
│  │                     │          │                      │  │
│  │  ┌───────────────┐  │          │  ┌──────────────────┐│  │
│  │  │ Nginx Pod(s)  │  │          │  │ Flask Pod(s)     ││  │
│  │  │ - React SPA   │  │ ────────► │  │ - Gunicorn       ││  │
│  │  │ - API Proxy   │  │          │  │ - SQLAlchemy ORM ││  │
│  │  └───────────────┘  │          │  └──────────────────┘│  │
│  │        ↓            │          │        ↓             │  │
│  │  Service (80/443)   │          │  Service (8000)      │  │
│  │                     │          │        ↓             │  │
│  └─────────────────────┘          │  ┌──────────────────┐│  │
│           ↓                        │  │ MySQL StatefulSet││  │
│        Ingress                     │  │ - Storage        ││  │
│      (external access)             │  └──────────────────┘│  │
│                                    │                      │  │
│                                    └──────────────────────┘  │
│                                                               │
└──────────────────────────────────────────────────────────────┘

External Component (managed externally):
  ├── ArgoCD (argocd namespace) - watches git repo for config changes
  ├── External Secrets Operator - syncs AWS Secrets Manager → K8s secrets
  └── Ingress Controller (nginx) - routes external traffic
```

### Port Mapping

| Component | Internal Port | Service Port | Access |
|-----------|--------------|-------------|--------|
| Flask App | 5000 | 8000 | Internal (backend service) |
| Nginx | 80 | 80 | External (ingress) |
| MySQL | 3306 | N/A | Internal (backend only) |

---

## Prerequisites

### Required Tools
- **kubectl** >= 1.24 - Kubernetes CLI
- **helm** >= 3.10 - Package manager for Kubernetes
- **git** - Version control
- **Docker** (optional, for building images locally)

### Required Kubernetes Components
- **ArgoCD** >= 2.6 - GitOps deployment controller
- **External Secrets Operator** - For AWS Secrets Manager integration
- **Nginx Ingress Controller** - For HTTP/HTTPS routing
- **Metrics Server** - For HPA functionality (usually pre-installed)

### Required AWS Resources (for staging)
- AWS Secrets Manager - Store sensitive configuration
- IAM role with `secretsmanager:GetSecretValue` permission
- EKS cluster (or any Kubernetes 1.24+ cluster)

### Application Prerequisites
- Docker images built and pushed to registry:
  - `akthm/demo-back:stage-1` (Flask backend)
  - `akthm/demo-front:1.0.3` (Nginx frontend)
- Database credentials and connection string

---

## Project Structure

```
.
├── README.md                          # This file
├── setup-staging.sh                   # Staging environment setup script
│
├── apps/                              # ArgoCD Application manifests
│   └── staging/
│       ├── flask-backend.yaml         # ArgoCD app for backend
│       └── nginx-front.yaml           # ArgoCD app for frontend
│
└── helm-charts/                       # Helm charts directory
    ├── flask-app/                     # Flask backend chart
    │   ├── Chart.yaml                 # Chart metadata
    │   ├── values.yaml                # Default values
    │   ├── values.stage.yaml          # Staging-specific overrides
    │   ├── values.prod.yaml           # Production-specific overrides (reference)
    │   └── templates/
    │       ├── _helpers.tpl           # Template functions
    │       ├── deployment.yaml        # Deployment spec
    │       ├── service.yaml           # Service spec
    │       ├── configmap.yaml         # ConfigMap for env vars
    │       ├── secret.yaml            # Secret for sensitive data
    │       ├── external-secret.yaml   # External Secrets resource
    │       ├── serviceaccount.yaml    # Service account
    │       ├── rbac.yaml              # Role and RoleBinding
    │       ├── networkpolicy.yaml     # Network policies
    │       ├── hpa.yaml               # Horizontal Pod Autoscaler
    │       ├── poddisruptionbudget.yaml # Pod disruption budget
    │       └── NOTES.txt              # Post-install notes
    │
    └── nginx-front/                   # Nginx frontend chart
        ├── Chart.yaml                 # Chart metadata
        ├── values.yaml                # Default values
        └── templates/
            ├── _helpers.tpl           # Template functions
            ├── deployment.yaml        # Deployment spec
            ├── service.yaml           # Service spec
            ├── configmap-nginx.yaml   # Nginx configuration
            ├── ingress.yaml           # Ingress resource
            ├── serviceaccount.yaml    # Service account
            ├── rbac.yaml              # Role and RoleBinding
            ├── networkpolicy.yaml     # Network policies
            └── NOTES.txt              # Post-install notes
```

---

## Security Implementation

### 1. **Pod Security Context**

All pods run as non-root users with restricted permissions:

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000              # Non-root user
  runAsGroup: 1000
  fsGroup: 1000
  fsGroupChangePolicy: OnRootMismatch

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: false  # Flask needs temp directory
```

**Impact:** Limits blast radius of container compromise.

### 2. **Network Policies**

Implemented microsegmentation using Kubernetes NetworkPolicies:

**Backend Network Policy:**
- ✅ Ingress: Only from frontend namespace on port 8000
- ✅ Ingress: Only from argocd namespace
- ✅ Egress: DNS (UDP 53) to all namespaces
- ✅ Egress: Port 3306 to MySQL pods
- ✅ Egress: HTTPS (443) to external APIs

**Frontend Network Policy:**
- ✅ Ingress: From ingress-nginx controller on ports 80/443
- ✅ Ingress: From anywhere on ports 80/443
- ✅ Egress: DNS queries
- ✅ Egress: Port 8000 to backend API
- ✅ Egress: HTTPS to external resources

**Important:** Enable in your cluster before deploying.

### 3. **RBAC Authorization**

Service accounts with minimal permissions:

```yaml
# Each chart creates its own service account
# Permissions limited to:
# - Read ConfigMaps
# - Read specific Secrets (only those needed)
```

**Deployment:**
```bash
kubectl apply -f helm-charts/flask-app/templates/rbac.yaml
kubectl apply -f helm-charts/nginx-front/templates/rbac.yaml
```

### 4. **Secrets Management**

**Current Implementation:**
- Non-sensitive config → **ConfigMap** (visible, versioned in git)
- Sensitive data → **Secret** (sealed, never in git)
- External secrets → **AWS Secrets Manager** (external-secrets-operator)

**Secrets Required (in AWS Secrets Manager):**
```
staging/backend/database-url  = "mysql://user:pass@host/db"
staging/backend/flask-key     = "secret-app-key"
```

### 5. **Image Scanning**

Recommended practice: Scan images for vulnerabilities.

```bash
# Example with Trivy
trivy image akthm/demo-back:stage-1
trivy image akthm/demo-front:1.0.3
```

---

## Configuration Management

### Configuration Hierarchy

```
values.yaml (base defaults)
    ↓
values.stage.yaml (staging overrides)
    ↓
Final rendered values
```

### Key Configuration Values

#### Backend (`helm-charts/flask-app/values.yaml`)

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `replicaCount` | int | Number of Flask pod replicas | 1 |
| `image.repository` | string | Docker image name | `akthm/demo-back` |
| `image.tag` | string | Docker image tag | `1.0.14` |
| `service.port` | int | Kubernetes service port | 8000 |
| `service.targetPort` | int | Container port | 5000 |
| `config.DEBUG` | bool | Flask debug mode | "0" |
| `config.GUNICORN_WORKERS` | int | Gunicorn worker processes | 2 |
| `config.CORS_ORIGINS` | string | Allowed CORS origins | See values.yaml |
| `resources.requests.cpu` | string | CPU request | 100m |
| `resources.requests.memory` | string | Memory request | 256Mi |
| `resources.limits.cpu` | string | CPU limit | 500m |
| `resources.limits.memory` | string | Memory limit | 512Mi |

#### Frontend (`helm-charts/nginx-front/values.yaml`)

| Variable | Type | Description | Default |
|----------|------|-------------|---------|
| `replicaCount` | int | Number of Nginx replicas | 1 |
| `image.tag` | string | Docker image tag | `1.0.3` |
| `backend.serviceHost` | string | Backend service DNS | `flask-app` |
| `backend.servicePort` | int | Backend service port | 8000 |
| `backend.path` | string | API endpoint path prefix | `/api` |
| `ingress.hosts[0].host` | string | Hostname for ingress | `frontend.local` |

### Environment Variables

Passed via ConfigMap to Flask application:

```yaml
DEBUG=0                                          # Development/Production
DOCKERIZED=true                                  # Container detection
GUNICORN_WORKERS=2                               # Worker processes
CORS_ORIGINS=https://frontend-staging.example.internal
ENVIRONMENT=staging
JWT_ALGORITHM=RS256                              # Authentication
JWT_ISSUER=my-backend
JWT_AUDIENCE=my-frontend
SQLALCHEMY_TRACK_MODIFICATIONS=False
API_TEST_MODE=false
DB_FALLBACK_TO_SQLITE_IN_MEMORY=false
```

### Database Configuration

MySQL subchart (`bitnami/mysql`):

```yaml
db:
  enabled: true                  # Enable MySQL deployment
  architecture: standalone       # For staging (not replication)
  image:
    repository: mysql
    tag: "8.0.35"
  auth:
    database: "flask_staging"    # Database name
    username: "flask_user"       # DB user
    password: (from secret)      # DB password
  primary:
    persistence:
      enabled: true
      size: 1Gi
      storageClass: "standard"   # Adjust per cluster
```

---

## Deployment Guide

### Step 1: Prepare Cluster

```bash
# 1. Create namespaces and setup prerequisites
chmod +x setup-staging.sh
./setup-staging.sh

# 2. Verify external-secrets-operator is installed
kubectl get deployment -n external-secrets-system external-secrets

# 3. Verify ingress controller is running
kubectl get deployment -n ingress-nginx nginx-ingress-controller
```

### Step 2: Setup Secrets in AWS

```bash
# Login to AWS console or use CLI
aws secretsmanager create-secret \
  --name staging/backend/database-url \
  --secret-string "mysql://flask_user:password@flask-app-db:3306/flask_staging" \
  --region ap-south-1

aws secretsmanager create-secret \
  --name staging/backend/flask-key \
  --secret-string "your-flask-secret-key-here" \
  --region ap-south-1
```

### Step 3: Update Git Repository

```yaml
# Update apps/staging/flask-backend.yaml
source:
  repoURL: https://github.com/YOUR-ORG/your-gitops-repo.git  # ← Your repo
  targetRevision: staging
  path: helm-charts/flask-app
```

```yaml
# Update apps/staging/nginx-front.yaml
source:
  repoURL: https://github.com/YOUR-ORG/your-gitops-repo.git  # ← Your repo
  targetRevision: staging
  path: helm-charts/nginx-front
```

### Step 4: Deploy via ArgoCD

```bash
# Apply ArgoCD Application manifests
kubectl apply -f apps/staging/flask-backend.yaml
kubectl apply -f apps/staging/nginx-front.yaml

# Verify ArgoCD applications are created
kubectl get applications -n argocd
# Output should show:
# NAME              SYNC STATUS   HEALTH STATUS
# flask-backend     OutOfSync     Progressing
# nginx-frontend    OutOfSync     Progressing

# Wait for sync and health to become "Synced" and "Healthy"
kubectl get applications -n argocd --watch
```

### Step 5: Manual Helm Deployment (Alternative)

If not using ArgoCD:

```bash
# Add MySQL chart dependency
helm dependency update helm-charts/flask-app/

# Deploy Flask backend
helm install flask-backend \
  helm-charts/flask-app/ \
  -n backend \
  --create-namespace \
  -f helm-charts/flask-app/values.yaml \
  -f helm-charts/flask-app/values.stage.yaml

# Deploy Nginx frontend
helm install nginx-frontend \
  helm-charts/nginx-front/ \
  -n frontend \
  --create-namespace \
  -f helm-charts/nginx-front/values.yaml
```

---

## Verification & Troubleshooting

### Deployment Verification Checklist

```bash
# 1. Check pod status
kubectl get pods -n backend
kubectl get pods -n frontend

# Output should show: 1/1 Running

# 2. Check service connectivity
kubectl get svc -n backend
kubectl get svc -n frontend

# 3. Check ingress
kubectl get ingress -n frontend

# 4. View pod logs
kubectl logs -n backend -l app.kubernetes.io/name=flask-app --tail=50
kubectl logs -n frontend -l app.kubernetes.io/name=nginx-front --tail=50

# 5. Test health endpoints
kubectl port-forward -n backend svc/flask-app 8000:8000
curl http://localhost:8000/health

# 6. Check resource usage
kubectl top pods -n backend
kubectl top pods -n frontend

# 7. View events
kubectl describe pod -n backend -l app.kubernetes.io/name=flask-app
kubectl describe pod -n frontend -l app.kubernetes.io/name=nginx-front
```

### Common Issues & Solutions

#### 1. **Pod Stuck in ImagePullBackOff**

```bash
# Problem: Docker image not found
# Solution: Ensure image exists in registry

kubectl describe pod -n backend <pod-name> | grep -A 10 "Events:"

# Pull and push image
docker pull akthm/demo-back:stage-1
docker tag akthm/demo-back:stage-1 your-registry/demo-back:stage-1
docker push your-registry/demo-back:stage-1

# Update values.yaml with correct image path
```

#### 2. **Database Connection Failed**

```bash
# Check MySQL service is running
kubectl get svc -n backend | grep db

# Check MySQL pod logs
kubectl logs -n backend flask-backend-db-0 --tail=50

# Verify database credentials match
kubectl get secret flask-backend-db -n backend -o jsonpath='{.data.mysql-password}' | base64 -d

# Test connectivity from Flask pod
kubectl exec -it <flask-pod> -n backend -- \
  mysql -h flask-app-db -u flask_user -p flask_staging -e "SELECT 1;"
```

#### 3. **Ingress Not Routing Traffic**

```bash
# Check ingress status
kubectl describe ingress -n frontend nginx-frontend

# Verify backend service is reachable
kubectl port-forward -n backend svc/flask-app 8000:8000 &
curl http://localhost:8000/api/health

# Check Nginx configuration inside container
kubectl exec -it <nginx-pod> -n frontend -- cat /etc/nginx/conf.d/default.conf

# Verify DNS resolution
kubectl exec -it <nginx-pod> -n frontend -- nslookup flask-app.backend.svc.cluster.local
```

#### 4. **Network Policy Blocking Traffic**

```bash
# Temporarily disable network policies for debugging
kubectl delete networkpolicy --all -n backend
kubectl delete networkpolicy --all -n frontend

# Verify connectivity works
# If yes, re-apply network policies and check configuration

kubectl apply -f helm-charts/flask-app/templates/networkpolicy.yaml
kubectl apply -f helm-charts/nginx-front/templates/networkpolicy.yaml

# Verify policies
kubectl get networkpolicy -n backend
kubectl get networkpolicy -n frontend
```

#### 5. **Secrets Not Loading**

```bash
# Check if external-secrets resource exists
kubectl get externalsecrets -n backend

# Check external-secrets operator logs
kubectl logs -n external-secrets-system -l app=external-secrets --tail=50

# Verify AWS credentials are mounted
kubectl describe pod -n external-secrets-system external-secrets-0

# Manually verify AWS secret exists
aws secretsmanager get-secret-value --secret-id staging/backend/database-url
```

---

## Best Practices

### 1. **Image Management**

✅ **DO:**
- Use specific image tags (never `latest`)
- Tag images with git commit SHA for traceability
- Scan images for vulnerabilities regularly
- Use private registries for proprietary code

❌ **DON'T:**
- Push images without scanning
- Use `latest` tag in production
- Hard-code secrets in images

### 2. **Resource Management**

✅ **DO:**
- Always set resource requests and limits
- Monitor usage and adjust accordingly
- Use HPA for predictable load patterns
- Set appropriate timeouts

```yaml
resources:
  requests:
    cpu: 100m         # Conservative minimum
    memory: 256Mi
  limits:
    cpu: 500m         # Max allowed
    memory: 512Mi
```

❌ **DON'T:**
- Leave resources empty (defaults to unlimited)
- Set limits too low (causes OOMKills)
- Ignore memory leaks

### 3. **Health Checks**

✅ **DO:**
- Implement `/health` endpoint in application
- Use readiness probes (for traffic)
- Use liveness probes (for recovery)
- Set appropriate thresholds

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 15
  periodSeconds: 20
  timeoutSeconds: 5
  failureThreshold: 3
```

❌ **DON'T:**
- Deploy without health checks
- Use TCP probes for HTTP services
- Set thresholds too aggressive

### 4. **Secrets Management**

✅ **DO:**
- Use external secret management (AWS Secrets Manager)
- Rotate secrets regularly
- Never commit secrets to git
- Use RBAC to limit secret access

❌ **DON'T:**
- Store secrets in ConfigMaps
- Commit `.env` files
- Share credentials between environments
- Log secrets

### 5. **Monitoring & Logging**

✅ **DO:**
- Aggregate logs to centralized service
- Monitor CPU, memory, disk I/O
- Set up alerting for anomalies
- Track deployment changes

❌ **DON'T:**
- Ignore pod restart loops
- Skip metric collection
- Log sensitive data

### 6. **GitOps Workflow**

✅ **DO:**
- Keep values in git, secrets in secure storage
- Use branch protection rules
- Require code reviews
- Automate via ArgoCD

❌ **DON'T:**
- Apply changes directly with `kubectl apply`
- Mix manual and automated deployments
- Deploy without version control

---

## Upgrading Helm Charts

### Update Chart Version

```bash
# 1. Increment version in Chart.yaml
# 2. Update app version if application changed
# 3. Commit to git

# 4. Update Helm dependencies
helm dependency update helm-charts/flask-app/

# 5. Validate templates
helm template flask-backend helm-charts/flask-app/ \
  -f helm-charts/flask-app/values.yaml \
  -f helm-charts/flask-app/values.stage.yaml

# 6. Dry-run install
helm install flask-backend helm-charts/flask-app/ \
  -n backend \
  --dry-run \
  -f helm-charts/flask-app/values.stage.yaml

# 7. Upgrade (or let ArgoCD handle it)
helm upgrade flask-backend helm-charts/flask-app/ \
  -n backend \
  -f helm-charts/flask-app/values.yaml \
  -f helm-charts/flask-app/values.stage.yaml
```

---

## Support & Maintenance

### Regular Tasks

- **Weekly:** Review pod restart counts and error logs
- **Monthly:** Audit RBAC permissions and network policies
- **Quarterly:** Scan images for vulnerabilities
- **Quarterly:** Update Helm dependencies

### Key Contacts

- **ArgoCD Issues:** Check ArgoCD UI at `https://argocd.your-domain`
- **Kubernetes Issues:** Contact infrastructure team
- **Application Issues:** See Flask app logs

---

## References

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [External Secrets Operator](https://external-secrets.io/)
- [OWASP Container Security](https://cheatsheetseries.owasp.org/cheatsheets/Container_Security_Cheat_Sheet.html)

---

## License

This project is proprietary. Unauthorized distribution is prohibited.

---

**Last Updated:** 2025-11-17  
**Status:** Staging Ready ✅
