# Local Environment - Kind Cluster with nip.io & MetalLB

This directory contains ArgoCD Applications for **local kind clusters** provisioned via Terragrunt.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Local Development Stack                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                │
│  │   Browser    │────▶│   MetalLB    │────▶│ nginx-ingress│                │
│  │              │     │ LoadBalancer │     │  Controller  │                │
│  └──────────────┘     │ 172.18.255.x │     └──────┬───────┘                │
│                       └──────────────┘            │                         │
│                                                   ▼                         │
│  ┌────────────────────────────────────────────────────────────────┐        │
│  │              platform.172.18.255.200.nip.io                    │        │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────┐       │        │
│  │  │/keycloak│  │  /argo  │  │/grafana │  │ /prometheus │       │        │
│  │  └────┬────┘  └────┬────┘  └────┬────┘  └──────┬──────┘       │        │
│  └───────┼────────────┼───────────┼──────────────┼───────────────┘        │
│          ▼            ▼           ▼              ▼                         │
│  ┌──────────────┐ ┌─────────┐ ┌─────────┐ ┌────────────┐                  │
│  │   Keycloak   │ │ ArgoCD  │ │ Grafana │ │ Prometheus │                  │
│  └──────┬───────┘ └─────────┘ └─────────┘ └────────────┘                  │
│         │                                                                   │
│         ▼                                                                   │
│  ┌──────────────────────────────────────────────────────────────────┐      │
│  │                    External Secrets Operator                      │      │
│  │                              │                                    │      │
│  │                              ▼                                    │      │
│  │  ┌──────────────────────────────────────────────────────────┐   │      │
│  │  │              LocalStack (AWS Emulation)                   │   │      │
│  │  │                  Secrets Manager                          │   │      │
│  │  └──────────────────────────────────────────────────────────┘   │      │
│  └──────────────────────────────────────────────────────────────────┘      │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Environment Parity

| Aspect | Local | Staging | Production |
|--------|-------|---------|------------|
| **Domain** | `platform.<IP>.nip.io` | `platform.staging.local` | `platform.example.com` |
| **TLS** | Disabled (HTTP) | Self-signed certs | Let's Encrypt |
| **Secrets Backend** | LocalStack | AWS Secrets Manager | AWS Secrets Manager |
| **Helm Values** | `values.stage.yaml` | `values.stage.yaml` | `values.prod.yaml` |
| **Ingress Class** | nginx | nginx | nginx |
| **LoadBalancer** | MetalLB | AWS NLB | AWS NLB |

> **Key Principle**: Local reuses `values.stage.yaml` everywhere except `platform-ingress` which adds `values.local.yaml` for domain/TLS overrides.

## nip.io DNS Strategy

