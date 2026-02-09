# ArgoCD Keycloak SSO Setup Guide

This guide explains how to configure ArgoCD to use Keycloak as an OIDC (OpenID Connect) provider for Single Sign-On (SSO).

## Prerequisites

1. **ArgoCD installed** in the `argocd` namespace
2. **Keycloak running** and accessible
3. **kubectl access** to the Kubernetes cluster
4. **Admin access** to Keycloak

## Step 1: Create Keycloak Client

### 1.1 Access Keycloak Admin Console

Navigate to your Keycloak admin console (e.g., `https://keycloak.adaas-il.com/admin`)

### 1.2 Create a New Client

1. Go to **Clients** → **Create Client**
2. Configure the client:
   - **Client ID**: `argocd`
   - **Client Protocol**: `openid-connect`
   - **Access Type**: `confidential`
   - **Standard Flow Enabled**: `ON`
   - **Direct Access Grants Enabled**: `OFF`

3. Set **Valid Redirect URIs**:
   ```
   https://argocd.adaas-il.com/*
   https://argocd.adaas-il.com/auth/callback
   ```

4. Set **Base URL**: `https://argocd.adaas-il.com`

5. Set **Web Origins**: `https://argocd.adaas-il.com`

6. Click **Save**

### 1.3 Get Client Secret

1. Go to the **Credentials** tab
2. Copy the **Client Secret** - you'll need this for the script

### 1.4 Configure Group Mapper (Optional but Recommended)

To pass group information to ArgoCD for RBAC:

1. Go to **Client Scopes** → **argocd-dedicated** → **Mappers**
2. Click **Add Mapper** → **By Configuration** → **Group Membership**
3. Configure:
   - **Name**: `groups`
   - **Token Claim Name**: `groups`
   - **Full group path**: `OFF`
   - **Add to ID token**: `ON`
   - **Add to access token**: `ON`
   - **Add to userinfo**: `ON`
4. Click **Save**

## Step 2: Run Configuration Script

### 2.1 Set Environment Variables (Optional)

```bash
export KEYCLOAK_URL="https://keycloak.adaas-il.com"
export KEYCLOAK_REALM="master"
export ARGOCD_URL="https://argocd.adaas-il.com"
export CLIENT_ID="argocd"
```

### 2.2 Run the Script

```bash
cd /workspaces/docker-in-docker/demo-k8s-gitops
./scripts/configure-argocd-keycloak-sso.sh
```

The script will:
1. Check ArgoCD installation
2. Prompt for Keycloak client secret
3. Update ArgoCD secret with OIDC credentials
4. Configure OIDC settings in ArgoCD
5. Set up basic RBAC policies
6. Restart ArgoCD server

## Step 3: Configure RBAC (Optional)

### 3.1 Default RBAC Policy

The script sets up a basic RBAC policy where:
- All authenticated users get `readonly` access
- Users in the `argocd-admins` Keycloak group get `admin` access

### 3.2 Customize RBAC

Edit the RBAC ConfigMap:

```bash
kubectl edit configmap argocd-rbac-cm -n argocd
```

Example RBAC policy:

```yaml
data:
  policy.csv: |
    # Default policy for authenticated users
    g, authenticated, role:readonly

    # Admin access for argocd-admins group
    g, argocd-admins, role:admin

    # Platform developers get admin access
    g, platform-developers, role:admin

    # Platform operators get readonly access
    g, platform-operators, role:readonly

    # Custom role for CI/CD
    p, role:ci-cd, applications, sync, */*, allow
    p, role:ci-cd, applications, get, */*, allow
    g, ci-cd-bot, role:ci-cd

  policy.default: role:readonly
  scopes: '[groups, email]'
```

### 3.3 RBAC Role Reference

Built-in roles:
- `role:admin` - Full admin access
- `role:readonly` - Read-only access to all resources

Custom permissions format:
```
p, <role/user/group>, <resource>, <action>, <object>, <effect>
```

Examples:
```csv
# Allow sync for specific project
p, role:developer, applications, sync, my-project/*, allow

# Allow create/delete for all apps
p, role:admin, applications, *, */*, allow

# Deny delete for production
p, role:developer, applications, delete, production/*, deny
```

## Step 4: Create Keycloak Groups (Optional)

### 4.1 Create Groups

1. In Keycloak Admin Console, go to **Groups**
2. Create groups:
   - `argocd-admins`
   - `platform-developers`
   - `platform-operators`

### 4.2 Assign Users to Groups

1. Go to **Users** → select a user
2. Go to **Groups** tab
3. Select the group and click **Join**

## Step 5: Test SSO Login

### 5.1 Access ArgoCD

1. Navigate to `https://argocd.adaas-il.com`
2. Click **LOG IN VIA KEYCLOAK**
3. Authenticate with your Keycloak credentials
4. You should be redirected back to ArgoCD

### 5.2 Verify Access

Check your permissions:
```bash
# Login via CLI
argocd login argocd.adaas-il.com --sso

# Check current user
argocd account get-user-info

# List accessible resources
argocd app list
```

## Troubleshooting

### Issue: "Login failed" or redirect issues

**Solution**: Verify redirect URIs in Keycloak client match exactly:
```
https://argocd.adaas-il.com/*
https://argocd.adaas-il.com/auth/callback
```

### Issue: "Groups not appearing in ArgoCD"

**Solution**: 
1. Check group mapper configuration in Keycloak
2. Verify `groups` scope is requested in ArgoCD OIDC config
3. Check ArgoCD logs: `kubectl logs -n argocd deployment/argocd-server`

### Issue: "User has no permissions"

**Solution**:
1. Check user's groups in Keycloak
2. Verify RBAC policy in `argocd-rbac-cm`
3. Check scopes in RBAC config: `scopes: '[groups, email]'`

### Issue: "Invalid client secret"

**Solution**: Re-run the configuration script with the correct client secret

## Manual Configuration (Alternative)

If you prefer to configure manually instead of using the script:

### Update argocd-secret

```bash
kubectl patch secret argocd-secret -n argocd --type merge -p '{
  "stringData": {
    "oidc.keycloak.clientSecret": "YOUR_CLIENT_SECRET_HERE"
  }
}'
```

### Update argocd-cm

```bash
kubectl patch configmap argocd-cm -n argocd --type merge -p '
data:
  url: "https://argocd.adaas-il.com"
  oidc.config: |
    name: Keycloak
    issuer: https://keycloak.adaas-il.com/realms/master
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

### Update argocd-rbac-cm

```bash
kubectl patch configmap argocd-rbac-cm -n argocd --type merge -p '
data:
  policy.csv: |
    g, authenticated, role:readonly
    g, argocd-admins, role:admin
  policy.default: role:readonly
  scopes: "[groups, email]"
'
```

### Restart ArgoCD Server

```bash
kubectl rollout restart deployment argocd-server -n argocd
```

## Additional Resources

- [ArgoCD SSO Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/)
- [ArgoCD RBAC Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
