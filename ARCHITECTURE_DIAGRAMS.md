# Deployment Architecture Diagrams

Visual representation of the system architecture, deployment flow, and data flow.

---

## System Architecture (Deployment Ready)

```
┌────────────────────────────────────────────────────────────────────┐
│                   KUBERNETES CLUSTER (Staging)                     │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ Namespace: frontend                                        │  │
│  ├─────────────────────────────────────────────────────────────┤  │
│  │                                                              │  │
│  │  ┌─────────────────────────────────────────────────────┐   │  │
│  │  │ Deployment: nginx-frontend                          │   │  │
│  │  ├─────────────────────────────────────────────────────┤   │  │
│  │  │ Labels:                                             │   │  │
│  │  │  - app.kubernetes.io/name: nginx-front             │   │  │
│  │  │  - app.kubernetes.io/instance: nginx-frontend      │   │  │
│  │  │                                                      │   │  │
│  │  │ Pod (1 replica):                                    │   │  │
│  │  │  ├─ Container: frontend (akthm/demo-front:1.0.3)   │   │  │
│  │  │  ├─ Port: 80                                        │   │  │
│  │  │  ├─ Security Context:                              │   │  │
│  │  │  │  └─ runAsUser: 101 (non-root)                  │   │  │
│  │  │  ├─ ConfigMap: nginx-conf (nginx config)          │   │  │
│  │  │  └─ Resources:                                     │   │  │
│  │  │     ├─ Requests: 50m CPU, 64Mi Memory             │   │  │
│  │  │     └─ Limits: 500m CPU, 256Mi Memory             │   │  │
│  │  │                                                      │   │  │
│  │  │ Service (ClusterIP):                               │   │  │
│  │  │  └─ Port: 80 → 80                                 │   │  │
│  │  │                                                      │   │  │
│  │  │ Ingress (nginx):                                   │   │  │
│  │  │  └─ frontend-staging.example.internal             │   │  │
│  │  │     → nginx-frontend:80                           │   │  │
│  │  │                                                      │   │  │
│  │  │ NetworkPolicy:                                      │   │  │
│  │  │  ├─ Ingress: from ingress-nginx on 80/443        │   │  │
│  │  │  └─ Egress: to backend:8000, DNS:53, HTTPS:443   │   │  │
│  │  │                                                      │   │  │
│  │  │ RBAC:                                              │   │  │
│  │  │  ├─ ServiceAccount: nginx-front                   │   │  │
│  │  │  └─ Role: read configmaps                         │   │  │
│  │  └─────────────────────────────────────────────────────┘   │  │
│  │                                                              │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │ Namespace: backend                                        │  │
│  ├─────────────────────────────────────────────────────────────┤  │
│  │                                                              │  │
│  │  ┌─────────────────────────────────────────────────────┐   │  │
│  │  │ Deployment: flask-app                              │   │  │
│  │  ├─────────────────────────────────────────────────────┤   │  │
│  │  │ Labels:                                             │   │  │
│  │  │  - app.kubernetes.io/name: flask-app              │   │  │
│  │  │  - app.kubernetes.io/instance: flask-backend      │   │  │
│  │  │                                                      │   │  │
│  │  │ Pod (1 replica):                                    │   │  │
│  │  │  ├─ Container: flask-app (akthm/demo-back:stage-1)│   │  │
│  │  │  ├─ Port: 5000 (internal)                          │   │  │
│  │  │  ├─ Security Context:                              │   │  │
│  │  │  │  ├─ runAsUser: 1000 (non-root)                │   │  │
│  │  │  │  └─ capabilities: drop ALL                     │   │  │
│  │  │  ├─ Env Vars: from ConfigMap + Secrets           │   │  │
│  │  │  ├─ Health Probes:                                │   │  │
│  │  │  │  ├─ Readiness: GET /health (initial: 5s)      │   │  │
│  │  │  │  └─ Liveness: GET /health (initial: 15s)      │   │  │
│  │  │  └─ Resources:                                     │   │  │
│  │  │     ├─ Requests: 100m CPU, 256Mi Memory          │   │  │
│  │  │     └─ Limits: 500m CPU, 512Mi Memory            │   │  │
│  │  │                                                      │   │  │
│  │  │ Service (ClusterIP):                               │   │  │
│  │  │  └─ Port: 8000 → 5000                            │   │  │
│  │  │                                                      │   │  │
│  │  │ Config:                                             │   │  │
│  │  │  ├─ ConfigMap: flask-app-config (non-secret vars) │   │  │
│  │  │  ├─ Secret: flask-app-secret (sensitive vars)    │   │  │
│  │  │  ├─ ExternalSecret: from AWS Secrets Manager     │   │  │
│  │  │  └─ Secrets: JWT keys (pre-created)             │   │  │
│  │  │                                                      │   │  │
│  │  │ Volumes:                                            │   │  │
│  │  │  ├─ ConfigMap: nginx-conf (read-only)            │   │  │
│  │  │  └─ (temp dirs: /tmp for sessions)               │   │  │
│  │  │                                                      │   │  │
│  │  │ NetworkPolicy:                                      │   │  │
│  │  │  ├─ Ingress: from frontend:80/443 on port 8000   │   │  │
│  │  │  ├─ Ingress: from argocd on port 8000            │   │  │
│  │  │  └─ Egress: to DB:3306, DNS:53, HTTPS:443       │   │  │
│  │  │                                                      │   │  │
│  │  │ RBAC:                                              │   │  │
│  │  │  ├─ ServiceAccount: flask-app                    │   │  │
│  │  │  ├─ Role: read configmaps, specific secrets      │   │  │
│  │  │  └─ RoleBinding                                   │   │  │
│  │  │                                                      │   │  │
│  │  │ PodDisruptionBudget: minAvailable=1              │   │  │
│  │  └─────────────────────────────────────────────────────┘   │  │
│  │                                                              │  │
│  │  ┌─────────────────────────────────────────────────────┐   │  │
│  │  │ StatefulSet: flask-app-db (MySQL)                 │   │  │
│  │  ├─────────────────────────────────────────────────────┤   │  │
│  │  │                                                      │   │  │
│  │  │ Pod (1 replica):                                    │   │  │
│  │  │  ├─ Container: mysql (mysql:8.0.35)              │   │  │
│  │  │  ├─ Port: 3306                                     │   │  │
│  │  │  ├─ Environment:                                   │   │  │
│  │  │  │  ├─ MYSQL_ROOT_PASSWORD: (from secret)        │   │  │
│  │  │  │  ├─ MYSQL_DATABASE: flask_staging             │   │  │
│  │  │  │  └─ MYSQL_USER: flask_user                   │   │  │
│  │  │  └─ Storage:                                      │   │  │
│  │  │     └─ PVC: 1Gi (storage: standard)              │   │  │
│  │  │                                                      │   │  │
│  │  │ Service (ClusterIP):                               │   │  │
│  │  │  ├─ Name: flask-app-db                           │   │  │
│  │  │  └─ Port: 3306                                    │   │  │
│  │  │                                                      │   │  │
│  │  │ Persistence:                                        │   │  │
│  │  │  ├─ Storage Class: standard                       │   │  │
│  │  │  ├─ Size: 1Gi                                     │   │  │
│  │  │  └─ Claim: flask-app-db-data                     │   │  │
│  │  └─────────────────────────────────────────────────────┘   │  │
│  │                                                              │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ External Components (Pre-requisite)                     │
├──────────────────────────────────────────────────────────┤
│                                                          │
│ - Ingress Controller (nginx)                           │
│ - External Secrets Operator                           │
│ - Metrics Server (for HPA)                            │
│ - ArgoCD (gitops controller)                          │
│ - AWS Secrets Manager (secret storage)                │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
Internet User
     ↓ (HTTPS)
┌─────────────────────────────────┐
│ Ingress Controller              │
│ (frontend-staging.example.int)  │
└────────────┬────────────────────┘
             ↓ (port 80)
┌─────────────────────────────────┐
│ Nginx Frontend Pod              │
│ (frontend namespace)            │
│                                 │
│ ├─ React SPA                   │
│ ├─ Cache headers               │
│ ├─ Security headers            │
│ └─ API Proxy: /api             │
└────────────┬────────────────────┘
             ↓ (port 8000)
   ┌─────────────────────────┐
   │ Network Policy Check    │ ← ✅ ALLOWED: frontend → backend
   └────────────┬────────────┘
                ↓
┌──────────────────────────────────┐
│ Flask App Pod                    │
│ (backend namespace)              │
│                                  │
│ ├─ Flask App (port 5000)        │
│ ├─ Business Logic               │
│ ├─ Request Validation           │
│ ├─ JWT Auth                     │
│ └─ Database Queries             │
└────────────┬─────────────────────┘
             ↓ (port 3306)
   ┌─────────────────────────┐
   │ Network Policy Check    │ ← ✅ ALLOWED: backend → DB
   └────────────┬────────────┘
                ↓
┌──────────────────────────────────┐
│ MySQL Database                   │
│ (backend namespace)              │
│                                  │
│ ├─ Tables                        │
│ ├─ Persistent Storage (1Gi)      │
│ └─ Replication: standalone       │
└──────────────────────────────────┘

Response Flow (Reverse):
Database → Flask → Network Check → Nginx Proxy → Network Check → Client
```

