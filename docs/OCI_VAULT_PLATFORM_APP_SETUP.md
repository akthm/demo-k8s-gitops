# OCI Vault Setup for Platform App

This guide provides step-by-step instructions for creating the required OCI Vault secrets for the platform-app umbrella chart deployment.

## Overview

The platform-app uses a consolidated secret named `platform-bff` in OCI Vault that contains all BFF (Backend-for-Frontend) authentication credentials.

## Secret Structure

### platform-bff

This secret contains three properties required for the BFF authentication layer:

- **client_secret**: Keycloak OIDC client secret for oauth2-proxy
- **cookie_secret**: Base64-encoded secret for oauth2-proxy session cookie encryption
- **internal_secret**: Shared secret between nginx-gateway and backend for internal API authentication

## Prerequisites

- OCI CLI installed and configured (`oci --version`)
- Access to OCI Vault in il-jerusalem-1 region
- Appropriate IAM permissions to create vault secrets
- Vault OCID: `ocid1.vault.oc1.il-jerusalem-1.hzuxkdlvaaeoe.abwxiljrggpuqky252x3qjqp5wc2utantvpi6g2xhgnemyufdgdjww2amgta`

## Step 1: Generate Secret Values

Run the following Python script to generate secure random values:

```bash
python3 << 'EOF'
import secrets
import base64
import json

# Generate secure secrets
client_secret = secrets.token_urlsafe(32)
cookie_secret = base64.b64encode(secrets.token_bytes(32)).decode('utf-8')
internal_secret = secrets.token_urlsafe(32)

# Create the secret structure
secret_data = {
    "client_secret": client_secret,
    "cookie_secret": cookie_secret,
    "internal_secret": internal_secret
}

print("Generated platform-bff secret structure:")
print(json.dumps(secret_data, indent=2))
print("\n" + "="*80)
print("\nBase64 encoded JSON for OCI CLI:")
json_str = json.dumps(secret_data)
base64_encoded = base64.b64encode(json_str.encode('utf-8')).decode('utf-8')
print(base64_encoded)

# Save to file for easy reference
with open('/tmp/platform-bff-secret.json', 'w') as f:
    json.dump(secret_data, f, indent=2)
print("\n✅ Secret structure saved to: /tmp/platform-bff-secret.json")
EOF
```

**Important Notes:**
1. Save the output - you'll need the base64 encoded JSON for the OCI CLI command
2. The `client_secret` should be replaced with your actual Keycloak client secret (see next section)
3. Keep the `cookie_secret` and `internal_secret` as generated (they are secure random values)

## Step 2: Get Keycloak Client Secret

The `client_secret` in the platform-bff secret should match the Keycloak OIDC client secret for the BFF oauth2-proxy client.

### Option A: Use Existing Flask Backend Client Secret

If you want to reuse the existing Flask backend client:

```bash
# Get the existing Flask backend client secret from Keycloak
CLIENT_SECRET=$(kubectl get secret -n keycloak keycloak-client-secrets -o jsonpath='{.data.flask_backend_secret}' | base64 -d)
echo "Existing Flask Backend Client Secret: $CLIENT_SECRET"
```

### Option B: Create New Keycloak Client for BFF

If you want a dedicated client for the BFF pattern:

1. Log in to Keycloak admin console
2. Navigate to the "platform" realm
3. Go to Clients → Create
4. Configure:
   - Client ID: `platform-bff`
   - Client Protocol: `openid-connect`
   - Access Type: `confidential`
   - Valid Redirect URIs: `https://platform.adaas-il.com/oauth2/callback`
5. Save and copy the generated client secret

### Update the Secret JSON

Edit `/tmp/platform-bff-secret.json` and replace the `client_secret` value:

```bash
# Example: Update with your actual client secret
cat > /tmp/platform-bff-secret.json << 'EOF'
{
  "client_secret": "YOUR_KEYCLOAK_CLIENT_SECRET_HERE",
  "cookie_secret": "Z//g2nhgHK7ICNGbcBbF3/JVLGlAHK4ZTW5geI42LcM=",
  "internal_secret": "YNkUb4mlTDvy2h6p7Hox7-gdrexVWQWlFCp9StMh2IY"
}
EOF

# Generate base64 encoded version
cat /tmp/platform-bff-secret.json | jq -c | base64 -w 0 > /tmp/platform-bff-secret-base64.txt
echo "✅ Base64 encoded secret saved to: /tmp/platform-bff-secret-base64.txt"
```

## Step 3: Get Required OCI Resource IDs

You need the compartment ID and KMS key ID to create the vault secret.

```bash
# Get compartment ID for platform-staging
COMPARTMENT_ID=$(oci iam compartment list --all | jq -r '.data[] | select(.name=="platform-staging") | .id')
echo "Compartment ID: $COMPARTMENT_ID"

# Get the KMS master key ID from an existing secret
# List secrets in the vault
oci vault secret list \
  --compartment-id "$COMPARTMENT_ID" \
  --vault-id "ocid1.vault.oc1.il-jerusalem-1.hzuxkdlvaaeoe.abwxiljrggpuqky252x3qjqp5wc2utantvpi6g2xhgnemyufdgdjww2amgta" \
  | jq -r '.data[0]."key-id"' > /tmp/kms-key-id.txt

KMS_KEY_ID=$(cat /tmp/kms-key-id.txt)
echo "KMS Key ID: $KMS_KEY_ID"

# Save for later use
export COMPARTMENT_ID
export KMS_KEY_ID
export VAULT_ID="ocid1.vault.oc1.il-jerusalem-1.hzuxkdlvaaeoe.abwxiljrggpuqky252x3qjqp5wc2utantvpi6g2xhgnemyufdgdjww2amgta"
```

