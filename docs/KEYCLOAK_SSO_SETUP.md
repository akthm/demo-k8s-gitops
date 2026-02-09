# Keycloak SSO Integration Guide

This guide covers the complete setup of Keycloak as the SSO provider for all platform components.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Keycloak (Identity Provider)                        │
│                              Realm: platform                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│  Clients:                         │  Groups:                                │
│  • flask-backend (confidential)   │  • /platform-admins → admin role       │
│  • react-frontend (public+PKCE)   │  • /developers → developer role        │
│  • argocd (confidential)          │  • /grafana-admins → Grafana Admin     │
│  • grafana (confidential)         │  • /grafana-editors → Grafana Editor   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
          ┌─────────────────────────┼─────────────────────────┐
          │                         │                         │
          ▼                         ▼                         ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────────────────┐
│  React Frontend │    │  Flask Backend  │    │  Platform Tools             │
│  (keycloak-js)  │    │  (authlib)      │    │  • ArgoCD (OIDC)            │
│                 │    │                 │    │  • Grafana (Generic OAuth)  │
│  Public client  │    │  Confidential   │    │  • Prometheus (via Grafana) │
│  PKCE flow      │    │  client         │    │                             │
└─────────────────┘    └─────────────────┘    └─────────────────────────────┘
```

## Deployment Order (Sync Waves)

1. **Wave -3**: Keycloak + PostgreSQL
2. **Wave -2**: monitoring-stack (Grafana, Prometheus)
3. **Wave 0**: flask-app, nginx-front

## Prerequisites

### AWS Secrets Manager

Create the following secrets before deployment:

```bash
# Keycloak Admin Credentials
aws secretsmanager create-secret \
  --name staging/keycloak/admin \
  --secret-string '{"admin-user":"admin","admin-password":"<secure-password>"}'

# Keycloak PostgreSQL Credentials
aws secretsmanager create-secret \
  --name staging/keycloak/postgres \
  --secret-string '{"postgres-password":"<postgres-admin-pw>","password":"<keycloak-db-pw>"}'

# Keycloak Client Secrets (update after creating clients)
aws secretsmanager create-secret \
  --name staging/keycloak/clients \
  --secret-string '{"flask-backend-secret":"<secret>","grafana-secret":"<secret>","argocd-secret":"<secret>"}'

# Flask OIDC Credentials
aws secretsmanager create-secret \
  --name staging/backend/oidc \
  --secret-string '{"OIDC_CLIENT_ID":"flask-backend","OIDC_CLIENT_SECRET":"<secret>"}'
```

## Step 1: Deploy Keycloak

### 1.1 Update Helm Dependencies

```bash
cd helm-charts/keycloak
helm dependency update
```

### 1.2 Deploy via ArgoCD

The ArgoCD Application is already configured in `apps/staging/keycloak.yaml`.

```bash
# Verify the application
kubectl get application keycloak -n argocd

# Check deployment status
kubectl get pods -n keycloak
```

### 1.3 Access Keycloak Admin Console

```bash
# Port-forward to Keycloak
kubectl port-forward svc/keycloak 8080:80 -n keycloak

# Access: http://localhost:8080
# Login with admin credentials from ExternalSecret
```

## Step 2: Configure Keycloak Realm

### 2.1 Create Platform Realm

1. Login to Keycloak Admin Console
2. Click "Create Realm"
3. Name: `platform`
4. Click "Create"

### 2.2 Create Client Scopes

#### Groups Scope
1. Go to Client Scopes → Create
2. Name: `groups`
3. Protocol: openid-connect
4. Include in token scope: ON
5. Save, then go to Mappers tab
6. Create mapper:
   - Name: `groups`
   - Mapper type: Group Membership
   - Token Claim Name: `groups`
   - Full group path: ON
   - Add to ID token: ON
   - Add to access token: ON

### 2.3 Create Clients

#### Flask Backend Client (Confidential)
```yaml
Client ID: flask-backend
Client Protocol: openid-connect
Access Type: confidential
Service Accounts Enabled: ON
Valid Redirect URIs: http://localhost:5000/*
Web Origins: *
```

#### React Frontend Client (Public with PKCE)
```yaml
Client ID: react-frontend
Client Protocol: openid-connect
Access Type: public
Standard Flow Enabled: ON
Direct Access Grants: OFF
Valid Redirect URIs: 
  - http://localhost:5173/*
  - http://localhost:3000/*
Web Origins: *
Advanced Settings:
  Proof Key for Code Exchange: S256