---

## Deployment Flow (GitOps)

```
Developer Workflow:
──────────────────

1. Developer commits to 'staging' branch
   git commit -am "Update Flask version"
   git push origin staging
             ↓
┌──────────────────────────────┐
│ Git Repository (GitHub)      │
│ staging branch               │
│ ├─ apps/staging/flask*.yaml │
│ ├─ helm-charts/flask-app/   │
│ └─ helm-charts/nginx-front/ │
└──────────────────────────────┘
             ↓ (ArgoCD watches)
┌──────────────────────────────┐
│ ArgoCD (argocd namespace)     │
│                              │
│ Application: flask-backend   │
│  ├─ Repo: git repo           │
│  ├─ Path: helm-charts/flask  │
│  ├─ Branch: staging          │
│  └─ Values: values.*.yaml    │
│                              │
│ Application: nginx-frontend  │
│  ├─ Repo: git repo           │
│  ├─ Path: helm-charts/nginx  │
│  └─ Branch: staging          │
└──────────────────────────────┘
             ↓ (Detects drift)
┌──────────────────────────────┐
│ Helm Template Rendering      │
│                              │
│ values.yaml + values.stage   │
│ → Deployment specs           │
│ → ConfigMap templates        │
│ → Secret references          │
│ → Network Policy             │
│ → RBAC definitions           │
└──────────────────────────────┘
             ↓ (Creates resources)
┌──────────────────────────────┐
│ Kubernetes Cluster           │
│                              │
│ Applies manifests:           │
│ 1. Namespaces               │
│ 2. RBAC (roles, bindings)   │
│ 3. Secrets (external)        │
│ 4. ConfigMaps                │
│ 5. Services                  │
│ 6. Deployments/StatefulSets │
│ 7. Network Policies          │
│ 8. Ingress                   │
└──────────────────────────────┘
             ↓ (Pods start)
         DEPLOYMENT COMPLETE
             ↓
    Application is live on staging
```

