# First Run Guide

Complete setup from a blank OKE cluster to a running platform.

## Prerequisites

- OKE cluster running with `kubectl` access
- OCI Vault created in the same compartment
- Dynamic group for OKE nodes with vault read policy
- Cloudflare account with DNS zone for your domain
- Domain DNS pointing to edge proxy IP

## 1. OCI Vault Secrets

Create these secrets in OCI Vault. Each is a single JSON blob.

### `keycloak` secret

```json
{
  "admin-user": "admin",
  "admin-password": "<generate>",
  "username": "KEYCLOAK",
  "password": "<atp-password>",
  "jdbc-url": "jdbc:oracle:thin:@stagingdb_high?TNS_ADMIN=/opt/oracle/wallet"
}
```

### `flask-app` secret

```json
{
  "DB_USER": "FLASK_USER",
  "DB_PASSWORD": "<atp-password>",
  "DB_HOST": "adb.il-jerusalem-1.oraclecloud.com",
  "DB_PORT": "1521",
  "DB_NAME": "stagingdb_high",
  "SECRET_KEY": "<random-64-char>",
  "API_TEST_KEY": "<random-32-char>",
  "DATABASE_ENCRYPTION_KEY_V1": "<fernet-key>",
  "CURRENT_KEY_VERSION": "v1"
}
```

Generate the Fernet key:

```bash
python3 scripts/generate_encryption_keys.py
```

### `flask-jwt-keys` secret

```json
{
  "JWT_PRIVATE_KEY": "<rsa-private-key-pem>",
  "JWT_PUBLIC_KEY": "<rsa-public-key-pem>"
}
```

Generate the RSA keypair:

```bash
openssl genrsa -out jwt-private.pem 2048
openssl rsa -in jwt-private.pem -pubout -out jwt-public.pem
```

### `platform-bff` secret

```json
{
  "OAUTH2_PROXY_CLIENT_ID": "platform-bff",
  "OAUTH2_PROXY_CLIENT_SECRET": "<from-keycloak>",
  "OAUTH2_PROXY_COOKIE_SECRET": "<32-byte-base64>"
}
```

Generate cookie secret:

```bash
python3 -c "import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())"
```

### `cloudflare` secret

```json
{
  "api-key": "<cloudflare-global-api-key>",
  "email": "you@example.com"
}
```

### `monitoring` secret

```json
{
  "GRAFANA_ADMIN_PASSWORD": "<generate>",
  "GRAFANA_OIDC_SECRET": "<from-keycloak>"
}
```

### `keycloak-wallet-bucket-info` secret

```json
{
  "bucket_name": "atp-wallets",
  "namespace": "<oci-object-storage-namespace>",
  "object_name": "wallet.zip",
  "region": "il-jerusalem-1"
}
```

> **Tip**: Use [docs/OCI_VAULT_PLATFORM_APP_SETUP.md](OCI_VAULT_PLATFORM_APP_SETUP.md) for detailed OCI Console steps.

## 2. ClusterSecretStore

The ESO ClusterSecretStore connects Kubernetes to OCI Vault using instance principal auth.

```bash
kubectl apply -f apps/oci-staging/cluster-secret-store.yaml
```

Verify:

```bash
kubectl get clustersecretstore oci-vault
# STATUS should be "Valid"
```

## 3. Deploy Infrastructure (Ingress + Reflector)

```bash
kubectl apply -f apps/oci-staging/platform-ingress.yaml
kubectl apply -f apps/oci-staging/reflector.yaml
```

Wait for the ingress controller and cert-manager to be ready:

```bash
kubectl get pods -n ingress-nginx
kubectl get clusterissuer letsencrypt-prod
```

## 4. Deploy Keycloak

```bash
kubectl apply -f apps/oci-staging/keycloak.yaml
```

### First-time Keycloak on Oracle ATP

Keycloak creates its schema automatically. If deploying to an ATP instance that had a previous Keycloak install, you may hit `ORA-00955: name is already used by an existing object`.

**Fix**: Drop existing Keycloak tables first:

