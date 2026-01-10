#!/bin/bash
# ==============================================================================
# Get Ingress Endpoint
# ==============================================================================
# Detects the ingress endpoint based on cluster type:
#   - Kind/MetalLB: Returns IP address (nip.io compatible)
#   - EKS: Returns NLB DNS hostname
#   - NodePort: Returns localhost with port
#
# Usage: ./scripts/get-ingress-endpoint.sh
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Try to get LoadBalancer IP (kind with MetalLB)
get_loadbalancer_ip() {
    kubectl get svc -n ingress-nginx ingress-nginx-controller \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null
}

# Try to get LoadBalancer hostname (EKS)
get_loadbalancer_hostname() {
    kubectl get svc -n ingress-nginx ingress-nginx-controller \
        -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null
}

# Try to get NodePort
get_nodeport() {
    kubectl get svc -n ingress-nginx ingress-nginx-controller \
        -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}' 2>/dev/null
}

# Detect cluster type
detect_cluster_type() {
    local context
    context=$(kubectl config current-context 2>/dev/null)
    
    if [[ "$context" == *"kind"* ]]; then
        echo "kind"
    elif [[ "$context" == *"eks"* ]] || [[ "$context" == *"aws"* ]]; then
        echo "eks"
    elif [[ "$context" == *"minikube"* ]]; then
        echo "minikube"
    else
        echo "unknown"
    fi
}

main() {
    local cluster_type
    local ip
    local hostname
    local nodeport
    
    cluster_type=$(detect_cluster_type)
    
    echo -e "${GREEN}Cluster Type:${NC} $cluster_type"
    echo -e "${GREEN}Context:${NC} $(kubectl config current-context)"
    echo ""
    
    # Try LoadBalancer IP first (kind with MetalLB)
    ip=$(get_loadbalancer_ip)
    if [[ -n "$ip" ]]; then
        echo -e "${GREEN}LoadBalancer IP:${NC} $ip"
        echo -e "${GREEN}nip.io Domain:${NC} platform.${ip//./-}.nip.io"
        echo ""
        echo "Access via:"
        echo "  http://platform.${ip//./-}.nip.io/keycloak"
        echo "  http://platform.${ip//./-}.nip.io/argo"
        echo "  http://platform.${ip//./-}.nip.io/grafana"
        exit 0
    fi
    
    # Try LoadBalancer hostname (EKS)
    hostname=$(get_loadbalancer_hostname)
    if [[ -n "$hostname" ]]; then
        echo -e "${GREEN}LoadBalancer DNS:${NC} $hostname"
        echo -e "${YELLOW}Note:${NC} nip.io not compatible with DNS hostnames"
        echo ""
        echo "Configure Route53 CNAME record:"
        echo "  platform.example.com -> $hostname"
        echo ""
        echo "Or add to /etc/hosts (get IP via dig):"
        echo "  dig +short $hostname"
        exit 0
    fi
    
    # Try NodePort
    nodeport=$(get_nodeport)
    if [[ -n "$nodeport" ]]; then
        echo -e "${GREEN}NodePort:${NC} $nodeport"
        echo ""
        echo "Access via:"
        echo "  http://localhost:$nodeport/keycloak"
        echo "  http://localhost:$nodeport/argo"
        echo "  http://localhost:$nodeport/grafana"
        exit 0
    fi
    
    # Fallback to port-forward instructions
    echo -e "${YELLOW}No ingress endpoint found${NC}"
    echo ""
    echo "Use port-forward instead:"
    echo "  kubectl port-forward -n platform-ingress svc/platform-ingress 8080:80"
    echo ""
    echo "Then access:"
    echo "  http://localhost:8080/keycloak"
    echo "  http://localhost:8080/argo"
    echo "  http://localhost:8080/grafana"
}

main "$@"
