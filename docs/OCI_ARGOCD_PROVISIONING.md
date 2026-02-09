# OCI ArgoCD + Let's Encrypt + Cloudflare Provisioning Guide

Complete provisioning guide for deploying the platform on OCI Kubernetes Engine (OKE) with:
- **ArgoCD** for GitOps continuous delivery
- **Let's Encrypt** TLS certificates via Cloudflare DNS01 challenge
- **OCI Autonomous Database (ATP)** for Flask and Keycloak
- **OCI Vault** for secrets management
- **Cloudflare DNS** for domain management

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLOUDFLARE                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │
│  │   DNS Records   │  │  (Optional)     │  │   API Token     │              │
│  │  A → 129.159.   │  │   Proxy/WAF     │  │  Zone:DNS:Edit  │              │
│  │      146.2      │  │                 │  │  (cert-manager) │              │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    EDGE PROXY (VM.Standard.E2.1.Micro)                       │
│                         IP: 129.159.146.2                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  NGINX Reverse Proxy                                                 │    │
│  │  :80/:443 → NodePort 30080/30443                                    │    │
│  │  (Optional: certbot for edge TLS termination)                       │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      OKE CLUSTER (oke-staging)                               │
│                      Region: il-jerusalem-1                                  │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    NGINX Ingress Controller                           │   │
│  │                    (NodePort 30080/30443)                            │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│       ┌────────────────────────────┼────────────────────────────┐           │
│       │                            │                            │           │
│       ▼                            ▼                            ▼           │
│  ┌─────────────┐            ┌─────────────┐            ┌─────────────┐      │
│  │   ArgoCD    │            │  Keycloak   │            │   Grafana   │      │
│  │ argocd.*    │            │ keycloak.*  │            │ grafana.*   │      │
│  └─────────────┘            └─────────────┘            └─────────────┘      │
│       │                            │                            │           │
│       │                            │                            │           │
│       ▼                            ▼                            ▼           │
│  ┌─────────────┐            ┌─────────────┐            ┌─────────────┐      │
│  │ Flask API   │            │ Prometheus  │            │ External    │      │
│  │ api.*       │            │ prometheus.*│            │ Secrets     │      │
│  └─────────────┘            └─────────────┘            │ Operator    │      │
│                                                        └─────────────┘      │
│                                                               │              │
│                                    ┌──────────────────────────┘              │
│                                    ▼                                         │
│                          ┌─────────────────┐                                │
│                          │  cert-manager   │                                │
│                          │ (DNS01 solver)  │                                │
│                          └─────────────────┘                                │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
              ┌─────────────────────┴─────────────────────┐
              │                                           │
              ▼                                           ▼