```bash
# Connect to ATP via SQL Developer or cloud shell
sqlplus KEYCLOAK/<password>@stagingdb_high

# Run the cleanup script
@scripts/fix-keycloak-db.sql
```

Or use the Liquibase repair script:

```bash
scripts/fix-keycloak-liquibase.sh
```

See [docs/KEYCLOAK_ATP_TABLE_CONFLICT_FIX.md](KEYCLOAK_ATP_TABLE_CONFLICT_FIX.md) for full details.

### Configure Keycloak Realm

After Keycloak is running at `https://keycloak.<domain>`:

1. **Create clients** — `platform-bff`, `grafana`, `argocd`
2. **Create groups** — `platform-developers`, `monitoring-viewers`
3. **Create group mapper** — Add a `groups` claim to tokens
4. **Assign users to groups**

Detailed steps: [docs/KEYCLOAK_SSO_SETUP.md](KEYCLOAK_SSO_SETUP.md)

Automated (after initial manual client creation):

```bash
scripts/configure-argocd-keycloak-sso.sh
scripts/configure-argocd-groups.sh
```

### Update Vault with Keycloak client secrets

After creating the clients, copy each client secret back to OCI Vault:

- `platform-bff` client secret → `platform-bff` vault secret → `OAUTH2_PROXY_CLIENT_SECRET`
- `grafana` client secret → `monitoring` vault secret → `GRAFANA_OIDC_SECRET`
- `argocd` client secret → ArgoCD SSO config

## 5. Deploy Monitoring

```bash
kubectl apply -f apps/oci-staging/monitoring-stack.yaml
```

Grafana is available at `https://grafana.<domain>`. Default admin password comes from the `monitoring` vault secret.

Keycloak SSO login appears on the Grafana login page once the `grafana` client is created in Keycloak.

## 6. Deploy Platform App

```bash
kubectl apply -f apps/oci-staging/platform-app.yaml
```

### First-time Flask Backend on Oracle ATP

The Flask app uses SQLAlchemy `db.create_all()` to create tables, but Oracle doesn't auto-create sequences for auto-increment IDs.

**After the first successful pod startup**, run the Oracle sequences script:

```bash
# Connect to ATP
sqlplus FLASK_USER/<password>@stagingdb_high

# Create sequences and triggers
@scripts/fix-oracle-sequences.sql
```

This creates sequences and triggers for: `users`, `patients`, `appointments`, `messages`, `refresh_tokens`, `system_settings`.

### Verify deployment

```bash
# Check all pods
kubectl get pods -n platform

# Test the API (should return 401 — auth required)
curl -s -o /dev/null -w "%{http_code}" https://app.<domain>/api/health

# Test OAuth2 flow
curl -s -o /dev/null -w "%{http_code}" https://app.<domain>/auth/login
# Should return 302 → Keycloak
```

## 7. Edge Proxy

The edge proxy VM runs NGINX and forwards traffic to OKE NodePorts.

```bash
ssh opc@<edge-proxy-ip>

# Update upstream blocks with OKE node IPs
sudo vi /etc/nginx/nginx.conf
# upstream k8s_ingress_http  { server 10.0.20.X:30080; server 10.0.20.Y:30080; }
# upstream k8s_ingress_https { server 10.0.20.X:30443; server 10.0.20.Y:30443; }

sudo nginx -t && sudo systemctl reload nginx
```

## Post-Deployment Checklist

- [ ] ClusterSecretStore status = `Valid`
- [ ] All ExternalSecrets status = `SecretSynced`
- [ ] Keycloak admin login works
- [ ] Keycloak clients created (platform-bff, grafana, argocd)
- [ ] Grafana login page shows "Sign in with Keycloak"
- [ ] ArgoCD login page shows "Log in via Keycloak"
- [ ] Platform app redirects to Keycloak on `/auth/login`
- [ ] Oracle sequences created for Flask tables
- [ ] Let's Encrypt certificates issued (`kubectl get certificates --all-namespaces`)
- [ ] Prometheus targets healthy (`kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090`)