## Step 4: Create OCI Vault Secret

Now create the secret in OCI Vault:

```bash
# Read the base64 encoded secret content
SECRET_CONTENT=$(cat /tmp/platform-bff-secret-base64.txt)

# Create the secret in OCI Vault
oci vault secret create-base64 \
  --compartment-id "$COMPARTMENT_ID" \
  --secret-name "platform-bff" \
  --vault-id "$VAULT_ID" \
  --key-id "$KMS_KEY_ID" \
  --secret-content-content "$SECRET_CONTENT" \
  --description "BFF authentication secrets for platform-app (oauth2-proxy client_secret, cookie_secret, nginx-gateway internal_secret)" \
  --wait-for-state ACTIVE

echo "✅ Secret 'platform-bff' created successfully in OCI Vault"
```

## Step 5: Verify Secret Creation

Check that the secret was created correctly:

```bash
# List secrets in the vault
oci vault secret list \
  --compartment-id "$COMPARTMENT_ID" \
  --vault-id "$VAULT_ID" \
  | jq -r '.data[] | select(.["secret-name"]=="platform-bff") | {name: .["secret-name"], id: .id, lifecycle: .["lifecycle-state"]}'

# Get secret details
SECRET_ID=$(oci vault secret list \
  --compartment-id "$COMPARTMENT_ID" \
  --vault-id "$VAULT_ID" \
  | jq -r '.data[] | select(.["secret-name"]=="platform-bff") | .id')

oci vault secret get --secret-id "$SECRET_ID" | jq '.data'
```

## Step 6: Sync External Secrets in Kubernetes

After creating the OCI Vault secret, the External Secrets Operator will automatically sync it to Kubernetes.

```bash
# Check external secret status
kubectl get externalsecret -n platform platform-platform-app-oauth2-proxy-secrets

# Expected output:
# NAME                                       STORE       REFRESH INTERVAL   STATUS         READY
# platform-platform-app-oauth2-proxy-secrets oci-vault   10m                SecretSynced   True

# Check the created Kubernetes secret
kubectl get secret -n platform platform-app-oauth2-proxy-secrets -o yaml

# Verify the BFF internal secret
kubectl get externalsecret -n platform platform-platform-app-bff-internal
```

## Troubleshooting

### Error: "secretName contains one or more invalid characters"

This error occurs when trying to use secret names with special characters like `/`. OCI Vault secret names must:
- Use only letters, numbers, hyphens, underscores, and periods
- Not contain slashes or other special characters

✅ **Correct**: `platform-bff`  
❌ **Incorrect**: `oci-staging/platform-bff`

### External Secret Not Syncing

Check the external secret status:

```bash
kubectl describe externalsecret -n platform platform-platform-app-oauth2-proxy-secrets

# Check ESO logs
kubectl logs -n external-secrets-operator deployment/external-secrets -f
```

Common issues:
1. Secret name doesn't exist in OCI Vault
2. Incorrect secret store reference
3. IAM permissions issues

### Missing Properties in Secret

Ensure the JSON in OCI Vault contains all required properties:

```bash
# Get secret content and decode
SECRET_ID=$(oci vault secret list \
  --compartment-id "$COMPARTMENT_ID" \
  --vault-id "$VAULT_ID" \
  | jq -r '.data[] | select(.["secret-name"]=="platform-bff") | .id')

# Get latest version
oci secrets secret-bundle get --secret-id "$SECRET_ID" \
  | jq -r '.data."secret-bundle-content".content' \
  | base64 -d \
  | jq '.'
```

Should show:
```json
{
  "client_secret": "...",
  "cookie_secret": "...",
  "internal_secret": "..."
}
```

## Secret Rotation

To rotate the platform-bff secret:

1. Generate new values using the script in Step 1
2. Create a new secret version:

```bash
# Generate new values
python3 -c "import secrets, base64, json; print(base64.b64encode(json.dumps({'client_secret': 'YOUR_CLIENT_SECRET', 'cookie_secret': base64.b64encode(secrets.token_bytes(32)).decode(), 'internal_secret': secrets.token_urlsafe(32)}).encode()).decode())" > /tmp/new-secret.txt

# Update secret with new version
oci vault secret update-base64 \
  --secret-id "$SECRET_ID" \
  --secret-content-content "$(cat /tmp/new-secret.txt)"
```

3. External Secrets Operator will automatically sync the new version within the refresh interval (10 minutes)

## Related Documentation

- [External Secrets Operator Retry Configuration](./EXTERNAL_SECRETS_RETRY_CONFIG.md)
- [Keycloak SSO Setup](./KEYCLOAK_SSO_SETUP.md)
- [OCI ArgoCD Provisioning](./OCI_ARGOCD_PROVISIONING.md)

## Summary

The platform-app deployment requires a single OCI Vault secret named `platform-bff` containing:
- `client_secret`: Keycloak OIDC client secret for oauth2-proxy
- `cookie_secret`: Session cookie encryption key
- `internal_secret`: Internal API authentication token

Once created, the External Secrets Operator will automatically create the corresponding Kubernetes secrets for use by the oauth2-proxy and nginx-gateway components.