---

## Security Boundaries

```
┌─────────────────────────────────────────────────────────────┐
│ SECURITY BOUNDARY 1: External Access                        │
│ (What's exposed to the internet)                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ ✅ ALLOWED: HTTPS to Ingress                         │ │
│  │  - frontend-staging.example.internal (only!)        │ │
│  │  - HTTP/HTTPS only                                  │ │
│  └───────────────────────────────────────────────────────┘ │
│                    ↓↓↓                                     │
│  ❌ BLOCKED: Direct access to pods/services              │
│  ❌ BLOCKED: K8s API access                              │
│  ❌ BLOCKED: Database port access                        │ │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ SECURITY BOUNDARY 2: Network Policies                       │
│ (What pods can talk to what)                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Frontend Namespace                                  │  │
│  │  └─ Nginx Pod                                      │  │
│  │     ├─ Ingress: from external (80/443) ✅          │  │
│  │     ├─ Egress: to Flask API ✅                     │  │
│  │     ├─ Egress: to DNS ✅                           │  │
│  │     └─ Egress: all other ❌                        │  │
│  └──────────────────────────────────────────────────────┘  │
│                    ↓ ✅                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Backend Namespace                                  │  │
│  │  ├─ Flask Pod                                      │  │
│  │  │  ├─ Ingress: from Frontend ✅                  │  │
│  │  │  ├─ Ingress: from ArgoCD ✅                    │  │
│  │  │  ├─ Egress: to MySQL ✅                        │  │
│  │  │  ├─ Egress: DNS ✅                             │  │
│  │  │  └─ Egress: HTTPS external APIs ✅            │  │
│  │  │                                                 │  │
│  │  └─ MySQL Pod                                     │  │
│  │     ├─ Ingress: from Flask ✅                    │  │
│  │     ├─ Ingress: from other ❌                    │  │
│  │     └─ Egress: none                               │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  ❌ Frontend ↔ Database: BLOCKED (network policy)         │
│  ❌ External ↔ Backend: BLOCKED (network policy)          │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ SECURITY BOUNDARY 3: Process Isolation                      │
│ (What processes can do)                                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Nginx Process:                                            │
│  ├─ User: nginx (UID 101) - non-root ✅                  │
│  ├─ Capabilities: NONE (dropped all) ✅                  │
│  ├─ Read /etc/nginx ✅                                  │
│  ├─ Write /var/cache/nginx ✅                           │
│  ├─ Privilege escalation: DENIED ✅                    │
│  └─ Host access: DENIED ✅                             │
│                                                             │
│  Flask Process:                                            │
│  ├─ User: app (UID 1000) - non-root ✅                 │
│  ├─ Capabilities: NONE (dropped all) ✅                  │
│  ├─ Read app code ✅                                    │
│  ├─ Write /tmp for sessions ✅                          │
│  ├─ Privilege escalation: DENIED ✅                    │
│  └─ Host access: DENIED ✅                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ SECURITY BOUNDARY 4: Secret Storage                         │
│ (Where sensitive data lives)                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Application Secrets:                                      │
│  ├─ AWS Secrets Manager (encrypted at rest) ✅           │
│  ├─ Audit trail via CloudTrail ✅                        │
│  ├─ Rotation support ✅                                  │
│  └─ Versioning ✅                                        │
│       ↓↓↓                                                  │
│  ├─ External Secrets Operator pulls secrets              │
│  └─ Creates K8s Secret (in etcd)                         │
│       ↓↓↓                                                  │
│  Pod receives via environment/volume                      │
│  ├─ Only pod can read ✅                                │
│  ├─ Not in pod logs (masking) ✅                        │
│  └─ Mounted as tmpfs (in-memory) ✅                     │
│                                                             │
│  Git Repository:                                           │
│  ├─ NO secrets committed ✅                              │
│  ├─ Configuration only                                    │
│  └─ Fully version controlled                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Request Lifecycle

```
1. USER REQUEST
   ┌─────────────────────────────────────────────────┐
   │ HTTPS GET /api/users                            │
   │ Host: frontend-staging.example.internal         │
   │ Authorization: Bearer <JWT token>               │
   └────────────────┬────────────────────────────────┘
                    ↓

