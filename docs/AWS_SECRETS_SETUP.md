# AWS Secrets Manager Setup Guide

## Required Secrets for Backend Flask Application

This guide covers creating all necessary secrets in AWS Secrets Manager for the Flask backend application.

---

## Prerequisites

- AWS CLI installed and configured
- Appropriate IAM permissions to create secrets
- Region: `ap-south-1` (or your target region)

---

## 1. Database Credentials

**Secret Name:** `staging/backend/database`

```bash
aws secretsmanager create-secret \
  --name staging/backend/database \
  --description "MySQL database credentials for Flask backend (staging)" \
  --secret-string '{
    "DB_USER": "flask_user",
    "DB_PASSWORD": "CHANGE_ME_SECURE_PASSWORD",
    "DB_HOST": "flask-app-db.backend.svc.cluster.local",
    "DB_PORT": "3306",
    "DB_NAME": "flask_staging"
  }' \
  --region ap-south-1
```

**Production:**
```bash
aws secretsmanager create-secret \
  --name prod/backend/database \
  --secret-string '{
    "DB_USER": "flask_user",
    "DB_PASSWORD": "PRODUCTION_SECURE_PASSWORD",
    "DB_HOST": "flask-app-db.backend.svc.cluster.local",
    "DB_PORT": "3306",
    "DB_NAME": "flask_production"
  }' \
  --region ap-south-1
```

---

## 2. Flask Application Secrets

**Secret Name:** `staging/backend/flask-app`

```bash
# Generate a secure secret key
FLASK_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
API_TEST_KEY=$(python3 -c "import secrets; print(secrets.token_hex(16))")

aws secretsmanager create-secret \
  --name staging/backend/flask-app \
  --description "Flask application secrets (staging)" \
  --secret-string "{
    \"SECRET_KEY\": \"$FLASK_SECRET\",
    \"API_TEST_KEY\": \"$API_TEST_KEY\"
  }" \
  --region ap-south-1
```

**Production:**
```bash
FLASK_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
API_TEST_KEY=$(python3 -c "import secrets; print(secrets.token_hex(16))")

aws secretsmanager create-secret \
  --name prod/backend/flask-app \
  --secret-string "{
    \"SECRET_KEY\": \"$FLASK_SECRET\",
    \"API_TEST_KEY\": \"$API_TEST_KEY\"
  }" \
  --region ap-south-1
```

---

## 3. Admin User Credentials

**Secret Name:** `staging/backend/admin`

```bash
aws secretsmanager create-secret \
  --name staging/backend/admin \
  --description "Initial admin user credentials (staging)" \
  --secret-string '{
    "INITIAL_ADMIN_USER": "{\"username\": \"admin\", \"password\": \"CHANGE_ME_ADMIN_PASSWORD\", \"email\": \"admin@example.com\"}"
  }' \
  --region ap-south-1
```

**Production:**
```bash
aws secretsmanager create-secret \
  --name prod/backend/admin \
  --secret-string '{
    "INITIAL_ADMIN_USER": "{\"username\": \"admin\", \"password\": \"PRODUCTION_ADMIN_PASSWORD\", \"email\": \"admin@production.com\"}"
  }' \
  --region ap-south-1
```

---

## 4. JWT RSA Key Pair (NEW)

**Secret Name:** `staging/backend/jwt-keys`

### Generate RSA Keys

```bash
# 1. Generate RSA private key (2048-bit)
openssl genrsa -out private.pem 2048

# 2. Extract public key
openssl rsa -in private.pem -pubout -out public.pem

# 3. Read keys into variables (preserving newlines)
JWT_PRIVATE_KEY=$(cat private.pem)
JWT_PUBLIC_KEY=$(cat public.pem)

# 4. Create AWS secret with proper JSON formatting
aws secretsmanager create-secret \
  --name staging/backend/jwt-keys \
  --description "JWT RSA key pair for token signing (staging)" \
  --secret-string "$(jq -n \
    --arg private "$JWT_PRIVATE_KEY" \
    --arg public "$JWT_PUBLIC_KEY" \
    '{JWT_PRIVATE_KEY: $private, JWT_PUBLIC_KEY: $public}')" \
  --region ap-south-1

# 5. Securely delete local key files
shred -u private.pem public.pem

echo "✅ JWT keys created and local files securely deleted"
```

**Production:**
```bash
# Generate separate keys for production
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -pubout -out public.pem

JWT_PRIVATE_KEY=$(cat private.pem)
JWT_PUBLIC_KEY=$(cat public.pem)

aws secretsmanager create-secret \
  --name prod/backend/jwt-keys \
  --description "JWT RSA key pair for token signing (production)" \
  --secret-string "$(jq -n \
    --arg private "$JWT_PRIVATE_KEY" \
    --arg public "$JWT_PUBLIC_KEY" \
    '{JWT_PRIVATE_KEY: $private, JWT_PUBLIC_KEY: $public}')" \
  --region ap-south-1

shred -u private.pem public.pem
```

### Verify JWT Keys Secret

```bash
# Retrieve and verify the secret structure
aws secretsmanager get-secret-value \
  --secret-id staging/backend/jwt-keys \
  --region ap-south-1 \
  --query 'SecretString' \
  --output text | jq 'keys'

# Should output: ["JWT_PRIVATE_KEY", "JWT_PUBLIC_KEY"]
```

---

## 5. Verify All Secrets

```bash
# List all backend secrets
aws secretsmanager list-secrets \
  --filters Key=name,Values=staging/backend \
  --region ap-south-1 \
  --query 'SecretList[].Name' \
  --output table

# Expected output:
# ---------------------------------
# |         ListSecrets           |
# +-------------------------------+
# |  staging/backend/admin        |
# |  staging/backend/database     |
# |  staging/backend/flask-app    |
# |  staging/backend/jwt-keys     |
# +-------------------------------+
```

