# ==============================================================================
# Platform App Helm Chart
# ==============================================================================
# Unified umbrella chart combining Flask backend, Nginx frontend, and
# oauth2-proxy BFF authentication with Redis session storage for Keycloak SSO.
# ==============================================================================

## IMPORTANT
 - When changing any of the subcharts ( flask-app, nginx-front) UPDATE the chart using :
   `helm dependency update` in the `platform-app` directory before pushing changes.
## Overview

This Helm chart deploys a complete platform application stack with:

- **Flask Backend API** - Python REST API with BFF authentication support
- **Nginx Frontend** - React SPA served by Nginx
- **OAuth2 Proxy** - Keycloak OIDC authentication with session management
- **Redis** - Session storage for oauth2-proxy
- **Nginx Gateway** - BFF gateway handling auth and routing

## Architecture

```
                     ┌─────────────────────────────────┐
                     │         Ingress Controller       │
                     └─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Nginx Gateway (BFF)                               │
│  • Routes /api/* to Backend          • Auth via oauth2-proxy                │
│  • Routes /* to Frontend             • Sets X-Auth-Request-* headers        │
│  • Routes /oauth2/* to oauth2-proxy  • Internal secret verification         │
└─────────────────────────────────────────────────────────────────────────────┘
        │                    │                    │
        ▼                    ▼                    ▼
┌──────────────┐    ┌───────────────┐    ┌──────────────┐
│   Frontend   │    │  OAuth2-Proxy │    │   Backend    │
│   (Nginx)    │    │   (Session)   │    │   (Flask)    │
│              │    │               │    │              │
│  React SPA   │    │  OIDC + PKCE  │    │  BFF Auth    │
│  Cookie auth │    │  Redis store  │    │  JWT valid.  │
└──────────────┘    └───────────────┘    └──────────────┘
                           │                    │
                           ▼                    ▼
                    ┌─────────────┐      ┌─────────────┐
                    │    Redis    │      │   Database  │
                    │  (Sessions) │      │   (MySQL)   │
                    └─────────────┘      └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  Keycloak   │
                    │   (OIDC)    │
                    └─────────────┘
```

## Quick Start

### Local Development

```bash
# Add bitnami repo for Redis
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update dependencies
cd helm-charts/platform-app
helm dependency update

# Install for local development
helm install platform . -f values.local.yaml -n platform --create-namespace
```

### Staging Deployment

```bash
# Install with staging values
helm install platform . -f values.staging.yaml -n platform --create-namespace \
  --set global.bff.internalSecret=$(openssl rand -base64 32)
```

### Production Deployment

```bash
# Install with production values (uses External Secrets for credentials)
helm install platform . -f values.prod.yaml -n platform --create-namespace
```

## Configuration

### Global Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.domain` | Application domain | `platform.example.com` |
| `global.tls.enabled` | Enable TLS | `true` |
| `global.keycloak.url` | Keycloak server URL | - |
| `global.keycloak.realm` | Keycloak realm | `platform` |
| `global.keycloak.bffClientId` | OAuth2-proxy client ID | `bff-proxy` |
| `global.bff.enabled` | Enable BFF authentication | `true` |
| `global.bff.internalSecret` | Shared secret for backend trust | - |

### OAuth2 Proxy

| Parameter | Description | Default |
|-----------|-------------|---------|
| `oauth2Proxy.enabled` | Enable oauth2-proxy | `true` |
| `oauth2Proxy.replicaCount` | Number of replicas | `2` |
| `oauth2Proxy.config.skipAuthPaths` | Paths to skip auth | `["/health", "/ready"]` |

### Backend (Flask)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `backend.enabled` | Enable backend | `true` |
| `backend.config.AUTH_MODE` | Authentication mode | `bff` |
| `backend.bff.validateJwt` | Validate forwarded JWT | `true` |
| `backend.bff.jitProvision` | JIT user provisioning | `true` |

### Frontend (Nginx)

| Parameter | Description | Default |
|-----------|-------------|---------|
| `frontend.enabled` | Enable frontend | `true` |
| `frontend.bff.enabled` | Use BFF auth mode | `true` |
| `frontend.keycloak.enabled` | Use direct keycloak-js | `false` |

### Redis

| Parameter | Description | Default |
|-----------|-------------|---------|
| `redis.enabled` | Enable internal Redis | `true` |
| `global.bff.redis.external.enabled` | Use external Redis | `false` |
| `global.bff.redis.external.url` | External Redis URL | - |

## Authentication Flow

### BFF Pattern (Recommended)

1. User visits application
2. Nginx gateway checks session via oauth2-proxy (`auth_request`)
3. If no session, user redirected to `/oauth2/start` → Keycloak
4. After login, oauth2-proxy stores tokens in Redis, sets session cookie
5. Subsequent requests include session cookie
6. Nginx validates session, forwards identity headers to backend
7. Backend trusts headers after validating internal secret

### Security Features

- **HttpOnly session cookies** - Tokens never exposed to JavaScript
- **Internal secret verification** - Backend validates requests come from gateway
- **Defense-in-depth JWT validation** - Backend optionally validates forwarded token
- **CSRF protection** - Double-submit cookie pattern for state-changing requests
- **Rate limiting** - Per-IP rate limits on API and auth endpoints
- **Network policies** - Strict pod-to-pod communication rules

## Keycloak Client Setup

### BFF Proxy Client (Confidential)

Create in Keycloak Admin Console:
- **Client ID**: `bff-proxy`
- **Client Protocol**: openid-connect
- **Access Type**: confidential
- **Valid Redirect URIs**: `https://platform.example.com/oauth2/callback`
- **Web Origins**: `https://platform.example.com`

Required client scopes: `openid`, `profile`, `email`, `groups`

### Backend Client (Confidential)

For service-to-service and JWT validation:
- **Client ID**: `flask-backend`
- **Access Type**: confidential
- Enable service account if needed

## Troubleshooting

### Session not persisting
- Check Redis connectivity: `redis-cli -h <redis-host> ping`
- Verify cookie settings (Secure flag requires HTTPS)
- Check oauth2-proxy logs for session errors

### 401 Unauthorized on API calls
- Verify internal secret matches between nginx and backend
- Check oauth2-proxy is correctly forwarding identity headers
- Enable debug logging in backend: `DEBUG=1`

### CSRF validation failed
- Ensure XSRF-TOKEN cookie is being set
- Check X-CSRF-Token header in requests
- Verify `credentials: 'include'` in fetch calls

## Upgrading

```bash
# Update dependencies
helm dependency update

# Upgrade release
helm upgrade platform . -f values.staging.yaml -n platform
```

## Uninstalling

```bash
helm uninstall platform -n platform
kubectl delete namespace platform
```