2. DNS RESOLUTION
   ┌─────────────────────────────────────────────────┐
   │ frontend-staging.example.internal               │
   │  → Ingress Controller IP (public/floating)     │
   └────────────────┬────────────────────────────────┘
                    ↓

3. TLS HANDSHAKE
   ┌─────────────────────────────────────────────────┐
   │ TLS 1.3 established with Ingress                │
   │ Certificate: staging-tls-secret                 │
   └────────────────┬────────────────────────────────┘
                    ↓

4. INGRESS ROUTING
   ┌─────────────────────────────────────────────────┐
   │ Ingress Controller receives request             │
   │ Looks up rule: host match + path match         │
   │ Routes to: nginx-frontend service:80           │
   └────────────────┬────────────────────────────────┘
                    ↓

5. LOAD BALANCING
   ┌─────────────────────────────────────────────────┐
   │ Service (nginx-frontend:80)                     │
   │ Resolves endpoints → nginx pod IP              │
   │ Establishes connection                          │
   └────────────────┬────────────────────────────────┘
                    ↓

6. NGINX PROCESSING
   ┌─────────────────────────────────────────────────┐
   │ Nginx receives HTTP request                     │
   │ Process:                                        │
   │  1. Parse request                              │
   │  2. Check location /api                        │
   │  3. Proxy to flask-app:8000                    │
   │  4. Add headers (X-Real-IP, X-Forwarded-Proto) │
   └────────────────┬────────────────────────────────┘
                    ↓

7. NETWORK POLICY CHECK
   ┌─────────────────────────────────────────────────┐
   │ kubernetes NetworkPolicy engine                │
   │  Source: nginx-frontend pod (frontend NS)      │
   │  Destination: flask-app pod (backend NS)       │
   │  Port: 8000                                    │
   │  Action: ✅ ALLOW                              │
   └────────────────┬────────────────────────────────┘
                    ↓

8. FLASK SERVICE ROUTING
   ┌─────────────────────────────────────────────────┐
   │ Service (flask-app:8000)                        │
   │ Resolves endpoints → flask-app pod IP:5000    │
   │ Establishes connection                          │
   └────────────────┬────────────────────────────────┘
                    ↓

