#!/bin/bash
# ==============================================================================
# Switch to Local Environment (Kind Cluster)
# ==============================================================================
# This script helps configure and deploy to the local kind cluster.
# Infrastructure is provisioned by Terragrunt (MetalLB, LocalStack, ESO).
#
# Usage: ./scripts/switch-to-local.sh [--apply]
#
# Options:
#   --apply    Apply ArgoCD applications after switching context
#
# Prerequisites (provisioned by Terragrunt):
#   - Kind cluster with kubectl context configured
#   - MetalLB for LoadBalancer IP assignment
#   - LocalStack for AWS Secrets Manager emulation
#   - nginx-ingress-controller
#   - External Secrets Operator
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check if kind cluster exists
check_kind_cluster() {
    if kind get clusters 2>/dev/null | grep -q "^kind$"; then
        log_info "✓ Kind cluster 'kind' found"
        return 0
    else
        log_error "✗ Kind cluster not found"
        log_warn "Run Terragrunt to provision: cd terragrunt/environments/local && terragrunt run-all apply"
        return 1
    fi
}

# Check MetalLB
check_metallb() {
    if kubectl get ns metallb-system &>/dev/null; then
        log_info "✓ MetalLB namespace found"
        
        # Check if IPAddressPool exists
        if kubectl get ipaddresspool -n metallb-system &>/dev/null; then
            log_info "✓ MetalLB IPAddressPool configured"
        else
            log_warn "✗ MetalLB IPAddressPool not configured"
        fi
    else
        log_warn "✗ MetalLB not found - LoadBalancer IPs won't work"
    fi
}

# Check nginx-ingress and get IP
check_ingress() {
    if kubectl get svc -n ingress-nginx ingress-nginx-controller &>/dev/null; then
        log_info "✓ nginx-ingress-controller found"
        
        INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        
        if [[ -n "$INGRESS_IP" ]]; then
            log_info "✓ LoadBalancer IP: $INGRESS_IP"
            log_info "  nip.io domain: platform.${INGRESS_IP}.nip.io"
            
            # Check if values.local.yaml has the correct domain
            CURRENT_DOMAIN=$(grep "^domain:" "$PROJECT_ROOT/helm-charts/platform-ingress/values.local.yaml" | awk '{print $2}')
            EXPECTED_DOMAIN="platform.${INGRESS_IP}.nip.io"
            
            if [[ "$CURRENT_DOMAIN" != "$EXPECTED_DOMAIN" ]]; then
                log_warn "⚠ Update helm-charts/platform-ingress/values.local.yaml:"
                log_warn "  Current:  domain: $CURRENT_DOMAIN"
                log_warn "  Expected: domain: $EXPECTED_DOMAIN"
            fi
        else
            log_warn "✗ LoadBalancer IP not assigned yet"
            log_warn "  Waiting for MetalLB to assign IP..."
        fi
    else
        log_warn "✗ nginx-ingress-controller not found"
    fi
}

# Check LocalStack
check_localstack() {
    if kubectl get ns localstack &>/dev/null; then
        log_info "✓ LocalStack namespace found"
        
        if kubectl get pods -n localstack -l app.kubernetes.io/name=localstack --field-selector=status.phase=Running 2>/dev/null | grep -q localstack; then
            log_info "✓ LocalStack pod running"
        else
            log_warn "✗ LocalStack pod not ready"
        fi
    else
        log_warn "✗ LocalStack not found - ESO won't work"
    fi
}

# Check External Secrets Operator
check_eso() {
    if kubectl get ns external-secrets &>/dev/null; then
        log_info "✓ External Secrets Operator namespace found"
        
        if kubectl get clustersecretstore aws-secrets-manager &>/dev/null; then
            log_info "✓ ClusterSecretStore 'aws-secrets-manager' exists"
        else
            log_warn "✗ ClusterSecretStore not configured"
        fi
    else
        log_warn "✗ External Secrets Operator not found"
    fi
}

# Check ArgoCD
check_argocd() {
    if kubectl get ns argocd &>/dev/null; then
        log_info "✓ ArgoCD namespace found"
        return 0
    else
        log_warn "✗ ArgoCD not found"
        return 1
    fi
}

# Apply local ArgoCD applications
apply_local_apps() {
    log_step "Applying local ArgoCD applications..."
    
    for app in "$PROJECT_ROOT/apps/local/"*.yaml; do
        if [[ "$(basename "$app")" != "README.md" ]]; then
            log_info "Applying $(basename "$app")..."
            kubectl apply -f "$app"
        fi
    done
    
    log_info "Local applications applied"
}

# Print access URLs
print_access_urls() {
    INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    echo ""
    echo "=============================================="
    echo " Access URLs"
    echo "=============================================="
    
    if [[ -n "$INGRESS_IP" ]]; then
        echo ""
        echo "nip.io URLs (recommended):"
        echo "  ArgoCD:     http://platform.${INGRESS_IP}.nip.io/argo"
        echo "  Keycloak:   http://platform.${INGRESS_IP}.nip.io/keycloak"
        echo "  Grafana:    http://platform.${INGRESS_IP}.nip.io/grafana"
        echo "  Prometheus: http://platform.${INGRESS_IP}.nip.io/prometheus"
    fi
    
    echo ""
    echo "Port-forward fallback:"
    echo "  kubectl port-forward -n platform-ingress svc/platform-ingress 8080:80"
    echo "  Then: http://localhost:8080/argo"
    echo ""
}

# Main
main() {
    local apply_apps=false
    
    for arg in "$@"; do
        case $arg in
            --apply)
                apply_apps=true
                shift
                ;;
        esac
    done
    
    echo "=============================================="
    echo " Switching to Local Environment (Kind)"
    echo "=============================================="
    echo ""
    
    # Check prerequisites
    check_kind_cluster || exit 1
    
    # Set kubectl context
    kubectl config use-context kind-kind 2>/dev/null || true
    
    echo ""
    log_step "Checking infrastructure components..."
    check_metallb
    check_ingress
    check_localstack
    check_eso
    check_argocd
    
    if $apply_apps; then
        echo ""
        if check_argocd; then
            apply_local_apps
        else
            log_error "ArgoCD not installed. Install it first:"
            log_error "  kubectl create namespace argocd"
            log_error "  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
            exit 1
        fi
    fi
    
    print_access_urls
    
    if ! $apply_apps; then
        echo "To apply applications: ./scripts/switch-to-local.sh --apply"
        echo ""
    fi
}

main "$@"
