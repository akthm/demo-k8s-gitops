#!/bin/bash
# ==============================================================================
# Configure ArgoCD with Keycloak SSO
# ==============================================================================
# This script configures ArgoCD to use Keycloak as an OIDC provider for SSO
#
# Prerequisites:
#   - kubectl access to the cluster
#   - ArgoCD installed in 'argocd' namespace
#   - Keycloak running and accessible
#   - A client created in Keycloak for ArgoCD
#
# Usage:
#   ./configure-argocd-keycloak-sso.sh
# ==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_NAMESPACE="argocd"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://keycloak.adaas-il.com}"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-master}"
ARGOCD_URL="${ARGOCD_URL:-https://argocd.adaas-il.com}"
CLIENT_ID="${CLIENT_ID:-argocd}"

echo -e "${BLUE}==================================================================${NC}"
echo -e "${BLUE}ArgoCD Keycloak SSO Configuration${NC}"
echo -e "${BLUE}==================================================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Keycloak URL:    $KEYCLOAK_URL"
echo "  Keycloak Realm:  $KEYCLOAK_REALM"
echo "  ArgoCD URL:      $ARGOCD_URL"
echo "  Client ID:       $CLIENT_ID"
echo ""

# Check if ArgoCD is running
echo -e "${BLUE}[1/5] Checking ArgoCD installation...${NC}"
if ! kubectl get namespace $ARGOCD_NAMESPACE &>/dev/null; then
    echo -e "${RED}Error: ArgoCD namespace '$ARGOCD_NAMESPACE' not found${NC}"
    exit 1
fi

if ! kubectl get deployment argocd-server -n $ARGOCD_NAMESPACE &>/dev/null; then
    echo -e "${RED}Error: ArgoCD server not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ ArgoCD is installed${NC}"
echo ""

# Prompt for client secret
echo -e "${BLUE}[2/5] Getting Keycloak client secret...${NC}"
echo -e "${YELLOW}Please enter the Keycloak client secret for '$CLIENT_ID':${NC}"
read -s CLIENT_SECRET
echo ""

if [ -z "$CLIENT_SECRET" ]; then
    echo -e "${RED}Error: Client secret cannot be empty${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Client secret received${NC}"
echo ""

# Update argocd-secret with OIDC client secret
echo -e "${BLUE}[3/5] Updating ArgoCD secret with OIDC client secret...${NC}"
kubectl patch secret argocd-secret -n $ARGOCD_NAMESPACE --type merge -p "{
  \"stringData\": {
    \"oidc.keycloak.clientSecret\": \"$CLIENT_SECRET\"
  }
}"
echo -e "${GREEN}✓ Secret updated${NC}"
echo ""

# Configure ArgoCD ConfigMap for OIDC
echo -e "${BLUE}[4/5] Configuring ArgoCD OIDC settings...${NC}"

OIDC_CONFIG=$(cat <<EOF
url: $ARGOCD_URL
oidc.config: |
  name: Keycloak
  issuer: $KEYCLOAK_URL/realms/$KEYCLOAK_REALM
  clientID: $CLIENT_ID
  clientSecret: \$oidc.keycloak.clientSecret
  requestedScopes:
    - openid
    - profile
    - email
    - groups
  requestedIDTokenClaims:
    groups:
      essential: true
EOF
)

# Get current argocd-cm
kubectl get configmap argocd-cm -n $ARGOCD_NAMESPACE -o yaml > /tmp/argocd-cm-backup.yaml

# Update the configmap
kubectl patch configmap argocd-cm -n $ARGOCD_NAMESPACE --type merge -p "
data:
  url: \"$ARGOCD_URL\"
  oidc.config: |
    name: Keycloak
    issuer: $KEYCLOAK_URL/realms/$KEYCLOAK_REALM
    clientID: $CLIENT_ID
    clientSecret: \$oidc.keycloak.clientSecret
    requestedScopes:
      - openid
      - profile
      - email
      - groups
    requestedIDTokenClaims:
      groups:
        essential: true
"

echo -e "${GREEN}✓ OIDC configuration updated${NC}"
echo ""

# Configure RBAC (optional but recommended)
echo -e "${BLUE}[5/5] Configuring ArgoCD RBAC...${NC}"

# Default RBAC policy - adjust as needed
RBAC_POLICY=$(cat <<'EOF'
# Default policy: role:readonly for authenticated users
g, authenticated, role:readonly

# Admin group gets admin access
g, argocd-admins, role:admin

# Allow SSO users from specific groups
# Uncomment and adjust based on your Keycloak groups:
# g, platform-developers, role:admin
# g, platform-operators, role:readonly
EOF
)

kubectl patch configmap argocd-rbac-cm -n $ARGOCD_NAMESPACE --type merge -p "
data:
  policy.csv: |
    # Default policy: role:readonly for authenticated users
    g, authenticated, role:readonly

    # Admin group gets admin access
    g, argocd-admins, role:admin

    # Allow SSO users from specific groups
    # Uncomment and adjust based on your Keycloak groups:
    # g, platform-developers, role:admin
    # g, platform-operators, role:readonly
  policy.default: role:readonly
  scopes: '[groups, email]'
"

echo -e "${GREEN}✓ RBAC configuration updated${NC}"
echo ""

# Restart ArgoCD server to apply changes
echo -e "${BLUE}Restarting ArgoCD server to apply changes...${NC}"
kubectl rollout restart deployment argocd-server -n $ARGOCD_NAMESPACE
kubectl rollout status deployment argocd-server -n $ARGOCD_NAMESPACE --timeout=120s

echo ""
echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}✓ ArgoCD Keycloak SSO configuration completed successfully!${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Ensure your Keycloak client '$CLIENT_ID' is configured with:"
echo "   - Client Protocol: openid-connect"
echo "   - Access Type: confidential"
echo "   - Valid Redirect URIs: $ARGOCD_URL/*"
echo "   - Base URL: $ARGOCD_URL"
echo ""
echo "2. Configure group mappings in Keycloak (optional):"
echo "   - Add 'groups' mapper to the client"
echo "   - Token Claim Name: groups"
echo "   - Full group path: OFF"
echo ""
echo "3. Access ArgoCD at: $ARGOCD_URL"
echo "   - Click 'LOG IN VIA KEYCLOAK'"
echo "   - Authenticate with your Keycloak credentials"
echo ""
echo "4. To customize RBAC, edit the argocd-rbac-cm ConfigMap:"
echo "   kubectl edit configmap argocd-rbac-cm -n $ARGOCD_NAMESPACE"
echo ""
echo -e "${YELLOW}Backup of original argocd-cm saved to: /tmp/argocd-cm-backup.yaml${NC}"
echo ""