9. FLASK PROCESSING
   ┌─────────────────────────────────────────────────┐
   │ Flask Pod receives request at port 5000        │
   │ Process:                                        │
   │  1. Gunicorn receives (8 workers available)    │
   │  2. Route: /api/users → users blueprint       │
   │  3. JWT verification                          │
   │  4. Query validation                          │
   │  5. Database query                            │
   └────────────────┬────────────────────────────────┘
                    ↓

10. DATABASE QUERY
    ┌─────────────────────────────────────────────────┐
    │ SQLAlchemy ORM builds query                     │
    │ Sends to MySQL (flask-app-db:3306)             │
    │ Network Policy: ✅ ALLOW backend → DB          │
    └────────────────┬────────────────────────────────┘
                     ↓

11. DATABASE EXECUTION
    ┌─────────────────────────────────────────────────┐
    │ MySQL Server                                    │
    │  1. Connection pool (conn=<user>@flask-app)   │
    │  2. Authenticate user (flask_user)            │
    │  3. Execute SELECT query                      │
    │  4. Return result set                         │
    └────────────────┬────────────────────────────────┘
                     ↓

12. RESPONSE BACK
    Flask → JSON response
       ↓
    Nginx → Proxy response + security headers
       ↓
    Ingress → TLS encrypt
       ↓
    Network → HTTPS transmission
       ↓
    Client Browser → Display data

TIME: ~200ms (with optimizations)
```

---

## Component Dependencies

```
External Components (Must install first):
├─ Kubernetes 1.24+
├─ Ingress Controller (nginx)
│  └─ Required for: Ingress routing
├─ External Secrets Operator
│  └─ Required for: AWS Secrets Manager sync
├─ Metrics Server
│  └─ Required for: HPA functionality
├─ ArgoCD
│  └─ Required for: GitOps deployment
└─ AWS Secrets Manager
   └─ Required for: Secret storage

Our Components (Deployed via Helm):
├─ Flask Backend Chart
│  ├─ Deployment (Flask app)
│  ├─ StatefulSet (MySQL)
│  ├─ Service
│  ├─ ConfigMap
│  ├─ Secret
│  ├─ ExternalSecret
│  ├─ ServiceAccount
│  ├─ RBAC (Role/RoleBinding)
│  ├─ NetworkPolicy
│  ├─ HPA
│  └─ PodDisruptionBudget
│
└─ Nginx Frontend Chart
   ├─ Deployment (Nginx)
   ├─ Service
   ├─ ConfigMap (nginx.conf)
   ├─ Ingress
   ├─ ServiceAccount
   ├─ RBAC (Role/RoleBinding)
   ├─ NetworkPolicy
   └─ HPA (optional)

Data Flow Dependencies:
├─ Frontend DNS → Ingress Controller
├─ Ingress → Service → Pod
├─ Pod → Pod (via Network Policy)
├─ Pod → MySQL (via Service)
├─ MySQL → Storage (PVC)
└─ External Secrets → AWS → K8s Secret → Pod
```

---

## Scaling Scenarios

```
CURRENT (Staging):
┌─────────────────────────────┐
│ Frontend:  1 pod × 1 NS     │
│ Backend:   1 pod × 1 NS     │
│ Database:  1 pod × 1 NS     │
│ Total:     3 pods           │
│ Resources: ~1 CPU, 1Gi RAM  │
└─────────────────────────────┘

SCALED UP (Staging+ for testing):
┌─────────────────────────────┐
│ Frontend:  2 pods × 1 NS    │
│ Backend:   2 pods × 1 NS    │
│ Database:  1 pod × 1 NS     │
│ Total:     5 pods           │
│ Resources: ~2 CPU, 2.5Gi    │
│ HPA enabled: yes            │
└─────────────────────────────┘
   Modification: Update values.stage.yaml
   hpa.enabled: true
   hpa.maxReplicas: 3

PRODUCTION READY:
┌─────────────────────────────┐
│ Frontend:  3 pods × 1 NS    │
│ Backend:   3 pods × 1 NS    │
│ Database:  3 pods (replica) │
│ Total:     9 pods           │
│ Resources: ~6 CPU, 6Gi RAM  │
│ HPA enabled: yes            │
│ Backup: daily               │
│ Monitoring: full            │
└─────────────────────────────┘
   Modification: Use values.prod.yaml
   replicaCount: 3
   db.architecture: replication
```

---

**Last Updated:** 2025-11-17  
**Diagram Version:** 1.0  
**Status:** Complete
