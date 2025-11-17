#!/bin/bash
# Setup script for staging environment secrets and prerequisites

set -e

NAMESPACE_BACKEND="backend"
NAMESPACE_FRONTEND="frontend"

echo "Setting up staging environment..."

# Create namespaces
kubectl create namespace ${NAMESPACE_BACKEND} --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ${NAMESPACE_FRONTEND} --dry-run=client -o yaml | kubectl apply -f -

# Label namespaces for network policies
kubectl label namespace ${NAMESPACE_BACKEND} name=backend --overwrite
kubectl label namespace ${NAMESPACE_FRONTEND} name=frontend --overwrite

# Create ArgoCD namespace if needed
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace argocd name=argocd --overwrite

echo "Creating JWT keys secret (if using RS256)..."
# Generate RSA keys for JWT (if not already present)
if [ ! -f jwt-private.key ] || [ ! -f jwt-public.key ]; then
    openssl genrsa -out jwt-private.key 2048
    openssl rsa -in jwt-private.key -pubout -out jwt-public.key
fi

kubectl create secret generic backend-jwt-keys \
  --from-file=JWT_PRIVATE_KEY=jwt-private.key \
  --from-file=JWT_PUBLIC_KEY=jwt-public.key \
  -n ${NAMESPACE_BACKEND} \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Creating external secrets store reference (AWS Secrets Manager)..."
# NOTE: This requires external-secrets-operator to be installed
# Install with: helm repo add external-secrets https://charts.external-secrets.io
# helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace

# Create a ClusterSecretStore that references AWS Secrets Manager
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-south-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets-system
EOF

echo "✓ Setup complete!"
echo ""
echo "NEXT STEPS:"
echo "1. Update values with your repository URL"
echo "2. Configure AWS credentials for External Secrets"
echo "3. Create secrets in AWS Secrets Manager:"
echo "   - staging/backend/database-url"
echo "   - staging/backend/flask-key"
echo "4. Deploy with ArgoCD"
