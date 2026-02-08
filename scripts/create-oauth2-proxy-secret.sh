#!/bin/bash
set -e

# Script to create OAuth2-Proxy secret manually
# Use this as a temporary workaround until OCI Vault secret is properly configured

NAMESPACE="platform"
SECRET_NAME="platform-app-oauth2-proxy"

echo "=== Creating OAuth2-Proxy Secret ==="

# Get Keycloak client secret (you need to provide this)
read -p "Enter the Keycloak client secret for 'platform-bff' client: " CLIENT_SECRET

# Generate a random cookie secret (32 bytes, base64 encoded)
COOKIE_SECRET=$(python3 -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode().rstrip("="))')

echo "Generated cookie secret: $COOKIE_SECRET"

# Create the secret
kubectl create secret generic "$SECRET_NAME" \
  -n "$NAMESPACE" \
  --from-literal=client-secret="$CLIENT_SECRET" \
  --from-literal=cookie-secret="$COOKIE_SECRET" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=== Secret Created Successfully ==="
echo ""
echo "Secret name: $SECRET_NAME"
echo "Namespace: $NAMESPACE"
echo ""
echo "Next steps:"
echo "1. Restart OAuth2-Proxy pods:"
echo "   kubectl rollout restart deployment -n $NAMESPACE -l app.kubernetes.io/name=oauth2-proxy"
echo ""
echo "2. Add these values to OCI Vault secret 'platform-bff':"
echo "   client-secret: $CLIENT_SECRET"
echo "   cookie-secret: $COOKIE_SECRET"
echo ""
echo "3. Once OCI Vault is configured, delete this manual secret:"
echo "   kubectl delete secret $SECRET_NAME -n $NAMESPACE"