---

## 6. Update Helm Values

Ensure your `values.stage.yaml` has the correct secret keys:

```yaml
externalSecrets:
  enabled: true
  secretStoreRef:
    name: "aws-secrets-manager"
    kind: "ClusterSecretStore"
  databaseKey: "staging/backend/database"
  flaskAppKey: "staging/backend/flask-app"
  adminKey: "staging/backend/admin"
  jwtKeysKey: "staging/backend/jwt-keys"

jwt:
  enabled: true
  existingSecret: "flask-app-jwt-keys"  # Created by ExternalSecret
```

---

## 7. IAM Permissions Required

The External Secrets Operator service account needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:ap-south-1:ACCOUNT_ID:secret:staging/backend/*",
        "arn:aws:secretsmanager:ap-south-1:ACCOUNT_ID:secret:prod/backend/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "secretsmanager:ListSecrets",
      "Resource": "*"
    }
  ]
}
```

---

## 8. Secret Rotation (Optional)

### Enable Automatic Rotation for Database Password

```bash
# This requires a Lambda function to handle rotation
aws secretsmanager rotate-secret \
  --secret-id staging/backend/database \
  --rotation-rules AutomaticallyAfterDays=30 \
  --rotation-lambda-arn arn:aws:lambda:ap-south-1:ACCOUNT_ID:function:SecretsManagerRotation \
  --region ap-south-1
```

### Manual JWT Key Rotation

```bash
# Generate new keys
openssl genrsa -out private_new.pem 2048
openssl rsa -in private_new.pem -pubout -out public_new.pem

JWT_PRIVATE_KEY=$(cat private_new.pem)
JWT_PUBLIC_KEY=$(cat public_new.pem)

# Update the secret
aws secretsmanager update-secret \
  --secret-id staging/backend/jwt-keys \
  --secret-string "$(jq -n \
    --arg private "$JWT_PRIVATE_KEY" \
    --arg public "$JWT_PUBLIC_KEY" \
    '{JWT_PRIVATE_KEY: $private, JWT_PUBLIC_KEY: $public}')" \
  --region ap-south-1

shred -u private_new.pem public_new.pem

# External Secrets Operator will sync the new keys within refreshInterval (1h)
```

---

## 9. Troubleshooting

### Secret Not Syncing

```bash
# Check ExternalSecret status
kubectl describe externalsecret flask-app-jwt-keys -n backend

# Check External Secrets Operator logs
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets --tail=50

# Verify SecretStore is valid
kubectl describe secretstore aws-secrets-manager -n backend
```

### Test Secret Access from Pod

```bash
# Run a debug pod with the service account
kubectl run -it --rm debug \
  --image=amazon/aws-cli \
  --serviceaccount=flask-app \
  --namespace=backend \
  -- secretsmanager get-secret-value \
     --secret-id staging/backend/jwt-keys \
     --region ap-south-1
```

---

## 10. Security Best Practices

1. ✅ **Never commit secrets to Git**
2. ✅ **Use different secrets for staging/production**
3. ✅ **Enable CloudTrail logging for secret access**
4. ✅ **Rotate secrets regularly** (database: 30-90 days, JWT keys: 90-180 days)
5. ✅ **Use least-privilege IAM policies**
6. ✅ **Enable secret versioning in AWS Secrets Manager**
7. ✅ **Monitor ExternalSecret sync failures**
8. ✅ **Audit secret access with CloudWatch**

---

## Quick Setup Script

```bash
#!/bin/bash
# setup-aws-secrets.sh - Create all AWS secrets for staging

set -e

REGION="ap-south-1"
ENV="staging"

echo "🔐 Creating AWS Secrets Manager secrets for $ENV environment..."

# 1. Database
aws secretsmanager create-secret \
  --name $ENV/backend/database \
  --secret-string '{
    "DB_USER": "flask_user",
    "DB_PASSWORD": "CHANGE_ME",
    "DB_HOST": "flask-app-db.backend.svc.cluster.local",
    "DB_PORT": "3306",
    "DB_NAME": "flask_staging"
  }' \
  --region $REGION

# 2. Flask App
FLASK_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
API_KEY=$(python3 -c "import secrets; print(secrets.token_hex(16))")

aws secretsmanager create-secret \
  --name $ENV/backend/flask-app \
  --secret-string "{
    \"SECRET_KEY\": \"$FLASK_SECRET\",
    \"API_TEST_KEY\": \"$API_KEY\"
  }" \
  --region $REGION

# 3. Admin
aws secretsmanager create-secret \
  --name $ENV/backend/admin \
  --secret-string '{
    "INITIAL_ADMIN_USER": "{\"username\": \"admin\", \"password\": \"CHANGE_ME\", \"email\": \"admin@example.com\"}"
  }' \
  --region $REGION

# 4. JWT Keys
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -pubout -out public.pem

JWT_PRIVATE=$(cat private.pem)
JWT_PUBLIC=$(cat public.pem)

aws secretsmanager create-secret \
  --name $ENV/backend/jwt-keys \
  --secret-string "$(jq -n \
    --arg private "$JWT_PRIVATE" \
    --arg public "$JWT_PUBLIC" \
    '{JWT_PRIVATE_KEY: $private, JWT_PUBLIC_KEY: $public}')" \
  --region $REGION

shred -u private.pem public.pem

echo "✅ All secrets created successfully!"
echo "⚠️  Remember to update passwords in AWS Secrets Manager console"
```

Save this as `setup-aws-secrets.sh`, make it executable with `chmod +x setup-aws-secrets.sh`, and run it.

---

**For more information:**
- [External Secrets Operator Documentation](https://external-secrets.io)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
