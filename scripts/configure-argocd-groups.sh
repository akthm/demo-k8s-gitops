#!/bin/bash
set -e

# Script to configure ArgoCD client in Keycloak with proper group mappers

NAMESPACE="keycloak"
SERVICE="keycloak"
REALM="master"
CLIENT_ID="argocd"

echo "=== Configuring ArgoCD Client Groups Mapper in Keycloak ==="

# Get admin password
ADMIN_PASSWORD=$(kubectl get secret keycloak-admin-credentials -n $NAMESPACE -o jsonpath='{.data.admin-password}' | base64 -d)

# Port forward to Keycloak
echo "Setting up port forward to Keycloak..."
kubectl port-forward -n $NAMESPACE svc/$SERVICE 8080:80 >/dev/null 2>&1 &
PORT_FORWARD_PID=$!
trap "kill $PORT_FORWARD_PID 2>/dev/null || true" EXIT

sleep 3

# Get admin token
echo "Getting admin token..."
TOKEN=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=$ADMIN_PASSWORD" \
  -d "grant_type=password" | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
  echo "Error: Failed to get admin token"
  exit 1
fi

echo "Token obtained successfully"

# Get ArgoCD client UUID
echo "Getting ArgoCD client UUID..."
CLIENT_UUID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8080/admin/realms/$REALM/clients?clientId=$CLIENT_ID" | jq -r '.[0].id')

if [ "$CLIENT_UUID" == "null" ] || [ -z "$CLIENT_UUID" ]; then
  echo "Error: ArgoCD client not found in Keycloak"
  exit 1
fi

echo "ArgoCD client UUID: $CLIENT_UUID"

# Check if groups mapper exists
echo "Checking for existing groups mapper..."
EXISTING_MAPPER=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8080/admin/realms/$REALM/clients/$CLIENT_UUID/protocol-mappers/models" \
  | jq -r '.[] | select(.name == "groups") | .id')

if [ -n "$EXISTING_MAPPER" ] && [ "$EXISTING_MAPPER" != "null" ]; then
  echo "Groups mapper already exists with ID: $EXISTING_MAPPER"
  echo "Updating existing mapper..."
  
  curl -s -X PUT -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "http://localhost:8080/admin/realms/$REALM/clients/$CLIENT_UUID/protocol-mappers/models/$EXISTING_MAPPER" \
    -d '{
      "id": "'"$EXISTING_MAPPER"'",
      "name": "groups",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-group-membership-mapper",
      "consentRequired": false,
      "config": {
        "full.path": "false",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "userinfo.token.claim": "true",
        "claim.name": "groups"
      }
    }'
  
  echo "Groups mapper updated successfully"
else
  echo "Creating new groups mapper..."
  
  curl -s -X POST -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "http://localhost:8080/admin/realms/$REALM/clients/$CLIENT_UUID/protocol-mappers/models" \
    -d '{
      "name": "groups",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-group-membership-mapper",
      "consentRequired": false,
      "config": {
        "full.path": "false",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "userinfo.token.claim": "true",
        "claim.name": "groups"
      }
    }'
  
  echo "Groups mapper created successfully"
fi

# Verify the mapper
echo ""
echo "Verifying groups mapper configuration..."
curl -s -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8080/admin/realms/$REALM/clients/$CLIENT_UUID/protocol-mappers/models" \
  | jq '.[] | select(.name == "groups")'

echo ""
echo "=== Configuration Complete ==="
echo ""
echo "The ArgoCD client now has a groups mapper configured."
echo "Make sure your user is assigned to the 'platform-developers' group in Keycloak."
echo ""
echo "To test:"
echo "1. Logout from ArgoCD"
echo "2. Login again via Keycloak SSO"
echo "3. Your user should now have admin access"
