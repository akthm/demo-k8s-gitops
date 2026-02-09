# OCI Production Environment

ArgoCD Application manifests for OCI production (Oracle Kubernetes Engine).

## Deployment Order (Sync Waves)

| Wave | Application | Description |
|------|------------|-------------|
| -3 | `reflector` | Secret/ConfigMap replication across namespaces |
| 0 | `platform-ingress` | NGINX Ingress + Let's Encrypt |
| 1 | `keycloak` | Keycloak SSO (external Oracle ATP) |
| 1 | `monitoring-stack` | Prometheus + Grafana |
| 2 | `platform-app` | Flask Backend + Nginx Frontend + OAuth2-Proxy + Redis |

## Apply

```bash
kubectl apply -f apps/oci-prod/
```

## Prerequisites

See [docs/FIRST_RUN.md](../../docs/FIRST_RUN.md) for complete setup instructions.