```

#### ArgoCD Client (Confidential)
```yaml
Client ID: argocd
Client Protocol: openid-connect
Access Type: confidential
Valid Redirect URIs: https://argocd.example.com/auth/callback
Web Origins: https://argocd.example.com
```

#### Grafana Client (Confidential)
```yaml
Client ID: grafana
Client Protocol: openid-connect
Access Type: confidential
Valid Redirect URIs: http://grafana.example.com/login/generic_oauth
Web Origins: http://grafana.example.com
```

### 2.4 Create Groups

1. Go to Groups → Create group
2. Create these groups:
   - `/platform-admins`
   - `/developers`
   - `/grafana-admins`
   - `/grafana-editors`

### 2.5 Create Users

1. Go to Users → Add user
2. Create users and assign to appropriate groups
3. Set credentials in Credentials tab

### 2.6 Update Client Secrets in AWS

After creating clients, copy the client secrets:

```bash
# Get client secrets from Keycloak Admin UI (Clients → Client → Credentials tab)
# Update AWS Secrets Manager
aws secretsmanager update-secret \
  --secret-id staging/keycloak/clients \
  --secret-string '{"flask-backend-secret":"<actual-secret>","grafana-secret":"<actual-secret>","argocd-secret":"<actual-secret>"}'

aws secretsmanager update-secret \
  --secret-id staging/backend/oidc \
  --secret-string '{"OIDC_CLIENT_ID":"flask-backend","OIDC_CLIENT_SECRET":"<actual-secret>"}'
```

## Step 3: Enable Flask OIDC

### 3.1 Update Flask values.stage.yaml

```yaml
# Add to helm-charts/flask-app/values.stage.yaml
oidc:
  enabled: true
  issuer: "http://keycloak.keycloak.svc.cluster.local/realms/platform"
  clientId: "flask-backend"
  scopes: "openid profile email groups"
  audience: "flask-backend"
  algorithms: ["RS256"]
  groupsClaim: "groups"

externalSecrets:
  enabled: true
  oidcKey: "staging/backend/oidc"
```

### 3.2 Flask Application Code

Add OIDC middleware to your Flask app:

```python
# app/auth/oidc.py
from authlib.integrations.flask_oauth2 import ResourceProtector
from authlib.oauth2.rfc7523 import JWTBearerTokenValidator
from authlib.jose import JsonWebKey
import requests
import os

class KeycloakJWTValidator(JWTBearerTokenValidator):
    def __init__(self, issuer):
        self.issuer = issuer
        # Fetch JWKS from Keycloak
        jwks_uri = f"{issuer}/protocol/openid-connect/certs"
        jwks = requests.get(jwks_uri).json()
        self.public_key = JsonWebKey.import_key_set(jwks)
        super().__init__(self.public_key)
    
    def authenticate_token(self, token_string):
        claims = self.validate_token(token_string)
        return claims

def init_oidc(app):
    if not os.environ.get('OIDC_ENABLED', 'false').lower() == 'true':
        return None
    
    issuer = os.environ.get('OIDC_ISSUER')
    require_oauth = ResourceProtector()
    validator = KeycloakJWTValidator(issuer)
    require_oauth.register_token_validator(validator)
    return require_oauth

# Usage in routes
# @require_oauth('openid')
# def protected_route():
#     user = current_token.get_user()
#     groups = current_token.get('groups', [])
```

## Step 4: Enable Grafana OAuth

### 4.1 Update monitoring-stack values.stage.yaml

```yaml
# helm-charts/monitoring-stack/values.stage.yaml
kubePrometheusStack:
  grafana:
    auth:
      enabled: true
      keycloak:
        enabled: true
        authUrl: "http://keycloak.keycloak.svc.cluster.local/realms/platform/protocol/openid-connect/auth"
        tokenUrl: "http://keycloak.keycloak.svc.cluster.local/realms/platform/protocol/openid-connect/token"
        apiUrl: "http://keycloak.keycloak.svc.cluster.local/realms/platform/protocol/openid-connect/userinfo"
        clientId: "grafana"
        scopes: "openid profile email groups"
        roleAttributePath: "contains(groups[*], '/grafana-admins') && 'Admin' || contains(groups[*], '/grafana-editors') && 'Editor' || 'Viewer'"
