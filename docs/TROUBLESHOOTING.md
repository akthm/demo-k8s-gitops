# Troubleshooting

Known issues and their fixes, grouped by component.

---

## Keycloak

### ORA-00955: Table already exists on fresh deploy

**Symptom**: Keycloak pod crashes with `ORA-00955: name is already used by an existing object` in Liquibase migration.

**Cause**: Oracle ATP database has leftover Keycloak tables from a previous installation. Unlike PostgreSQL, Oracle doesn't support `IF NOT EXISTS` for table creation.

**Fix**: Drop all Keycloak tables and let Keycloak recreate them:

```bash
sqlplus KEYCLOAK/<password>@stagingdb_high
@scripts/fix-keycloak-db.sql
```

Or repair the Liquibase changelog:

```bash
scripts/fix-keycloak-liquibase.sh
```

Then restart the pod:

```bash
kubectl rollout restart statefulset/keycloak -n keycloak
```

### Keycloak stuck in CrashLoopBackOff (wallet not found)

**Symptom**: `download-wallet` init container fails with authentication error.

**Cause**: Instance principal auth not configured, or OCI IAM policy missing.

**Fix**: Verify the dynamic group and policy:

```bash
# The dynamic group must match OKE worker nodes
# Policy must grant: "Allow dynamic-group <group> to read objects in compartment <name>"
```

Check init container logs:

```bash
kubectl logs keycloak-0 -n keycloak -c download-wallet
```

---

## OAuth2-Proxy / Authentication

### 403 CSRF token mismatch

**Symptom**: After Keycloak login, oauth2-proxy returns `403 Forbidden` with CSRF error.

**Cause**: Cookie domain mismatch. The CSRF cookie is set on a different domain than the callback URL.

**Fix**: Ensure `cookie_domains` in oauth2-proxy config is empty (auto-detect) or matches the exact domain:

```yaml
# In platform-app values
oauth2Proxy:
  config:
    cookieDomains: ""  # Let oauth2-proxy auto-detect from request
```

### Redirect loop on /auth/login

**Symptom**: Browser loops between the frontend and `/auth/login` endlessly.

**Cause**: The frontend SPA handles `/auth/login` as a client-side route instead of proxying to oauth2-proxy.

**Fix**: The ingress must route `/auth/*` paths directly to oauth2-proxy before they reach the frontend. These ingress resources should exist:

- `/auth/login` → oauth2-proxy `/oauth2/start`
- `/auth/logout` → oauth2-proxy `/oauth2/sign_out`
- `/auth/userinfo` → oauth2-proxy `/oauth2/userinfo`

Check that all 6 ingress resources exist:

```bash
kubectl get ingress -n platform
```

### Auth refresh fails (cookie not sent to API)

**Symptom**: Frontend can authenticate but token refresh to `/api/*` fails with 401.

**Cause**: OAuth2-proxy cookie path defaults to `/oauth2/`, so the cookie isn't sent on `/api/*` requests.

**Fix**: Set `cookie_path: "/"` in oauth2-proxy config so the cookie is sent on all paths.

---

## Flask Backend

### Auto-increment IDs fail on Oracle

**Symptom**: `INSERT` statements fail with `ORA-01400: cannot insert NULL into (FLASK_USER.USERS.ID)`.

**Cause**: SQLAlchemy `db.create_all()` creates tables but not Oracle sequences/triggers for auto-increment.

**Fix**: Run the sequences script after the first deployment:

```bash
sqlplus FLASK_USER/<password>@stagingdb_high
@scripts/fix-oracle-sequences.sql
```

### Backend pods stuck in Init (wallet download)

**Symptom**: Flask pods stay in `Init:0/2` state.

**Cause**: Same as Keycloak wallet issue — instance principal or OCI policy not configured.

**Fix**: Check init container logs and verify IAM policy allows reading from the Object Storage bucket.

---

## Grafana

### Login locked out ("too many consecutive incorrect login attempts")

**Symptom**: Grafana shows lockout message, admin login blocked.

**Cause**: The sidecar container health checks use admin credentials and can trigger the lockout.

**Fix**: Restart the Grafana pod to reset the attempt counter:

```bash
kubectl rollout restart deployment/prometheus-grafana -n monitoring
```

### Keycloak SSO button not showing

**Symptom**: Grafana login page only shows username/password, no "Sign in with Keycloak" button.

**Cause**: The `grafana.ini` `[auth.generic_oauth]` section is missing from the ConfigMap. This happens when the helm template doesn't pass through `grafana.ini` values.

**Fix**: Verify the ConfigMap contains the OAuth section:

```bash
kubectl get configmap prometheus-grafana -n monitoring -o yaml | grep "auth.generic_oauth"
```

If missing, check that the `kube-prometheus-stack.yaml` template includes:

```yaml
{{- if index .Values.kubePrometheusStack.grafana "grafana.ini" }}
grafana.ini:
  {{- toYaml (index .Values.kubePrometheusStack.grafana "grafana.ini") | nindent 12 }}
{{- end }}
```

---

## External Secrets Operator

### ExternalSecret stuck in `SecretSyncedError`

**Symptom**: `kubectl get externalsecrets` shows error status.

**Cause**: OCI Vault secret doesn't exist, wrong OCID, or IAM policy issue.

**Fix**:

```bash
# Check the error message
kubectl describe externalsecret <name> -n <namespace>

# Verify ClusterSecretStore is healthy
kubectl get clustersecretstore oci-vault

# Force re-sync
kubectl annotate externalsecret <name> -n <namespace> force-sync="$(date +%s)" --overwrite
```

### Secret not updating after vault change

**Symptom**: You updated a secret in OCI Vault but the Kubernetes secret still has old values.

**Cause**: ESO polls on a `refreshInterval` (default 10m). Changes aren't instant.

**Fix**: Force sync or wait for the next refresh cycle:

```bash
kubectl annotate externalsecret <name> -n <namespace> force-sync="$(date +%s)" --overwrite
```

---

## ArgoCD

### Application OutOfSync but sync succeeds

**Symptom**: ArgoCD shows OutOfSync even after a successful sync.

**Cause**: Commonly caused by fields that are modified by controllers at runtime (HPA status, ExternalSecret status, Secret data managed by ESO).

**Fix**: Add `ignoreDifferences` to the Application spec:

```yaml
ignoreDifferences:
  - group: external-secrets.io
    kind: ExternalSecret
    jsonPointers:
      - /status
  - group: ""
    kind: Secret
    jsonPointers:
      - /data
```

### Sync fails with "another operation is in progress"

**Fix**: Wait or terminate the stuck operation:

```bash
kubectl patch application <name> -n argocd --type merge \
  -p '{"status":{"operationState":null}}'
```

For more ArgoCD debugging: see [ARGOCD_DEBUG_GUIDE.md](../ARGOCD_DEBUG_GUIDE.md).

---

## Ingress / TLS

### Let's Encrypt certificate not issued

**Symptom**: Certificate stays in `False` ready state.

**Cause**: DNS challenge failed — Cloudflare API key wrong, DNS not propagated, or rate limited.

**Fix**:

```bash
# Check certificate status
kubectl describe certificate -n <namespace>

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager -f

# Check the challenge
kubectl get challenges --all-namespaces
kubectl describe challenge <name> -n <namespace>
```

### 502 Bad Gateway after deploy

**Symptom**: NGINX returns 502 for a service that was just deployed.

**Cause**: Backend pods not yet ready, or service port mismatch.

**Fix**: Check if pods are running and endpoints are populated:

```bash
kubectl get pods -n <namespace>
kubectl get endpoints <service-name> -n <namespace>
```
