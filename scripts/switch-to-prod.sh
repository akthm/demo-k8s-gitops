#!/bin/bash
# ==============================================================================
# Switch to Production Environment (AWS EKS)
# ==============================================================================
# This script helps configure kubectl for production EKS cluster.
#
# Usage: ./scripts/switch-to-prod.sh [--apply]
#
# Options:
#   --apply    Apply production ArgoCD applications
#
# Prerequisites:
#   - AWS CLI configured with production credentials
#   - kubectl installed
#   - EKS cluster already provisioned
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration - Update these for your environment
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-prod-cluster}"
AWS_REGION="${AWS_REGION:-ap-south-1}"

# Check AWS CLI
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Run 'aws configure' first."
        exit 1
    fi
    
    log_info "AWS CLI configured"
    aws sts get-caller-identity --query 'Arn' --output text
}

# Update kubeconfig for EKS
update_kubeconfig() {
    log_info "Updating kubeconfig for EKS cluster: $EKS_CLUSTER_NAME"
    
    aws eks update-kubeconfig \
        --name "$EKS_CLUSTER_NAME" \
        --region "$AWS_REGION"
    
    log_info "kubeconfig updated successfully"
}

# Verify cluster connectivity
verify_cluster() {
    log_info "Verifying cluster connectivity..."
    
    if kubectl cluster-info &> /dev/null; then
        log_info "Connected to cluster:"
        kubectl cluster-info | head -n 1
    else
        log_error "Cannot connect to cluster"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check nginx-ingress-controller
    if kubectl get svc -n ingress-nginx ingress-nginx-controller &> /dev/null; then
        log_info "✓ nginx-ingress-controller found"
        INGRESS_HOSTNAME=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
        log_info "  NLB DNS: $INGRESS_HOSTNAME"
    else
        log_warn "✗ nginx-ingress-controller not found"
    fi
    
    # Check cert-manager
    if kubectl get ns cert-manager &> /dev/null; then
        log_info "✓ cert-manager namespace found"
    else
        log_warn "✗ cert-manager not found - TLS certificates won't work"
    fi
    
    # Check external-secrets
    if kubectl get ns external-secrets &> /dev/null; then
        log_info "✓ external-secrets namespace found"
    else
        log_warn "✗ external-secrets not found - Secrets won't sync from AWS"
    fi
    
    # Check ArgoCD
    if kubectl get ns argocd &> /dev/null; then
        log_info "✓ argocd namespace found"
    else
        log_warn "✗ argocd not found - Install ArgoCD first"
    fi
}

# Apply production ArgoCD applications
apply_prod_apps() {
    log_info "Applying production ArgoCD applications..."
    
    for app in "$PROJECT_ROOT/apps/prod/"*.yaml; do
        if [[ "$(basename "$app")" != "README.md" ]]; then
            log_info "Applying $(basename "$app")..."
            kubectl apply -f "$app"
        fi
    done
    
    log_info "Production applications applied"
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
    echo " Switching to Production Environment (EKS)"
    echo "=============================================="
    echo ""
    log_warn "⚠️  You are about to connect to PRODUCTION!"
    echo ""
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborted"
        exit 0
    fi
    
    check_aws_cli
    update_kubeconfig
    verify_cluster
    check_prerequisites
    
    if $apply_apps; then
        echo ""
        log_warn "⚠️  About to apply production applications!"
        read -p "Are you sure? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            apply_prod_apps
        fi
    fi
    
    echo ""
    echo "=============================================="
    echo " Production Environment Ready"
    echo "=============================================="
    echo ""
    echo "Next steps:"
    echo "  1. Configure DNS in Route53 to point to NLB"
    echo "  2. Verify secrets in AWS Secrets Manager"
    echo "  3. Apply applications: ./scripts/switch-to-prod.sh --apply"
    echo ""
    echo "Access (after DNS setup):"
    echo "  - ArgoCD:     https://platform.example.com/argo"
    echo "  - Keycloak:   https://platform.example.com/keycloak"
    echo "  - Grafana:    https://platform.example.com/grafana"
    echo "  - Prometheus: https://platform.example.com/prometheus"
    echo ""
}

main "$@"
