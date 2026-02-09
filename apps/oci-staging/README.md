# OCI Staging Environment

ArgoCD Application manifests for OCI staging (Oracle Kubernetes Engine, `il-jerusalem-1`).

## Architecture

```
Cloudflare DNS → Edge Proxy (129.159.146.2) → OKE NodePort → nginx-ingress
```

**Domain**: `*.adaas-il.com`

## Deployment Order (Sync Waves)

| Wave | Application | Description |
|------|------------|-------------|
| -3 | `reflector` | Secret/ConfigMap replication across namespaces |
| -1 | `cluster-secret-store` | OCI Vault → ESO ClusterSecretStore |
| 0 | `platform-ingress` | NGINX Ingress + Let's Encrypt (Cloudflare DNS01) |
| 1 | `keycloak` | Keycloak SSO (external Oracle ATP) |
| 1 | `monitoring-stack` | Prometheus + Grafana |
| 2 | `platform-app` | Flask Backend + Nginx Frontend + OAuth2-Proxy + Redis |

## Apply

```bash
kubectl apply -f apps/oci-staging/
```

## OCI Vault Secrets Required

| Secret Name | Contents |
|-------------|----------|
| `keycloak` | admin creds, DB creds, JDBC URL |
| `flask-app` | DB creds, encryption keys, app secret |
| `flask-jwt-keys` | RSA keypair for JWT signing |
| `platform-bff` | OAuth2-proxy client ID/secret/cookie |
| `cloudflare` | API key for DNS01 challenge |
| `monitoring` | Grafana admin password, OIDC secret |
| `keycloak-wallet-bucket-info` | Object Storage bucket details for ATP wallet |

See [docs/FIRST_RUN.md](../../docs/FIRST_RUN.md) for setup instructions.