┌──────────────────────────────┐          ┌──────────────────────────────┐
│   OCI AUTONOMOUS DATABASE    │          │    OCI VAULT (oke-staging)   │
│   (ATP - PostgreSQL Mode)    │          │    Consolidated App Secrets  │
│  ┌────────────────────────┐  │          │  ┌────────────────────────┐  │
│  │ Flask Database         │  │          │  │ flask-app              │  │
│  │ Keycloak Database      │  │          │  │ keycloak               │  │
│  └────────────────────────┘  │          │  │ cloudflare             │  │
│  Connection: TLS (sslmode)   │          │  │ monitoring             │  │
└──────────────────────────────┘          └──────────────────────────────┘
```

## Prerequisites

### 1. Domain Setup (GoDaddy → Cloudflare)

1. **Purchase domain from GoDaddy** (or transfer existing domain)

2. **Add domain to Cloudflare**:
   - Create free Cloudflare account at https://cloudflare.com
   - Add your domain to Cloudflare
   - Cloudflare provides nameservers (e.g., `ada.ns.cloudflare.com`, `bob.ns.cloudflare.com`)

3. **Update GoDaddy nameservers**:
   - Go to GoDaddy Domain Manager → DNS → Nameservers
   - Change to "Custom" and enter Cloudflare nameservers
   - Wait 24-48 hours for propagation

4. **Create Cloudflare API Token**:
   - Go to Cloudflare Dashboard → My Profile → API Tokens
   - Create Token → Custom Token
   - Permissions: `Zone:DNS:Edit` for your domain
   - Save the token securely (needed for OCI Vault)

### 2. OCI Infrastructure (Already Provisioned)

Based on your terraform state files:

| Resource | Value |
|----------|-------|
| **Cluster** | `oke-staging` (ACTIVE) |
| **Region** | `il-jerusalem-1` |
| **K8s Version** | `v1.34.1` |
| **Node Pool** | 2 nodes, VM.Standard.E4.Flex (2 OCPU, 12GB each) |
| **Edge Proxy IP** | `129.159.146.2` |
| **VCN CIDR** | `10.0.0.0/16` |

### 3. OCI Autonomous Database Setup

1. **Create ATP Instance** (if not already done):
   ```bash
   # Via OCI Console or CLI
   oci db autonomous-database create \
     --compartment-id $COMPARTMENT_OCID \
     --db-name "platformdb" \
     --display-name "Platform Staging ATP" \
     --cpu-core-count 1 \
     --data-storage-size-in-tbs 1 \
     --admin-password "YourSecurePassword123!" \
     --db-workload OLTP \
     --license-model LICENSE_INCLUDED \
     --is-free-tier true
   ```

2. **Create Database Users**:
   ```sql
   -- Connect as ADMIN
   CREATE USER flask_user IDENTIFIED BY "FlaskSecurePass123!";
   GRANT CONNECT, RESOURCE TO flask_user;
   ALTER USER flask_user QUOTA UNLIMITED ON DATA;
   
   CREATE USER keycloak IDENTIFIED BY "KeycloakSecurePass123!";
   GRANT CONNECT, RESOURCE TO keycloak;
   ALTER USER keycloak QUOTA UNLIMITED ON DATA;
   ```

3. **Download Wallet**:
   - OCI Console → Autonomous Database → DB Connection → Download Wallet
   - Extract and base64-encode each file for OCI Vault

### 4. OCI Vault Setup

1. **Create Vault**:
   ```bash
   oci kms management vault create \
     --compartment-id $COMPARTMENT_OCID \
     --display-name "oke-staging-vault" \
     --vault-type DEFAULT
   ```

2. **Create Master Encryption Key**:
   ```bash
   oci kms management key create \
     --compartment-id $COMPARTMENT_OCID \
     --display-name "oke-staging-master-key" \
     --key-shape '{"algorithm":"AES","length":32}' \
     --endpoint $VAULT_MANAGEMENT_ENDPOINT
   ```

3. **Create Secrets** (see [Secrets Reference](#oci-vault-secrets-reference) below)

### 5. IAM Policies for OKE

Create dynamic group and policies for OKE nodes to access Vault:

```hcl
# Dynamic Group
resource "oci_identity_dynamic_group" "oke_nodes" {
  compartment_id = var.tenancy_ocid
  name           = "oke-staging-nodes"
  description    = "OKE staging cluster nodes"
  matching_rule  = "ALL {instance.compartment.id = '${var.compartment_ocid}'}"
}

# Policy
resource "oci_identity_policy" "oke_vault_policy" {
  compartment_id = var.tenancy_ocid
  name           = "oke-staging-vault-access"
  description    = "Allow OKE nodes to read vault secrets"
  statements = [
    "Allow dynamic-group oke-staging-nodes to read secret-bundles in compartment ${var.compartment_name}",
    "Allow dynamic-group oke-staging-nodes to read vaults in compartment ${var.compartment_name}",
    "Allow dynamic-group oke-staging-nodes to read keys in compartment ${var.compartment_name}"
  ]
}
```

---

## Step-by-Step Provisioning

### Step 1: Configure Cloudflare DNS

Create DNS A records pointing to your edge proxy:

| Type | Name | Content | Proxy Status |
|------|------|---------|--------------|
| A | `@` | `129.159.146.2` | DNS Only (grey) |
| A | `*` | `129.159.146.2` | DNS Only (grey) |

Or individual subdomains:

| Type | Name | Content | Proxy Status |
|------|------|---------|--------------|
| A | `argocd` | `129.159.146.2` | DNS Only |
| A | `keycloak` | `129.159.146.2` | DNS Only |
| A | `api` | `129.159.146.2` | DNS Only |
| A | `grafana` | `129.159.146.2` | DNS Only |
| A | `prometheus` | `129.159.146.2` | DNS Only |

> **Note**: Keep proxy status as "DNS Only" (grey cloud) initially for Let's Encrypt DNS01 validation. You can enable Cloudflare proxy later.

### Step 2: Provision OCI Vault Secrets via Terraform

The OCI Vault secrets are managed via Terraform using the consolidated `application_secrets` structure. Each application has a single JSON blob secret containing all its configuration.

**Terraform Resource Structure:**

```hcl
# In your Terraform OCI Vault module

variable "application_secrets" {
  description = "Consolidated application secrets as JSON blobs"
  type = map(object({
    secret_name = string
    secret_data = map(string)
  }))
}

