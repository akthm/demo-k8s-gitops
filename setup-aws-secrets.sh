#!/bin/bash
# setup-aws-secrets.sh - Create all AWS Secrets Manager secrets for Flask backend
# Usage: ./setup-aws-secrets.sh [staging|prod]

set -e

ENV="${1:-staging}"
REGION="${2:-ap-south-1}"

if [[ "$ENV" != "staging" && "$ENV" != "prod" ]]; then
  echo "❌ Invalid environment. Use 'staging' or 'prod'"
  exit 1
fi

echo "🔐 Creating AWS Secrets Manager secrets for [$ENV] environment in region [$REGION]..."
echo ""

# Check required tools
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI not found. Install it first."; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "❌ OpenSSL not found. Install it first."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "❌ jq not found. Install it first."; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "❌ Python3 not found. Install it first."; exit 1; }

# Confirm before proceeding
read -p "This will create 4 secrets in AWS Secrets Manager. Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# 1. Database Credentials
echo "📊 Creating database credentials secret..."
DB_NAME="flask_staging"
if [[ "$ENV" == "prod" ]]; then
  DB_NAME="flask_production"
fi

aws secretsmanager create-secret \
  --name "$ENV/backend/database" \
  --description "MySQL database credentials for Flask backend ($ENV)" \
  --secret-string "{
    \"DB_USER\": \"flask_user\",
    \"DB_PASSWORD\": \"CHANGE_ME_$(openssl rand -hex 16)\",
    \"DB_HOST\": \"flask-app-db.backend.svc.cluster.local\",
    \"DB_PORT\": \"3306\",
    \"DB_NAME\": \"$DB_NAME\"
  }" \
  --region "$REGION" \
  --tags Key=Environment,Value="$ENV" Key=Application,Value=flask-backend

echo "✅ Database secret created: $ENV/backend/database"

# 2. Flask Application Secrets
echo "🔑 Creating Flask application secrets..."
FLASK_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
API_KEY=$(python3 -c "import secrets; print(secrets.token_hex(16))")

aws secretsmanager create-secret \
  --name "$ENV/backend/flask-app" \
  --description "Flask application secrets ($ENV)" \
  --secret-string "{
    \"SECRET_KEY\": \"$FLASK_SECRET\",
    \"API_TEST_KEY\": \"$API_KEY\"
  }" \
  --region "$REGION" \
  --tags Key=Environment,Value="$ENV" Key=Application,Value=flask-backend

echo "✅ Flask app secret created: $ENV/backend/flask-app"

# 3. Admin User Credentials
echo "👤 Creating admin user credentials..."
ADMIN_EMAIL="admin@example.com"
if [[ "$ENV" == "prod" ]]; then
  ADMIN_EMAIL="admin@production.com"
fi

aws secretsmanager create-secret \
  --name "$ENV/backend/admin" \
  --description "Initial admin user credentials ($ENV)" \
  --secret-string "{
    \"INITIAL_ADMIN_USER\": \"{\\\"username\\\": \\\"admin\\\", \\\"password\\\": \\\"CHANGE_ME_$(openssl rand -hex 12)\\\", \\\"email\\\": \\\"$ADMIN_EMAIL\\\"}\"
  }" \
  --region "$REGION" \
  --tags Key=Environment,Value="$ENV" Key=Application,Value=flask-backend

echo "✅ Admin secret created: $ENV/backend/admin"

# 4. JWT RSA Keys
echo "🔐 Generating JWT RSA key pair..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

openssl genrsa -out private.pem 2048 2>/dev/null
openssl rsa -in private.pem -pubout -out public.pem 2>/dev/null

JWT_PRIVATE=$(cat private.pem)
JWT_PUBLIC=$(cat public.pem)

aws secretsmanager create-secret \
  --name "$ENV/backend/jwt-keys" \
  --description "JWT RSA key pair for token signing ($ENV)" \
  --secret-string "$(jq -n \
    --arg private "$JWT_PRIVATE" \
    --arg public "$JWT_PUBLIC" \
    '{JWT_PRIVATE_KEY: $private, JWT_PUBLIC_KEY: $public}')" \
  --region "$REGION" \
  --tags Key=Environment,Value="$ENV" Key=Application,Value=flask-backend

# Securely delete temporary key files
shred -u private.pem public.pem
cd - >/dev/null
rm -rf "$TEMP_DIR"

echo "✅ JWT keys secret created: $ENV/backend/jwt-keys"
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All secrets created successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Created secrets:"
echo "  1. $ENV/backend/database"
echo "  2. $ENV/backend/flask-app"
echo "  3. $ENV/backend/admin"
echo "  4. $ENV/backend/jwt-keys"
echo ""
echo "⚠️  IMPORTANT NEXT STEPS:"
echo "  1. Update database password in: $ENV/backend/database"
echo "  2. Update admin password in: $ENV/backend/admin"
echo "  3. Configure External Secrets Operator with proper IAM role"
echo "  4. Update values.stage.yaml or values.prod.yaml to enable externalSecrets"
echo ""
echo "📚 View secrets:"
echo "  aws secretsmanager list-secrets --filters Key=name,Values=$ENV/backend --region $REGION"
echo ""
echo "🔍 Verify a secret:"
echo "  aws secretsmanager get-secret-value --secret-id $ENV/backend/database --region $REGION"
echo ""
