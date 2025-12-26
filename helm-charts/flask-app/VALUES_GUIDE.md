# Flask App Helm Chart - Values Configuration Guide

## Overview

This chart follows Helm best practices for configuration management:
- All environment-specific values are in separate files (`values.yaml`, `values.stage.yaml`, `values.prod.yaml`)
- No hard-coded values in templates
- Secrets are managed via External Secrets Operator
- Database credentials are centralized and configurable

## Configuration Hierarchy

```
values.yaml (base defaults)
  └── values.stage.yaml (staging overrides)
  └── values.prod.yaml (production overrides)
```

## Key Configuration Sections

### 1. Secret Names (`secretNames`)

All Kubernetes Secret names are configurable for flexibility:

```yaml
secretNames:
  database: "flask-app-db"                    # MySQL password secret
  databaseCredentials: "flask-app-db-credentials"  # DB connection details from External Secrets
  flaskSecret: "flask-app-secret"            # Flask SECRET_KEY, etc.
  adminCredentials: "flask-app-admin-credentials"  # Initial admin user
```

**Used by**: Deployment envFrom, RBAC, External Secrets targets

### 2. Database Configuration (`db`)

Database settings are split between chart values and External Secrets:

```yaml
db:
  auth:
    existingSecret: "flask-app-db"  # Must match secretNames.database
    database: flask_db              # Database name
    username: flask_user            # Database username
```

**Important**: 
- `database` and `username` must match values in AWS Secrets Manager
- The password comes from External Secrets, not from values files
- Bitnami MySQL subchart uses `db.auth.*` for initialization

### 3. External Secrets (`externalSecrets`)

Maps AWS Secrets Manager keys to Kubernetes Secrets:

```yaml
externalSecrets:
  enabled: true  # Set to false for local dev without AWS
  secretStoreRef:
    name: "aws-secrets-manager"
    kind: "ClusterSecretStore"
  
  # AWS Secrets Manager paths
  databaseKey: "staging/backend/database"    # Contains: DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, DB_NAME
  flaskAppKey: "staging/backend/flask-app"   # Contains: SECRET_KEY, etc.
  adminKey: "staging/backend/admin"          # Contains: INITIAL_ADMIN_USER (JSON)
  jwtKeysKey: "staging/backend/jwt-keys"     # Contains: JWT_PRIVATE_KEY, JWT_PUBLIC_KEY
```

**AWS Secrets Structure**:

```json
// staging/backend/database
{
  "DB_USER": "flask_user",
  "DB_PASSWORD": "secure_password",
  "DB_HOST": "flask-app-db.backend.svc.cluster.local",
  "DB_PORT": "3306",
  "DB_NAME": "flask_staging"
}

// staging/backend/admin
{
  "INITIAL_ADMIN_USERNAME": "admin",
  "INITIAL_ADMIN_PASSWORD": "admin123",
  "INITIAL_ADMIN_EMAIL": "admin@example.com"
}
```

### 4. Application Config (`config`)

Non-sensitive configuration exposed as environment variables:

```yaml
config:
  DEBUG: "0"
  ENVIRONMENT: "staging"
  DB_TYPE: "mysql"
  DB_HOST: "flask-app-db"  # Service name
  DB_PORT: "3306"
  # DB_NAME and DB_USER come from secrets
```

**Note**: Database credentials (DB_NAME, DB_USER, DB_PASSWORD) come from External Secrets, not from `config`.

### 5. JWT Configuration (`jwt`)

JWT signing configuration:

```yaml
jwt:
  enabled: true
  algorithm: RS256
  issuer: "my-backend"
  audience: "my-frontend"
  existingSecret: "flask-app-jwt-keys"  # Created by External Secrets
  privateKeyKey: "JWT_PRIVATE_KEY"
  publicKeyKey: "JWT_PUBLIC_KEY"
```

## Environment-Specific Overrides

### Staging (`values.stage.yaml`)

```yaml
# Override database name for staging
db:
  auth:
    database: "flask_staging"

# Override External Secrets paths
externalSecrets:
  enabled: true
  databaseKey: "staging/backend/database"

# Override config
config:
  ENVIRONMENT: "staging"
  DEBUG: "0"
```

### Production (`values.prod.yaml`)

```yaml
# Production database
db:
  auth:
    database: "flask_production"
  primary:
    persistence:
      size: 10Gi

# Production secrets
externalSecrets:
  enabled: true
  databaseKey: "production/backend/database"

# Production config
config:
  ENVIRONMENT: "production"
  DEBUG: "0"
  DB_FALLBACK_TO_SQLITE_IN_MEMORY: "false"

# Enable autoscaling
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
```

## Best Practices

### ✅ DO:
- Use `values.<env>.yaml` for environment-specific overrides
- Keep secrets in External Secrets / AWS Secrets Manager
- Use `secretNames.*` for all secret references
- Document configuration in comments
- Use meaningful default values in base `values.yaml`

### ❌ DON'T:
- Hard-code secret names in templates
- Put passwords in values files
- Duplicate configuration between files
- Mix environment-specific values in base `values.yaml`
- Hard-code namespaces or service names

## Deployment Examples

### Local Development (no External Secrets)
```bash
helm install flask-app . \
  --set externalSecrets.enabled=false \
  --set db.auth.database=flask_local
```

### Staging
```bash
helm install flask-app . \
  -f values.yaml \
  -f values.stage.yaml \
  --namespace backend
```

### Production
```bash
helm install flask-app . \
  -f values.yaml \
  -f values.prod.yaml \
  --namespace backend-prod
```

## Troubleshooting

### Database Connection Issues

**Symptom**: "Access denied for user to database"

**Cause**: Mismatch between:
- `db.auth.database` in values
- `DB_NAME` in AWS Secrets Manager
- MySQL database initialization

**Fix**: Ensure all three match:
```yaml
# values.stage.yaml
db:
  auth:
    database: "flask_staging"  # ← Must match

# AWS Secret: staging/backend/database
{
  "DB_NAME": "flask_staging"  # ← Must match
}
```

### Secret Not Found

**Symptom**: "secret not found" in pod logs

**Cause**: `secretNames.*` doesn't match External Secret target name

**Fix**: Check that External Secret `target.name` matches `secretNames.*`:
```yaml
# values.yaml
secretNames:
  databaseCredentials: "flask-app-db-credentials"

# external-secret-database.yaml
target:
  name: {{ .Values.secretNames.databaseCredentials }}  # ✅ Correct
```

## Migration from Hard-Coded Values

If you're upgrading from a version with hard-coded values:

1. **Identify hard-coded values**: Search for literals in templates
2. **Add to values.yaml**: Create appropriate sections
3. **Update templates**: Replace literals with `{{ .Values.* }}`
4. **Test**: `helm template` to verify
5. **Deploy**: Use `helm upgrade` with proper values files
