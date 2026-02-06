# OCI Production Environment

This directory contains ArgoCD Application manifests for deploying to OCI Production.

## Applications

| Application | Description | Sync Wave |
|------------|-------------|-----------|
| `platform-app` | Unified platform (Backend + Frontend + BFF) | 2 |
| `keycloak` | Keycloak SSO server | 1 |
| `monitoring-stack` | Prometheus + Grafana | 3 |
| `platform-ingress` | NGINX Ingress Controller | 0 |

## Deployment Order

Applications are deployed in sync wave order:
1. **Wave 0**: Platform Ingress (NGINX Ingress Controller)
2. **Wave 1**: Keycloak SSO
3. **Wave 2**: Platform App (depends on Keycloak)
4. **Wave 3**: Monitoring Stack

## Prerequisites

Before deploying:

1. **OCI Vault Secrets** - Ensure these secrets exist in OCI Vault:
   - `platform-bff-prod` - OAuth2-proxy client credentials
   - `flask-app-prod` - Flask application secrets
   - `keycloak-prod` - Keycloak admin credentials
   - `flask-app-jwt-keys-prod` - JWT signing keys
   - `flask-app-oidc-prod` - OIDC client credentials

2. **ClusterSecretStore** - OCI Vault ClusterSecretStore must be configured

3. **cert-manager** - Let's Encrypt ClusterIssuer (`letsencrypt-prod`)

4. **DNS** - Cloudflare DNS configured for your domain

## Usage

Apply all applications:
```bash
kubectl apply -f apps/oci-prod/
```

Or use App of Apps pattern with ArgoCD.
