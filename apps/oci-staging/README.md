# OCI Staging Environment

This directory contains ArgoCD Application manifests for the OCI staging environment deployed on Oracle Kubernetes Engine (OKE) in the `il-jerusalem-1` (Israel Jerusalem) region.

## Architecture

```
                           ┌─────────────────────┐
                           │     Cloudflare      │
                           │    DNS + Proxy      │
                           └──────────┬──────────┘
                                      │ DNS A Record
                                      ▼
                           ┌─────────────────────┐
                           │   Edge Proxy VM     │
                           │  129.159.146.2      │
                           │   NGINX + Certbot   │
                           └──────────┬──────────┘
                                      │ :80/:443 → NodePort 30080/30443
                                      ▼
                    ┌─────────────────────────────────┐
                    │         OKE Cluster             │
                    │        oke-staging              │
                    │   ┌─────────────────────────┐   │
                    │   │   nginx-ingress-ctrl    │   │
                    │   │   (NodePort Service)    │   │
                    │   └───────────┬─────────────┘   │
                    │               │                 │
                    │   ┌───────────┼───────────┐     │
                    │   ▼           ▼           ▼     │
                    │ ArgoCD   Keycloak    Grafana    │
                    │ Flask    Prometheus             │
                    └─────────────────────────────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    ▼                                   ▼
         ┌─────────────────────┐           ┌─────────────────────┐
         │  OCI Autonomous DB  │           │     OCI Vault       │
         │  (ATP - PostgreSQL) │           │  (Secrets Manager)  │
         │  - Flask DB         │           │  - DB credentials   │
         │  - Keycloak DB      │           │  - API keys         │
         └─────────────────────┘           │  - JWT keys         │
                                           │  - ATP Wallet       │
                                           └─────────────────────┘
```

## Components

| Application | Description | Sync Wave |
|-------------|-------------|-----------|
| `cluster-secret-store.yaml` | OCI Vault ClusterSecretStore | -1 |
| `platform-ingress.yaml` | NGINX Ingress + Let's Encrypt | 0 |
| `keycloak.yaml` | Keycloak SSO (external ATP) | 1 |
| `monitoring-stack.yaml` | Prometheus + Grafana | 1 |
| `platform-app.yaml` | Unified Platform (Flask + Nginx + OAuth2-Proxy + Redis) | 2 |
| `flask-backend.yaml` | Flask API standalone (deprecated - use platform-app) | 2 |

## Prerequisites

### 1. OCI Resources
- OKE cluster (`oke-staging`) - ACTIVE
- OCI Autonomous Database (ATP) with PostgreSQL
- OCI Vault with secrets provisioned
- Edge proxy VM with NGINX

### 2. Cloudflare DNS
- Domain purchased (GoDaddy → Cloudflare DNS)
- A records pointing to edge proxy IP: `129.159.146.2`
- API token with `Zone:DNS:Edit` permissions for cert-manager

### 3. OCI Vault Secrets

Create these secrets in OCI Vault:

| Secret Name | Keys |
|-------------|------|
| `oci-staging-flask-database` | `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DATABASE_ENCRYPTION_KEY_V1`, `CURRENT_KEY_VERSION` |
| `oci-staging-flask-app` | `SECRET_KEY`, `API_TEST_KEY` |
| `oci-staging-flask-jwt` | `JWT_PRIVATE_KEY`, `JWT_PUBLIC_KEY` |
| `oci-staging-flask-admin` | `INITIAL_ADMIN_USER` (JSON) |
| `oci-staging-keycloak-admin` | `admin-user`, `admin-password` |
| `oci-staging-keycloak-db` | `username`, `password` |
| `oci-staging-keycloak-clients` | `flask-backend-secret`, `grafana-secret`, `argocd-secret` |
| `oci-staging-atp-wallet` | `wallet` (base64-encoded wallet.zip) |
| `oci-staging-cloudflare` | `api-token` |

### 4. IAM Policies

```hcl
# Dynamic group for OKE nodes
resource "oci_identity_dynamic_group" "oke_nodes" {
  name           = "oke-staging-nodes"
  description    = "OKE staging cluster nodes"
  compartment_id = var.tenancy_ocid
  matching_rule  = "ALL {instance.compartment.id = '${var.compartment_ocid}'}"
}

# Policy for vault access
resource "oci_identity_policy" "oke_vault_access" {
  name           = "oke-staging-vault-policy"
  description    = "Allow OKE nodes to read vault secrets"
  compartment_id = var.compartment_ocid
  statements = [
    "Allow dynamic-group oke-staging-nodes to read secret-bundles in compartment ${var.compartment_name}",
    "Allow dynamic-group oke-staging-nodes to read vaults in compartment ${var.compartment_name}"
  ]
}
```

## Deployment

1. **Bootstrap ArgoCD** (if not installed):
   ```bash
   helm repo add argo https://argoproj.github.io/argo-helm
   helm install argocd argo/argo-cd -n argocd --create-namespace \
     --set server.service.type=NodePort \
     --set server.service.nodePortHttp=30080 \
     --set server.service.nodePortHttps=30443
   ```

2. **Apply ClusterSecretStore**:
   ```bash
   kubectl apply -f cluster-secret-store.yaml
   ```

3. **Apply App-of-Apps** (or individual apps):
   ```bash
   kubectl apply -f platform-ingress.yaml
   kubectl apply -f keycloak.yaml
   kubectl apply -f monitoring-stack.yaml
   kubectl apply -f flask-backend.yaml
   ```

## Edge Proxy Configuration

SSH to edge proxy and update NGINX upstream blocks:

```bash
ssh opc@129.159.146.2

# Get node IPs
kubectl get nodes -o wide

# Edit NGINX config
sudo vi /etc/nginx/nginx.conf

# Update upstream blocks with node private IPs:
# upstream k8s_ingress_http {
#     server 10.0.20.X:30080;
#     server 10.0.20.Y:30080;
# }
# upstream k8s_ingress_https {
#     server 10.0.20.X:30443;
#     server 10.0.20.Y:30443;
# }

sudo nginx -t && sudo systemctl reload nginx
```

## Let's Encrypt Certificate

After DNS is configured and ingress is deployed:

```bash
# On edge proxy (if using certbot there)
sudo certbot --nginx -d yourdomain.com -d *.yourdomain.com

# Or use cert-manager in cluster (recommended)
# Certificates are automatically provisioned via ClusterIssuer
```