# Example terraform.tfvars or secret values:
application_secrets = {
  flask-app = {
    secret_name = "flask-app"
    secret_data = {
      DB_USER                       = "flask_user"
      DB_PASSWORD                   = "FlaskSecurePass123!"
      DB_HOST                       = "adb.il-jerusalem-1.oraclecloud.com"
      DB_PORT                       = "1521"
      DB_NAME                       = "stagingdb_high"
      SECRET_KEY                    = "your-flask-secret-key"
      API_TEST_KEY                  = "your-api-test-key"
      JWT_PRIVATE_KEY               = "-----BEGIN RSA PRIVATE KEY-----..."
      JWT_PUBLIC_KEY                = "-----BEGIN PUBLIC KEY-----..."
      OIDC_CLIENT_ID                = "flask-backend"
      OIDC_CLIENT_SECRET            = "your-oidc-client-secret"
      DATABASE_ENCRYPTION_KEY_V1    = "your-fernet-key-here"
      DATABASE_ENCRYPTION_KEY_V2    = ""
      CURRENT_KEY_VERSION           = "v1"
    }
  }
  
  keycloak = {
    secret_name = "keycloak"
    secret_data = {
      admin_user              = "admin"
      admin_password          = "KeycloakAdminPass123!"
      db_user                 = "keycloak"
      db_password             = "KeycloakDBPass123!"
      db_host                 = "adb.il-jerusalem-1.oraclecloud.com"
      db_port                 = "1521"
      db_name                 = "stagingdb_high"
      flask_backend_secret    = "your-flask-backend-secret"
      grafana_secret          = "your-grafana-secret"
      argocd_secret           = "your-argocd-secret"
    }
  }
  
  cloudflare = {
    secret_name = "cloudflare"
    secret_data = {
      CLOUDFLARE_API_TOKEN = "your-cloudflare-api-token"
    }
  }
  
  monitoring = {
    secret_name = "monitoring"
    secret_data = {
      GRAFANA_OIDC_SECRET    = "your-grafana-oidc-secret"
      GRAFANA_ADMIN_PASSWORD = "GrafanaAdminPass123!"
    }
  }
}
```

**Terraform OCI Vault Resource:**

```hcl
resource "oci_vault_secret" "application_secret" {
  for_each = var.application_secrets

  compartment_id = var.compartment_id
  vault_id       = oci_kms_vault.platform_vault.id
  key_id         = oci_kms_key.master_key.id
  secret_name    = each.value.secret_name
  
  secret_content {
    content_type = "BASE64"
    content      = base64encode(jsonencode(each.value.secret_data))
  }
}
```

**Apply Terraform:**

```bash
cd terraform/oci-vault
terraform init
terraform plan -var-file="secrets.tfvars"
terraform apply -var-file="secrets.tfvars"
```

> **Note:** Store `secrets.tfvars` securely (e.g., in a secrets manager or encrypted file). Never commit to version control.

### Step 3: Connect to OKE Cluster

```bash
# Generate kubeconfig
oci ce cluster create-kubeconfig \
  --cluster-id ocid1.cluster.oc1.il-jerusalem-1.aaaaaaaajy4hwcxv2nk5clftclqyly4fjohx3sfduksy3ff5ucputrcdhzmq \
  --file ~/.kube/config \
  --region il-jerusalem-1 \
  --token-version 2.0.0

# Verify connection
kubectl get nodes
```

### Step 4: Install Prerequisites

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

# Wait for cert-manager pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=120s

# Install External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace \
  --set installCRDs=true

# Install NGINX Ingress Controller (NodePort mode)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443
```

### Step 5: Bootstrap ArgoCD

```bash
# Install ArgoCD (minimal bootstrap)
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm

helm install argocd argo/argo-cd -n argocd \
  --set server.service.type=NodePort \
  --set server.service.nodePortHttp=30081 \
  --set server.service.nodePortHttps=30444 \
  --set server.extraArgs="{--insecure}" \
  --set dex.enabled=false

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD via edge proxy (after configuring NGINX)
echo "ArgoCD URL: https://argocd.yourdomain.com"
```

### Step 6: Apply ClusterSecretStore

Update the vault OCID in `apps/oci-staging/cluster-secret-store.yaml`:

```yaml
spec:
  provider:
    oracle:
      vault: "ocid1.vault.oc1.il-jerusalem-1.YOUR_ACTUAL_VAULT_OCID"
      region: "il-jerusalem-1"
```

Apply:

```bash
kubectl apply -f apps/oci-staging/cluster-secret-store.yaml

# Verify
kubectl get clustersecretstore oci-vault
```

### Step 7: Configure Edge Proxy

