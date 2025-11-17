# Configuration Reference Guide

Complete reference for all configurable values in the Helm charts.

---

## Table of Contents

- [Flask Backend Chart](#flask-backend-chart)
- [Nginx Frontend Chart](#nginx-frontend-chart)
- [Environment-Specific Overrides](#environment-specific-overrides)
- [Secret Management](#secret-management)

---

## Flask Backend Chart

**Chart Location:** `helm-charts/flask-app/`

### Chart Metadata

```yaml
# Chart.yaml
name: flask-app
description: Flask backend with SQLAlchemy ORM and JWT authentication
type: application
version: 0.1.0
appVersion: "1.16.0"

dependencies:
  - name: mysql
    version: "14.0.3"
    repository: "https://charts.bitnami.com/bitnami"
    alias: db
    condition: db.enabled
```

### Base Values Reference

```yaml
# Replica and Deployment Configuration
replicaCount: 1                    # Number of Flask pods

# Container Image
image:
  repository: akthm/demo-back    # Docker registry path
  pullPolicy: IfNotPresent       # Image pull policy (Always/IfNotPresent/Never)
  tag: "1.0.14"                  # Image tag (overridden by ArgoCD)

# Service Configuration
service:
  type: ClusterIP                 # Service type (ClusterIP/LoadBalancer/NodePort)
  port: 8000                      # Kubernetes service port
  targetPort: 5000                # Container port (Flask/Gunicorn listens here)

# Health Probes
probes:
  path: "/health"                 # Health check endpoint
  initialDelaySeconds: 15         # Delay before first check
  periodSeconds: 10               # Check interval
  timeoutSeconds: 5               # Check timeout

livenessProbe:                     # Kills pod if unhealthy
  httpGet:
    path: "/health"
    port: http
  initialDelaySeconds: 15
  periodSeconds: 10
  timeoutSeconds: 5

readinessProbe:                    # Removes from load balancer if not ready
  httpGet:
    path: "/health"
    port: http
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 5

# Horizontal Pod Autoscaling
hpa:
  enabled: false                  # Enable/disable HPA
  minReplicas: 1                  # Minimum pods
  maxReplicas: 2                  # Maximum pods
  targetCPUUtilizationPercentage: 70  # Target CPU %

autoscaling:                       # Alternative HPA config
  enabled: false
  minReplicas: 1
  maxReplicas: 2
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# Service Account
serviceAccount:
  create: true                    # Create service account
  name: flask-app                 # Service account name

# Pod Configuration
podAnnotations:
  prometheus.io/scrape: "false"   # Prometheus scraping

podLabels:
  app: flask-backend
  version: "1"

imagePullSecrets: []               # Pull secrets for private registries

# Security Context
podSecurityContext:
  runAsNonRoot: true             # Don't run as root
  runAsUser: 1000                # Run as UID 1000
  runAsGroup: 1000               # Run as GID 1000
  fsGroup: 1000                  # Filesystem group
  fsGroupChangePolicy: OnRootMismatch

securityContext:
  allowPrivilegeEscalation: false # No privilege escalation
  capabilities:
    drop:
      - ALL                       # Drop all Linux capabilities
  readOnlyRootFilesystem: false   # Flask needs /tmp directory

# Resource Limits
resources:
  requests:
    cpu: 100m                      # Guaranteed CPU
    memory: 256Mi                  # Guaranteed memory
  limits:
    cpu: 500m                      # Maximum CPU
    memory: 512Mi                  # Maximum memory

# Volume Mounts
volumeMounts: []
volumes: []

# Node Selection
nodeSelector: {}
affinity: {}
tolerations: []

# Configuration (non-sensitive)
config:
  DEBUG: "0"                       # Flask debug mode (0=off)
  DOCKERIZED: "true"              # Container detection
  GUNICORN_WORKERS: "2"           # Gunicorn worker processes
  BACKEND_PORT: "5000"            # Internal port
  CORS_ORIGINS: "http://localhost:5173,https://frontend-staging.example.internal"
  SQLALCHEMY_TRACK_MODIFICATIONS: "False"
  JWT_ACCESS_TTL: "900"           # 15 minutes
  JWT_REFRESH_TTL: "2592000"      # 30 days
  JWT_COOKIE_NAME: "rt"
  JWT_CSRF_COOKIE: "csrf_refresh_root"
  JWT_COOKIE_SECURE: "false"      # HTTPS only (set true in prod)
  JWT_COOKIE_SAMESITE: "Lax"
  JWT_COOKIE_DOMAIN: ""
  JWT_LEEWAY: "30"                # Clock skew tolerance
  API_TEST_MODE: "false"
  DB_FALLBACK_TO_SQLITE_IN_MEMORY: "false"

# External Secrets
externalSecrets:
  enabled: true                   # Enable external secrets
  secretStoreRef:
    name: "aws-secrets-manager"   # AWS Secrets Manager store
    kind: "ClusterSecretStore"
  databaseUrlKey: "staging/backend/database-url"  # AWS secret key
  flaskKey: "staging/backend/flask-key"           # AWS secret key

# JWT Configuration
jwt:
  enabled: true
  algorithm: RS256                # RS256 (recommended for security)
  issuer: "my-backend"            # JWT issuer claim
  audience: "my-frontend"         # JWT audience claim
  existingSecret: "backend-jwt-keys"  # Pre-created secret
  createSecret: false             # Don't create new secret
  privateKeyKey: "JWT_PRIVATE_KEY"    # Key name in secret
  publicKeyKey: "JWT_PUBLIC_KEY"      # Key name in secret

# Application Secrets (sensitive)
secrets:
  DATABASE_ENCRYPTION_KEY: "RrI-kQ5W5A4fk3YJu4siDXCTsGhW7cvPbq859VHYFKc="
  SECRET_KEY: "change-me-in-production"
  INITIAL_ADMIN_USER: "{user : 'admin', password: 'admin'}"
  DB_TYPE: "mysql"
  DB_USER: "flask_user"
  DB_PASSWORD: "userpassword"     # Override in values.stage.yaml
  DB_HOST: "flask-app-db"         # MySQL service hostname
  DB_PORT: "3306"
  DB_NAME: "flask_db"
  API_TEST_KEY: ""

# MySQL Database (Bitnami Subchart)
db:
  enabled: true                   # Enable MySQL deployment
  
  auth:
    rootPassword: secretrootpassword   # MySQL root password
    database: flask_db            # Default database
    username: flask_user          # Database user
    password: userpassword        # Database password
  
  image:
    registry: docker.io
    repository: mysql
    tag: "8.0.35"
  
  architecture: standalone        # standalone/replication
  
  fullnameOverride: "flask-app-db"    # Service name
  
  primary:
    persistence:
      enabled: true               # Persistent storage
      storageClass: "standard"    # Storage class name
      size: 1Gi                   # PVC size
  
  configuration: |-               # MySQL configuration
    [mysqld]
    default_authentication_plugin=mysql_native_password
    character-set-server=utf8mb4
    collation-server=utf8mb4_unicode_ci

# Ingress (for API access)
ingress:
  enabled: false
  className: ""
  hosts: []
  tls: []

# HTTPRoute (Gateway API)
httpRoute:
  enabled: false
  parentRefs: []
  hostnames: []
  rules: []
```

### Staging Override Values

```yaml
# values.stage.yaml
replicaCount: 1                    # Single replica for cost

image:
  tag: "stage-1"                   # Staging image tag

service:
  type: ClusterIP
  port: 8000
  targetPort: 5000

externalSecrets:
  enabled: true
  databaseUrlKey: "staging/backend/database-url"
  flaskKey: "staging/backend/flask-key"

db:
  auth:
    database: "flask_staging"
    username: "flask_user"

config:
  DEBUG: "0"
  CORS_ORIGINS: "http://localhost:5173,https://frontend-staging.example.internal"
  ENVIRONMENT: "staging"

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: "api-staging.example.internal"
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 1

hpa:
  enabled: false
```

---

## Nginx Frontend Chart

**Chart Location:** `helm-charts/nginx-front/`

### Chart Metadata

```yaml
# Chart.yaml
apiVersion: v2
name: nginx-front
description: React SPA served by Nginx
type: application
version: 0.1.0
appVersion: "1.0.1"
```

### Base Values Reference

```yaml
# Replica Configuration
replicaCount: 1                    # Number of Nginx pods

# Container Image
image:
  repository: akthm/demo-front   # Docker registry path
  tag: "1.0.3"                    # Image tag
  pullPolicy: IfNotPresent        # Pull policy

# Service Configuration
service:
  type: ClusterIP                 # Service type
  port: 80                        # Service port

# Ingress Configuration
ingress:
  enabled: true                   # Enable ingress
  className: ""                   # Ingress class (nginx)
  annotations: {}                 # Annotations
  hosts:
    - host: frontend.local        # Hostname
      paths:
        - path: /
          pathType: Prefix        # Path type
  tls: []                         # TLS configuration

# Backend API Configuration
backend:
  enabled: true                   # Enable API proxy
  serviceHost: "flask-app"        # Backend service name
  servicePort: 8000               # Backend service port
  path: "/api"                    # API path prefix

# Resource Limits
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 500m
    memory: 256Mi

# Horizontal Pod Autoscaling
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 1
  targetCPUUtilizationPercentage: 60
  targetMemoryUtilizationPercentage: 70

# Node Selection
nodeSelector: {}
tolerations: []
affinity: {}

# Pod Annotations
podAnnotations: {}

# Security Context
securityContext:
  enabled: true
  runAsUser: 101                  # Nginx user
  runAsGroup: 101
  runAsNonRoot: true
  fsGroup: 101
  fsGroupChangePolicy: "OnRootMismatch"

podSecurityContext: {}
```

### Nginx Configuration

The Nginx configuration is embedded in `configmap-nginx.yaml`:

```yaml
# default.conf in ConfigMap
server {
  listen 80;
  server_name _;
  
  root /usr/share/nginx/html;
  index index.html index.htm;
  
  # Security Headers
  add_header X-Content-Type-Options "nosniff" always;
  add_header X-Frame-Options "DENY" always;
  add_header X-XSS-Protection "1; mode=block" always;
  add_header Referrer-Policy "strict-origin-when-cross-origin" always;
  
  client_max_body_size 1m;
  
  # Cache Control
  location = /index.html {
    add_header Cache-Control "no-store, no-cache, must-revalidate" always;
  }
  
  location ~* \.(?:js|css|ico|gif|jpe?g|png|svg|woff2?|ttf|eot)$ {
    add_header Cache-Control "public, max-age=31536000, immutable" always;
  }
  
  # SPA Fallback
  location / {
    try_files $uri $uri/ /index.html;
  }
  
  # API Proxy (if enabled)
  location /api {
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    proxy_pass http://flask-app:8000;
  }
}
```

---

## Environment-Specific Overrides

### Staging (`values.stage.yaml`)

| Key | Value | Purpose |
|-----|-------|---------|
| `image.tag` | `stage-1` | Staging image |
| `ingress.enabled` | `true` | Enable routing |
| `ingress.hosts[0].host` | `api-staging.example.internal` | Staging domain |
| `db.auth.database` | `flask_staging` | Staging database |
| `resources.limits.memory` | `512Mi` | Staging limits |
| `externalSecrets.databaseUrlKey` | `staging/backend/database-url` | Staging secrets |

### Production (`values.prod.yaml` - reference only)

| Key | Value | Purpose |
|-----|-------|---------|
| `image.tag` | `stable-1` | Production image |
| `replicaCount` | `3` | High availability |
| `ingress.hosts[0].host` | `api.example.com` | Production domain |
| `db.auth.database` | `flask_prod` | Production database |
| `resources.limits.memory` | `1Gi` | Production limits |
| `externalSecrets.databaseUrlKey` | `prod/backend/database-url` | Prod secrets |
| `autoscaling.enabled` | `true` | Enable HPA |
| `autoscaling.maxReplicas` | `10` | Production scaling |

---

## Secret Management

### External Secrets from AWS Secrets Manager

**Backend Secrets:**

```json
{
  "name": "staging/backend/database-url",
  "value": "mysql://flask_user:password@flask-app-db:3306/flask_staging"
}

{
  "name": "staging/backend/flask-key",
  "value": "your-secret-app-key"
}
```

**Frontend Secrets:**

Currently frontend doesn't require external secrets (stateless service).

### Kubernetes Secrets

**JWT Keys Secret (must be pre-created):**

```bash
kubectl create secret generic backend-jwt-keys \
  --from-file=JWT_PRIVATE_KEY=private.pem \
  --from-file=JWT_PUBLIC_KEY=public.pem \
  -n backend
```

---

## Database Connection String Format

```
mysql://[USER]:[PASSWORD]@[HOST]:[PORT]/[DATABASE]

Example:
mysql://flask_user:mypassword@flask-app-db:3306/flask_staging
```

---

## Common Configuration Patterns

### Enable HTTPS/TLS

```yaml
# In values.yaml or values.stage.yaml
ingress:
  enabled: true
  tls:
    - secretName: frontend-tls
      hosts:
        - frontend-staging.example.internal

# For API Ingress
# In flask-app values.stage.yaml
ingress:
  enabled: true
  tls:
    - secretName: backend-tls
      hosts:
        - api-staging.example.internal
```

### Increase Resource Limits

```yaml
resources:
  requests:
    cpu: 500m
    memory: 512Mi
  limits:
    cpu: 2000m
    memory: 2Gi
```

### Enable Auto-Scaling

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

### External Database

To use an external database (not Bitnami MySQL):

```yaml
db:
  enabled: false  # Don't deploy MySQL

secrets:
  DB_HOST: "external-mysql.example.com"
  DB_PORT: "3306"
  DB_USER: "app_user"
  DB_PASSWORD: "external-password"
  DB_NAME: "production_db"
```

---

## Validation

To validate configuration before deployment:

```bash
# Lint charts
helm lint helm-charts/flask-app/
helm lint helm-charts/nginx-front/

# Template rendering
helm template flask-backend \
  helm-charts/flask-app/ \
  -f helm-charts/flask-app/values.yaml \
  -f helm-charts/flask-app/values.stage.yaml

# Dry-run install
helm install flask-backend \
  helm-charts/flask-app/ \
  -n backend \
  --create-namespace \
  --dry-run \
  --debug
```

---

**Last Updated:** 2025-11-17  
**Version:** 1.0