```

### 4.2 Add Grafana Secret

The Grafana client secret needs to be added to the kube-prometheus-stack Helm values:

```yaml
# helm-charts/monitoring-stack/templates/grafana-oauth-secret.yaml
# Or configure via ExternalSecret targeting grafana's secret
```

## Step 5: Enable ArgoCD OIDC

### 5.1 Update ArgoCD ConfigMap

```bash
kubectl patch configmap argocd-cm -n argocd --patch '
data:
  oidc.config: |
    name: Keycloak
    issuer: http://keycloak.keycloak.svc.cluster.local/realms/platform
    clientID: argocd
    clientSecret: $oidc.keycloak.clientSecret
    requestedScopes:
      - openid
      - profile
      - email
      - groups
    requestedIDTokenClaims:
      groups:
        essential: true
'
```

### 5.2 Update ArgoCD Secret

```bash
kubectl patch secret argocd-secret -n argocd --patch '
stringData:
  oidc.keycloak.clientSecret: <argocd-client-secret>
'
```

### 5.3 Update ArgoCD RBAC

```bash
kubectl patch configmap argocd-rbac-cm -n argocd --patch '
data:
  policy.csv: |
    g, /platform-admins, role:admin
    g, /developers, role:readonly
    p, role:developer, applications, sync, */*, allow
    p, role:developer, applications, get, */*, allow
    g, /developers, role:developer
  policy.default: role:readonly
  scopes: "[groups]"
'
```

## Step 6: Enable React Frontend Keycloak

### 6.1 Update nginx-front values.stage.yaml

```yaml
# helm-charts/nginx-front/values.stage.yaml
keycloak:
  enabled: true
  url: "http://keycloak.staging.local"  # External URL
  realm: "platform"
  clientId: "react-frontend"
  pkceEnabled: true
  onLoad: "check-sso"
  silentCheckSsoEnabled: true
  minTokenValidity: 30

runtimeConfig:
  enabled: true
```

### 6.2 React Application Code

```tsx
// src/keycloak.ts
import Keycloak from 'keycloak-js';

const config = (window as any).__RUNTIME_CONFIG__;

export const keycloak = new Keycloak({
  url: config.KEYCLOAK_URL,
  realm: config.KEYCLOAK_REALM,
  clientId: config.KEYCLOAK_CLIENT_ID,
});

export const initKeycloak = async () => {
  const authenticated = await keycloak.init({
    onLoad: config.KEYCLOAK_ON_LOAD,
    silentCheckSsoRedirectUri: window.location.origin + config.KEYCLOAK_SILENT_CHECK_SSO_REDIRECT_URI,
    pkceMethod: config.KEYCLOAK_PKCE_ENABLED ? 'S256' : undefined,
  });
  
  // Set up token refresh
  setInterval(() => {
    keycloak.updateToken(config.KEYCLOAK_MIN_TOKEN_VALIDITY);
  }, 30000);
  
  return authenticated;
};
```

## Verification

### Test Authentication Flow

```bash
# 1. Get token from Keycloak
TOKEN=$(curl -s -X POST \
  "http://keycloak.staging.local/realms/platform/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=flask-backend" \
  -d "client_secret=<secret>" \
  -d "username=testuser" \
  -d "password=<password>" | jq -r '.access_token')

# 2. Call Flask API with token
curl -H "Authorization: Bearer $TOKEN" \
  http://flask-app.backend.svc.cluster.local:5000/api/protected

# 3. Verify token claims
echo $TOKEN | cut -d. -f2 | base64 -d | jq .
```

## Troubleshooting

### Common Issues

1. **Invalid redirect URI**: Ensure redirect URIs in Keycloak clients match exactly
2. **Token validation fails**: Check issuer URL matches Keycloak's realm URL
3. **Groups not in token**: Ensure groups scope is added to client and mapper is configured
4. **CORS errors**: Add frontend URL to Web Origins in Keycloak client

### Debug Commands

```bash
# Check Keycloak logs
kubectl logs -n keycloak -l app.kubernetes.io/name=keycloak

# Check ExternalSecret status
kubectl get externalsecrets -n keycloak

# Verify secrets created
kubectl get secrets -n keycloak

# Test Keycloak OIDC discovery
curl http://keycloak.keycloak.svc.cluster.local/realms/platform/.well-known/openid-configuration
```

## Security Considerations

1. **Use HTTPS in production**: All OAuth flows should use HTTPS
2. **Rotate client secrets regularly**: Use External Secrets with rotation
3. **Limit token lifetimes**: Set appropriate access token (5-15 min) and refresh token (hours-days) lifetimes
4. **Use PKCE for public clients**: Always enable PKCE for SPAs
5. **Validate all claims**: Check issuer, audience, and expiration in backend