SSH to edge proxy and configure NGINX upstreams:

```bash
ssh opc@129.159.146.2

# Get OKE node private IPs
# (Run from your local machine with kubectl access)
kubectl get nodes -o wide
# Note the INTERNAL-IP addresses (e.g., 10.0.20.X, 10.0.20.Y)

# On edge proxy, edit NGINX config
sudo vi /etc/nginx/nginx.conf
```

Update upstream blocks:

```nginx
upstream k8s_ingress_http {
    server 10.0.20.X:30080;  # Replace with actual node IP
    server 10.0.20.Y:30080;  # Replace with actual node IP
}

upstream k8s_ingress_https {
    server 10.0.20.X:30443;
    server 10.0.20.Y:30443;
}

server {
    listen 80;
    listen [::]:80;
    server_name _;

    location / {
        proxy_pass http://k8s_ingress_http;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name _;

    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;

    location / {
        proxy_pass https://k8s_ingress_https;
        proxy_ssl_verify off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

Reload NGINX:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Step 8: Deploy Applications via ArgoCD

Update domain in values files, then deploy:

```bash
# Update your domain in all values.oci-staging.yaml files
# Replace "yourdomain.com" with your actual domain

# Apply ArgoCD applications
kubectl apply -f apps/oci-staging/platform-ingress.yaml
kubectl apply -f apps/oci-staging/keycloak.yaml
kubectl apply -f apps/oci-staging/monitoring-stack.yaml
kubectl apply -f apps/oci-staging/flask-backend.yaml
kubectl apply -f apps/oci-staging/argocd.yaml

# Or use App-of-Apps pattern (create app-of-apps.yaml)
```

### Step 9: Verify Let's Encrypt Certificates

```bash
# Check ClusterIssuer
kubectl get clusterissuer letsencrypt-prod

# Check Certificate requests
kubectl get certificaterequests -A

# Check Certificates
kubectl get certificates -A

# Check for any issues
kubectl describe certificate -n ingress-nginx
kubectl logs -n cert-manager -l app=cert-manager
```

### Step 10: Post-Deployment Configuration

1. **Configure Keycloak Realm**:
   - Access `https://keycloak.yourdomain.com`
   - Create `platform` realm
   - Create clients: `flask-backend`, `argocd`, `grafana`
   - Create groups: `/platform-admins`, `/developers`, `/grafana-admins`

2. **Enable Cloudflare Proxy** (optional):
   - After TLS is working, enable orange cloud for WAF/DDoS protection
   - Set SSL/TLS mode to "Full (Strict)" in Cloudflare

3. **Configure Grafana OAuth**:
   - Update Keycloak client secret in OCI Vault
   - Sync via External Secrets

---

## OCI Vault Secrets Reference

Secrets are organized as **one JSON blob per application** (created by Terraform `application_secrets`):

### `flask-app` Secret

All Flask application secrets consolidated in one vault secret:

| Key | Description |
|-----|-------------|
| `SECRET_KEY` | Flask secret key for sessions |
| `API_TEST_KEY` | API test mode key |
| `DB_USER` | Database username (e.g., `flask_user`) |
| `DB_PASSWORD` | Database password |
| `DB_HOST` | ATP hostname (e.g., `adb.il-jerusalem-1.oraclecloud.com`) |
| `DB_PORT` | Database port (`1521`) |
| `DB_NAME` | Database service name (e.g., `stagingdb_high`) |
| `DATABASE_ENCRYPTION_KEY_V1` | Fernet encryption key for data at rest |
| `CURRENT_KEY_VERSION` | Current encryption key version (`v1`) |
| `JWT_PRIVATE_KEY` | RSA private key for JWT signing (PEM format) |
| `JWT_PUBLIC_KEY` | RSA public key for JWT verification (PEM format) |
| `OIDC_CLIENT_ID` | Keycloak client ID (`flask-backend`) |
| `OIDC_CLIENT_SECRET` | Keycloak client secret |

### `keycloak` Secret

Keycloak identity provider secrets:

| Key | Description |
|-----|-------------|
| `admin_user` | Keycloak admin username |
| `admin_password` | Keycloak admin password |
| `DB_USER` | Database username (e.g., `keycloak`) |
| `DB_PASSWORD` | Database password |
| `DB_HOST` | ATP hostname |
| `DB_PORT` | Database port (`1521`) |
| `DB_NAME` | Database service name (e.g., `stagingdb_high`) |
| `flask_backend_secret` | OIDC client secret for Flask |
| `grafana_secret` | OIDC client secret for Grafana |
| `argocd_secret` | OIDC client secret for ArgoCD |