[nip.io](https://nip.io) provides wildcard DNS resolution without `/etc/hosts`:

```
*.172.18.255.200.nip.io  →  172.18.255.200
```

**How it works:**
1. MetalLB assigns LoadBalancer IP (e.g., `172.18.255.200`)
2. nginx-ingress gets this IP
3. Domain `platform.172.18.255.200.nip.io` resolves to `172.18.255.200`
4. Ingress routes `/keycloak`, `/argo`, `/grafana`, `/prometheus`

## Terragrunt MetalLB Configuration

Add to your Terragrunt local environment module:

### `terragrunt/environments/local/metallb/terragrunt.hcl`

```hcl
terraform {
  source = "${get_parent_terragrunt_dir()}/modules//metallb"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "kind" {
  config_path = "../kind-cluster"
}

inputs = {
  kubeconfig_path = dependency.kind.outputs.kubeconfig_path
  
  # MetalLB IP address pool - must be within Docker network range
  # Get Docker network CIDR: docker network inspect kind | jq '.[0].IPAM.Config[0].Subnet'
  ip_address_pool = {
    name       = "default"
    protocol   = "layer2"
    addresses  = ["172.18.255.200-172.18.255.250"]
  }
}
```

### `terragrunt/modules/metallb/main.tf`

```hcl
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

variable "kubeconfig_path" {
  type = string
}

variable "ip_address_pool" {
  type = object({
    name      = string
    protocol  = string
    addresses = list(string)
  })
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

provider "kubectl" {
  config_path = var.kubeconfig_path
}

# Install MetalLB
resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = "0.14.5"
  namespace        = "metallb-system"
  create_namespace = true

  wait = true
  timeout = 300
}

# Wait for MetalLB controller to be ready
resource "time_sleep" "wait_for_metallb" {
  depends_on = [helm_release.metallb]
  create_duration = "30s"
}

# Configure IP Address Pool
resource "kubectl_manifest" "ip_address_pool" {
  depends_on = [time_sleep.wait_for_metallb]
  
  yaml_body = <<-YAML
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: ${var.ip_address_pool.name}
      namespace: metallb-system
    spec:
      addresses:
        ${indent(8, yamlencode(var.ip_address_pool.addresses))}
  YAML
}

# Configure L2 Advertisement
resource "kubectl_manifest" "l2_advertisement" {
  depends_on = [kubectl_manifest.ip_address_pool]
  
  yaml_body = <<-YAML
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
      name: default
      namespace: metallb-system
    spec:
      ipAddressPools:
        - ${var.ip_address_pool.name}
  YAML
}

output "ip_pool_range" {
  value = var.ip_address_pool.addresses
}
```

### `terragrunt/environments/local/localstack/terragrunt.hcl`

```hcl
terraform {
  source = "${get_parent_terragrunt_dir()}/modules//localstack"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "kind" {
  config_path = "../kind-cluster"
}

inputs = {
  kubeconfig_path = dependency.kind.outputs.kubeconfig_path
  
  # Secrets to populate in LocalStack
  secrets = {
    "staging/backend/database-url"  = "postgresql://flask:localpassword@postgres:5432/flask_local"
    "staging/backend/flask-key"     = "local-dev-secret-key"
    "staging/keycloak/admin-user"   = "admin"
    "staging/keycloak/admin-password" = "localadminpassword"
  }
}
```

### `terragrunt/modules/localstack/main.tf`

```hcl
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

variable "kubeconfig_path" {
  type = string
}

variable "secrets" {
  type = map(string)
  default = {}
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

# Deploy LocalStack
resource "helm_release" "localstack" {
  name             = "localstack"
  repository       = "https://localstack.github.io/helm-charts"
  chart            = "localstack"
  version          = "0.6.14"
  namespace        = "localstack"
  create_namespace = true

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "startServices"
    value = "secretsmanager"
  }
}

# Create ESO credentials secret for LocalStack
resource "kubernetes_secret" "localstack_credentials" {
  metadata {
    name      = "localstack-credentials"
    namespace = "external-secrets"
  }

  data = {
    "access-key" = "test"      # LocalStack default
    "secret-key" = "test"      # LocalStack default
    "endpoint"   = "http://localstack.localstack.svc.cluster.local:4566"
  }

  depends_on = [helm_release.localstack]
}

# Populate secrets in LocalStack
resource "null_resource" "populate_secrets" {
  for_each = var.secrets

  provisioner "local-exec" {
    command = <<-EOT
      kubectl exec -n localstack deploy/localstack -- \
        awslocal secretsmanager create-secret \
          --name "${each.key}" \
          --secret-string "${each.value}" \
        || kubectl exec -n localstack deploy/localstack -- \
        awslocal secretsmanager put-secret-value \
          --secret-id "${each.key}" \
          --secret-string "${each.value}"
    EOT
  }

  depends_on = [helm_release.localstack]
}

output "endpoint" {
  value = "http://localstack.localstack.svc.cluster.local:4566"
}
```

## Quick Start

### 1. Provision Local Infrastructure (Terragrunt)

```bash
cd terragrunt/environments/local

# Create kind cluster
terragrunt run-all apply --terragrunt-include-dir kind-cluster

# Install MetalLB
terragrunt run-all apply --terragrunt-include-dir metallb

# Install LocalStack + ESO
terragrunt run-all apply --terragrunt-include-dir localstack
terragrunt run-all apply --terragrunt-include-dir external-secrets

# Install nginx-ingress
terragrunt run-all apply --terragrunt-include-dir nginx-ingress
```

### 2. Get MetalLB IP & Update Domain

```bash
# Wait for nginx-ingress LoadBalancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller -w

# Once IP is assigned (e.g., 172.18.255.200):
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Update helm-charts/platform-ingress/values.local.yaml:"
echo "  domain: platform.${INGRESS_IP}.nip.io"
```

### 3. Deploy Applications

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply local applications
kubectl apply -f apps/local/

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 4. Access Services

```bash
# Example with IP 172.18.255.200
open http://platform.172.18.255.200.nip.io/argo
open http://platform.172.18.255.200.nip.io/keycloak
open http://platform.172.18.255.200.nip.io/grafana
open http://platform.172.18.255.200.nip.io/prometheus
```

## Fallback: Port Forwarding

If MetalLB isn't available or nip.io doesn't resolve:

```bash
kubectl port-forward -n platform-ingress svc/platform-ingress 8080:80

# Access at:
open http://localhost:8080/argo
open http://localhost:8080/keycloak
open http://localhost:8080/grafana
```

## Troubleshooting

### MetalLB not assigning IP

```bash
# Check MetalLB controller logs
kubectl logs -n metallb-system -l app.kubernetes.io/component=controller

# Verify IPAddressPool exists
kubectl get ipaddresspool -n metallb-system

# Verify L2Advertisement exists
kubectl get l2advertisement -n metallb-system
```

### nip.io DNS not resolving

```bash
# Test DNS resolution
nslookup platform.172.18.255.200.nip.io

# If blocked, try sslip.io instead (alternative service)
# Update values.local.yaml: domain: platform.172.18.255.200.sslip.io
```

### LocalStack secrets not syncing

```bash
# Check LocalStack is running
kubectl get pods -n localstack

# List secrets in LocalStack
kubectl exec -n localstack deploy/localstack -- awslocal secretsmanager list-secrets

# Check ESO ClusterSecretStore status
kubectl get clustersecretstore aws-secrets-manager -o yaml
```

