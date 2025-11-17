#!/bin/bash
# Deployment validation script for staging environment

set -e

NAMESPACE_BACKEND="backend"
NAMESPACE_FRONTEND="frontend"
TIMEOUT=300
POLL_INTERVAL=5

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

check_namespaces() {
    log_info "Checking namespaces exist..."
    for ns in $NAMESPACE_BACKEND $NAMESPACE_FRONTEND; do
        if kubectl get namespace $ns &>/dev/null; then
            log_info "✓ Namespace '$ns' found"
        else
            log_error "✗ Namespace '$ns' not found"
            return 1
        fi
    done
}

check_pods() {
    local namespace=$1
    local label=$2
    local expected_count=$3
    
    log_info "Checking pods in $namespace with label $label..."
    
    local elapsed=0
    while [ $elapsed -lt $TIMEOUT ]; do
        local running=$(kubectl get pods -n $namespace -l $label -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' | wc -w)
        
        if [ $running -ge $expected_count ]; then
            log_info "✓ Found $running running pod(s)"
            return 0
        fi
        
        echo -ne "  Waiting for pods... ($running/$expected_count) \r"
        sleep $POLL_INTERVAL
        elapsed=$((elapsed + POLL_INTERVAL))
    done
    
    log_error "✗ Timeout waiting for pods"
    return 1
}

check_services() {
    log_info "Checking services..."
    
    for namespace in $NAMESPACE_BACKEND $NAMESPACE_FRONTEND; do
        local services=$(kubectl get svc -n $namespace -o jsonpath='{.items[*].metadata.name}')
        if [ -z "$services" ]; then
            log_warn "No services found in $namespace"
        else
            log_info "✓ Found services in $namespace: $services"
        fi
    done
}

check_health_endpoints() {
    log_info "Checking Flask health endpoint..."
    
    # Port forward to Flask service
    kubectl port-forward -n $NAMESPACE_BACKEND svc/flask-app 8000:8000 &
    local pf_pid=$!
    sleep 2
    
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health | grep -q "200\|404"; then
        log_info "✓ Health endpoint reachable"
        kill $pf_pid 2>/dev/null || true
        return 0
    else
        log_error "✗ Health endpoint not responding"
        kill $pf_pid 2>/dev/null || true
        return 1
    fi
}

check_database() {
    log_info "Checking database connectivity..."
    
    local db_pod=$(kubectl get pod -n $NAMESPACE_BACKEND -l app.kubernetes.io/name=mysql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$db_pod" ]; then
        log_warn "MySQL pod not found (might be external)"
        return 0
    fi
    
    if kubectl exec -n $NAMESPACE_BACKEND $db_pod -- mysql -u root -proot -e "SELECT 1;" &>/dev/null; then
        log_info "✓ Database is accessible"
        return 0
    else
        log_error "✗ Cannot connect to database"
        return 1
    fi
}

check_ingress() {
    log_info "Checking ingress configuration..."
    
    local ingress_status=$(kubectl get ingress -n $NAMESPACE_FRONTEND -o jsonpath='{.items[*].status.ingress[0].ip}' 2>/dev/null)
    
    if [ -z "$ingress_status" ]; then
        log_warn "Ingress IP not assigned yet"
        return 0
    else
        log_info "✓ Ingress IP: $ingress_status"
        return 0
    fi
}

check_rbac() {
    log_info "Checking RBAC configuration..."
    
    for namespace in $NAMESPACE_BACKEND $NAMESPACE_FRONTEND; do
        local sa=$(kubectl get sa -n $namespace -o jsonpath='{.items[*].metadata.name}')
        if [ -z "$sa" ]; then
            log_warn "No service accounts in $namespace"
        else
            log_info "✓ Service accounts in $namespace: $sa"
        fi
    done
}

check_network_policies() {
    log_info "Checking network policies..."
    
    for namespace in $NAMESPACE_BACKEND $NAMESPACE_FRONTEND; do
        local policies=$(kubectl get networkpolicy -n $namespace -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        if [ -z "$policies" ]; then
            log_warn "No network policies in $namespace"
        else
            log_info "✓ Network policies in $namespace: $policies"
        fi
    done
}

main() {
    echo ""
    echo "=========================================="
    echo "  Deployment Validation Script"
    echo "  Staging Environment"
    echo "=========================================="
    echo ""
    
    local errors=0
    
    check_namespaces || ((errors++))
    check_pods $NAMESPACE_BACKEND "app.kubernetes.io/name=flask-app" 1 || ((errors++))
    check_pods $NAMESPACE_FRONTEND "app.kubernetes.io/name=nginx-front" 1 || ((errors++))
    check_services
    check_rbac
    check_network_policies
    
    # Optional health checks
    # check_health_endpoints || ((errors++))
    # check_database || ((errors++))
    # check_ingress
    
    echo ""
    echo "=========================================="
    if [ $errors -eq 0 ]; then
        log_info "All checks passed! ✓"
        echo "=========================================="
        return 0
    else
        log_error "Some checks failed! ✗"
        echo "=========================================="
        return 1
    fi
}

main "$@"