### `cloudflare` Secret

Cloudflare API credentials for DNS01 challenge:

| Key | Description |
|-----|-------------|
| `CLOUDFLARE_API_TOKEN` | API token with Zone:DNS:Edit permissions |
| `CLOUDFLARE_EMAIL` | Cloudflare account email |
| `CLOUDFLARE_ZONE_ID` | Zone ID for the domain |

### `monitoring` Secret

Grafana and monitoring secrets:

| Key | Description |
|-----|-------------|
| `GRAFANA_ADMIN_USER` | Grafana admin username |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password |
| `GRAFANA_OIDC_CLIENT_ID` | Keycloak client ID for Grafana |
| `GRAFANA_OIDC_SECRET` | Keycloak client secret for Grafana |

---

## Troubleshooting

### DNS Not Resolving

```bash
# Check DNS propagation
dig +short yourdomain.com
dig +short argocd.yourdomain.com

# Should return: 129.159.146.2
```

### Let's Encrypt Certificate Fails

```bash
# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager -f

# Check challenge status
kubectl get challenges -A
kubectl describe challenge -n ingress-nginx <challenge-name>

# Verify Cloudflare token has correct permissions
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

### External Secrets Not Syncing

```bash
# Check ExternalSecret status
kubectl get externalsecrets -A
kubectl describe externalsecret <name> -n <namespace>

# Check ESO logs
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

### ATP Connection Issues

```bash
# Test wallet mount
kubectl exec -it <pod-name> -n backend -- ls -la /opt/oracle/wallet

# Test connection from pod
kubectl exec -it <pod-name> -n backend -- python -c "
import sqlalchemy
engine = sqlalchemy.create_engine('postgresql://...')
print(engine.connect())
"
```

---

## Files Created/Modified

### New Files

| File | Description |
|------|-------------|
| `apps/oci-staging/cluster-secret-store.yaml` | OCI Vault ClusterSecretStore |
| `apps/oci-staging/flask-backend.yaml` | Flask ArgoCD Application |
| `apps/oci-staging/keycloak.yaml` | Keycloak ArgoCD Application |
| `apps/oci-staging/platform-ingress.yaml` | Ingress ArgoCD Application |
| `apps/oci-staging/monitoring-stack.yaml` | Monitoring ArgoCD Application |
| `apps/oci-staging/argocd.yaml` | ArgoCD self-management Application |
| `apps/oci-staging/README.md` | OCI staging environment README |
| `helm-charts/flask-app/values.oci-staging.yaml` | Flask OCI-specific values |
| `helm-charts/flask-app/templates/external-secret-atp-wallet.yaml` | ATP wallet ExternalSecret |
| `helm-charts/keycloak/values.oci-staging.yaml` | Keycloak OCI-specific values |
| `helm-charts/keycloak/templates/external-secret-atp-wallet.yaml` | Keycloak ATP wallet ExternalSecret |
| `helm-charts/keycloak/templates/external-secret-atp-credentials.yaml` | Keycloak ATP credentials ExternalSecret |
| `helm-charts/platform-ingress/values.oci-staging.yaml` | Ingress OCI-specific values |
| `helm-charts/platform-ingress/templates/letsencrypt-issuer.yaml` | Let's Encrypt ClusterIssuer |
| `helm-charts/platform-ingress/templates/cloudflare-secret.yaml` | Cloudflare token ExternalSecret |
| `helm-charts/monitoring-stack/values.oci-staging.yaml` | Monitoring OCI-specific values |
| `helm-charts/argocd/Chart.yaml` | ArgoCD Helm chart |
| `helm-charts/argocd/values.yaml` | ArgoCD default values |
| `helm-charts/argocd/values.oci-staging.yaml` | ArgoCD OCI-specific values |
| `helm-charts/argocd/templates/_helpers.tpl` | ArgoCD Helm helpers |
| `helm-charts/argocd/templates/external-secret-oidc.yaml` | ArgoCD OIDC ExternalSecret |

### Modified Files

| File | Change |
|------|--------|
| `helm-charts/flask-app/templates/external-secret-database.yaml` | Added PostgreSQL support alongside MySQL |

---

## Next Steps

1. [ ] Update all `yourdomain.com` placeholders with your actual domain
2. [ ] Update OCI Vault OCID in `cluster-secret-store.yaml`
3. [ ] Create all required secrets in OCI Vault
4. [ ] Configure Cloudflare DNS records
5. [ ] Apply IAM policies for OKE vault access
6. [ ] Deploy and verify certificates
7. [ ] Configure Keycloak realm and clients
8. [ ] Test full authentication flow
