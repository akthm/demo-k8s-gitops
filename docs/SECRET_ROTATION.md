# Secret Rotation

All secrets are stored in **OCI Vault** and synced to Kubernetes via the External Secrets Operator (ESO). This document covers rotation procedures for each secret type.

## Secret Inventory

| OCI Vault Secret | Namespace | Rotation Frequency | Impact |
|-----------------|-----------|-------------------|--------|
| `flask-app` (DB encryption keys) | platform | 180 days | Requires re-encryption migration |
| `flask-jwt-keys` | platform | 90 days | Existing tokens invalid after grace period |
| `platform-bff` (OAuth2 cookie) | platform | 90 days | Active sessions invalidated |
| `keycloak` (admin + DB) | keycloak | On compromise only | Keycloak restart required |
| `cloudflare` (API key) | ingress-nginx | On compromise only | Cert renewal affected during rotation |
| `monitoring` (Grafana secrets) | monitoring | On compromise only | Grafana restart required |

## How It Works

```
OCI Vault  ──(ESO polls every refreshInterval)──▶  K8s Secret  ──(Reloader)──▶  Pod restart
```

1. You update a secret version in OCI Vault
2. ESO detects the change on its next refresh cycle (default 10m)
3. ESO updates the Kubernetes Secret
4. Reloader (or ArgoCD) restarts affected pods
5. Application loads new secret values

## Database Encryption Key Rotation

The Flask app uses Fernet symmetric encryption with versioned keys. Old keys are kept for decryption during a grace period.

### Key Structure in OCI Vault (`flask-app` secret)

```json
{
  "DATABASE_ENCRYPTION_KEY_V1": "<fernet-key>",
  "DATABASE_ENCRYPTION_KEY_V2": "<fernet-key>",
  "CURRENT_KEY_VERSION": "v2",
  "ROTATION_DATE": "2026-02-01T00:00:00Z",
  "MIGRATION_STATUS": "completed"
}
```

### Rotation Procedure

**1. Generate new key**

```bash
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

**2. Update OCI Vault secret**

Add the new key version and update `CURRENT_KEY_VERSION`:

```bash
# Using OCI CLI
oci vault secret update-secret-content \
  --secret-id <SECRET_OCID> \
  --content-type BASE64 \
  --content "$(echo '<updated-json>' | base64 -w 0)"
```

The updated JSON should contain all existing keys plus the new one:

```json
{
  "DATABASE_ENCRYPTION_KEY_V1": "<old-key>",
  "DATABASE_ENCRYPTION_KEY_V2": "<current-key>",
  "DATABASE_ENCRYPTION_KEY_V3": "<new-key>",
  "CURRENT_KEY_VERSION": "v3",
  "ROTATION_DATE": "2026-08-01T00:00:00Z",
  "MIGRATION_STATUS": "pending"
}
```

**3. Wait for ESO sync** (~10 minutes) or force it:

```bash
kubectl annotate externalsecret flask-app-encryption-keys \
  -n platform force-sync="$(date +%s)" --overwrite
```

**4. Verify pods have new key**

```bash
POD=$(kubectl get pod -n platform -l app=flask-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n platform $POD -- ls /run/secrets/db_encryption_keys/
# Should show: v1.key  v2.key  v3.key  current.version
kubectl exec -n platform $POD -- cat /run/secrets/db_encryption_keys/current.version
# Should show: v3
```

**5. Re-encrypt existing data** (background process)

```bash
kubectl exec -n platform $POD -- python scripts/migrate-encryption-keys.py --stats
# Runs in batches of 100 records
```

**6. After grace period (30 days)**, remove the oldest key from OCI Vault.

### Rollback

Revert `CURRENT_KEY_VERSION` in OCI Vault to the previous version. All keys remain available for decryption.

```bash
# Update vault secret: set CURRENT_KEY_VERSION back to "v2"
# Then force sync and restart
kubectl annotate externalsecret flask-app-encryption-keys -n platform force-sync="$(date +%s)" --overwrite
kubectl rollout restart deployment/flask-app -n platform
```

## JWT Key Rotation

JWT keys use RSA keypairs. During rotation, both old and new public keys are available for token validation.

### Rotation Procedure

**1. Generate new keypair**

```bash
openssl genrsa -out jwt-private.pem 2048
openssl rsa -in jwt-private.pem -pubout -out jwt-public.pem
```

**2. Update OCI Vault** — replace `JWT_PRIVATE_KEY` and `JWT_PUBLIC_KEY` in the `flask-jwt-keys` secret. Optionally store old public key as `JWT_PUBLIC_KEY_PREVIOUS` for grace period.

**3. Wait for ESO sync or force it**

**4. Restart pods**

```bash
kubectl rollout restart deployment/flask-app -n platform
```

> **Note**: Existing JWTs signed with the old key will fail validation after rotation unless the app supports multi-key verification. Plan rotation during low-traffic windows.

## OAuth2-Proxy Cookie Secret Rotation

Rotating the cookie secret in the `platform-bff` vault secret invalidates all active user sessions.

**1. Generate new cookie secret**

```bash
python3 -c "import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())"
```

**2. Update `OAUTH2_PROXY_COOKIE_SECRET` in OCI Vault**

**3. Wait for ESO sync → pods restart → users must re-authenticate**

## Monitoring Rotation Events

### Prometheus Queries

```promql
# Encryption key age (days since last rotation)
(time() - mokhaback_db_encryption_key_rotation_timestamp_seconds) / 86400

# Records still on old encryption key version
sum by (version) (mokhaback_db_encryption_key_version_distribution)

# ESO sync errors
externalsecret_sync_calls_error{name=~"flask-app.*"}
```

### Alerts

| Alert | Fires When | Action |
|-------|-----------|--------|
| `DBEncryptionKeyVersionStale` | Key age > 180 days | Rotate encryption key |
| `ExternalSecretNotReady` | ESO sync failing > 15m | Check OCI Vault connectivity |
| `MultipleEncryptionKeyVersionsActive` | Data on >1 key version after 30 days | Complete re-encryption migration |

### Force ESO Sync

```bash
# For a specific secret
kubectl annotate externalsecret <name> -n <namespace> force-sync="$(date +%s)" --overwrite

# Check sync status
kubectl get externalsecrets -n platform
```

## Pre-Rotation Checklist

- [ ] Verify current key version and migration status
- [ ] Confirm monitoring dashboards operational
- [ ] Notify team of scheduled rotation
- [ ] Check database health (for DB key rotation)
- [ ] Backup current vault secret version (OCI Vault keeps version history)

## Post-Rotation Checklist

- [ ] ESO sync completed (check ExternalSecret status)
- [ ] Pods restarted with new secrets
- [ ] No decryption errors in application logs
- [ ] New data encrypted with new key version
- [ ] Prometheus metrics updated
- [ ] Schedule old key removal after grace period
