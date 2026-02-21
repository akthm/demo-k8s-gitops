# Platform GitOps

GitOps repository for the platform stack deployed on **OCI (Oracle Cloud Infrastructure)** using ArgoCD.

## Architecture

```
                       ┌──────────────────┐
                       │    Cloudflare    │
                       │   DNS + Proxy    │
                       └────────┬─────────┘
                                │
                       ┌────────▼─────────┐
                       │     NLB          │
                       │  proxy → OKE     │
                       └────────┬─────────┘
                                │ NodePort 30080/30443
                ┌───────────────▼───────────────┐
                │        OKE Cluster (private)  │
                │  ┌──────────────────────────┐ │
                │  │   nginx-ingress-ctrl     │ │
                │  └──────┬───────────────────┘ │
                │         │                     │
                │  ┌──────┼──────┬──────┐       │
                │  │      │      │      │       │
                │  ▼      ▼      ▼      ▼       │
                │ App  Keycloak Grafana ArgoCD  │
                └───────────────────────────────┘
                         │              │
              ┌──────────▼──┐   ┌───────▼────────┐
              │  Oracle ATP │   │   OCI Vault    │
              │  (Database) │   │   (Secrets)    │
              └─────────────┘   └────────────────┘
```

## Components

| Component | Description |
|-----------|-------------|
| **Platform App** | Flask backend (BFF) + React frontend + OAuth2-Proxy + Redis |
| **Keycloak** | SSO/OIDC provider on Oracle ATP |
| **Monitoring** | Prometheus + Grafana (kube-prometheus-stack) |
| **Ingress** | NGINX ingress controller with Let's Encrypt TLS |
| **Reflector** | Cross-namespace secret/configmap replication |

## Environments

| Directory | Cluster | Purpose |
|-----------|---------|---------|
| `apps/local/` | Kind (local) | Development with LocalStack secrets |
| `apps/oci-staging/` | OKE (il-jerusalem-1) | Staging — `*.adaas-il.com` |
| `apps/oci-prod/` | OKE (il-jerusalem-1) | Production |

## Repo Structure

```
apps/
  local/                  # ArgoCD apps for local Kind cluster
  oci-staging/            # ArgoCD apps for OCI staging
  oci-prod/               # ArgoCD apps for OCI production

helm-charts/
  platform-app/           # Umbrella chart (flask + nginx + oauth2-proxy + redis)
  keycloak/               # Keycloak SSO
  monitoring-stack/       # kube-prometheus-stack wrapper
  platform-ingress/       # NGINX ingress + cert-manager + Let's Encrypt
  flask-app/              # Flask backend subchart
  nginx-front/            # React frontend subchart
  argocd/                 # ArgoCD configuration

scripts/                  # Operational scripts (SSO config, DB fixes, key generation)
docs/                     # Setup guides, runbooks, troubleshooting
```

## Quick Start

### Prerequisites

- OKE cluster with `kubectl` access
- OCI Vault with secrets provisioned ([guide](docs/FIRST_RUN.md))
- Cloudflare DNS configured
- ArgoCD installed in cluster

### Deploy

```bash
# 1. Apply ClusterSecretStore (OCI Vault → ESO)
kubectl apply -f apps/oci-staging/cluster-secret-store.yaml

# 2. Apply all apps
kubectl apply -f apps/oci-staging/
```

ArgoCD handles the rest via sync waves.

## Documentation

| Document | Description |
|----------|-------------|
| [First Run Guide](docs/FIRST_RUN.md) | Complete setup from scratch — OCI Vault, Keycloak, Flask DB, ArgoCD |
| [Secret Rotation](docs/SECRET_ROTATION.md) | Rotation procedures for all secret types (DB keys, JWT, OAuth) |
| [SSO Setup](docs/KEYCLOAK_SSO_SETUP.md) | Keycloak client configuration for all services |
| [ArgoCD SSO](docs/ARGOCD_KEYCLOAK_SSO_SETUP.md) | ArgoCD OIDC integration with Keycloak |
| [OCI Provisioning](docs/OCI_ARGOCD_PROVISIONING.md) | OCI infrastructure and ArgoCD bootstrap |
| [OCI Vault Setup](docs/OCI_VAULT_PLATFORM_APP_SETUP.md) | Platform BFF secret structure in OCI Vault |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Known issues and fixes |
| [ArgoCD Debug](ARGOCD_DEBUG_GUIDE.md) | ArgoCD sync debugging reference |
| [Monitoring](docs/SECRETS_MONITORING_REFERENCE.md) | Prometheus alerts and Grafana dashboards for secrets |

## Scripts

| Script | Purpose |
|--------|---------|
| `switch-to-local.sh` | Switch kubectl context to local Kind cluster |
| `configure-argocd-keycloak-sso.sh` | Configure ArgoCD OIDC with Keycloak |
| `configure-argocd-groups.sh` | Set up ArgoCD RBAC group mappings |
| `create-oauth2-proxy-secret.sh` | Generate oauth2-proxy cookie secret |
| `generate_encryption_keys.py` | Generate Fernet encryption keys for OCI Vault |
| `fix-oracle-sequences.sql` | Create Oracle sequences/triggers for Flask tables |
| `fix-keycloak-db.sql` | Drop Keycloak tables for clean reinstall |
| `fix-keycloak-liquibase.sh` | Repair Keycloak Liquibase changelog locks |
| `validate-monitoring.sh` | Validate Prometheus targets and dashboards |
