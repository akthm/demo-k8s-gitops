#!/bin/bash
set -e

echo "=================================================="
echo "Secrets Monitoring Validation Script"
echo "=================================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: kube-state-metrics
echo "1. Checking kube-state-metrics..."
if kubectl get pods -n monitoring -l app.kubernetes.io/name=kube-state-metrics | grep -q Running; then
    echo -e "${GREEN}✓${NC} kube-state-metrics is running"
else
    echo -e "${RED}✗${NC} kube-state-metrics is NOT running"
    exit 1
fi

# Test 2: ESO Metrics Service
echo "2. Checking External Secrets Operator metrics Service..."
if kubectl get svc -n external-secrets external-secrets-metrics &>/dev/null; then
    ENDPOINTS=$(kubectl get endpoints -n external-secrets external-secrets-metrics -o jsonpath='{.subsets[0].addresses}' | jq length)
    if [ "$ENDPOINTS" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} ESO metrics Service exists with $ENDPOINTS endpoints"
    else
        echo -e "${YELLOW}⚠${NC} ESO metrics Service exists but has no endpoints"
    fi
else
    echo -e "${RED}✗${NC} ESO metrics Service does NOT exist"
fi

# Test 3: Dashboard ConfigMap
echo "3. Checking dashboard ConfigMap..."
if kubectl get cm flask-app-dashboard-rotation -n backend &>/dev/null; then
    DASHBOARD=$(kubectl get cm flask-app-dashboard-rotation -n backend -o jsonpath='{.data}' | jq -r 'keys[0]')
    if [ "$DASHBOARD" == "secrets-monitoring-final.json" ]; then
        echo -e "${GREEN}✓${NC} Dashboard ConfigMap deployed: $DASHBOARD"
    else
        echo -e "${YELLOW}⚠${NC} Dashboard ConfigMap exists but has wrong file: $DASHBOARD"
    fi
else
    echo -e "${RED}✗${NC} Dashboard ConfigMap does NOT exist"
fi

# Test 4: Prometheus Targets
echo "4. Checking Prometheus targets..."
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9092:9090 &>/dev/null &
PF_PID=$!
sleep 3

# Check kube-state-metrics target
KSM_STATUS=$(curl -s 'http://localhost:9092/api/v1/targets' | jq -r '.data.activeTargets[] | select(.labels.job == "kube-state-metrics") | .health')
if [ "$KSM_STATUS" == "up" ]; then
    echo -e "${GREEN}✓${NC} kube-state-metrics target is UP"
else
    echo -e "${RED}✗${NC} kube-state-metrics target is ${KSM_STATUS:-MISSING}"
fi

# Check ESO target
ESO_STATUS=$(curl -s 'http://localhost:9092/api/v1/targets' | jq -r '.data.activeTargets[] | select(.labels.job == "external-secrets-metrics") | .health')
if [ "$ESO_STATUS" == "up" ]; then
    echo -e "${GREEN}✓${NC} external-secrets-metrics target is UP"
else
    echo -e "${YELLOW}⚠${NC} external-secrets-metrics target is ${ESO_STATUS:-MISSING}"
fi

# Test 5: Query Backend Secrets
echo "5. Querying backend secrets from Prometheus..."
SECRET_COUNT=$(curl -s 'http://localhost:9092/api/v1/query?query=kube_secret_info' | jq '.data.result[] | select(.metric.namespace == "backend")' | jq -s length)
if [ "$SECRET_COUNT" -ge 5 ]; then
    echo -e "${GREEN}✓${NC} Found $SECRET_COUNT secrets in backend namespace"
else
    echo -e "${RED}✗${NC} Expected at least 5 secrets, found $SECRET_COUNT"
fi

# Cleanup
kill $PF_PID &>/dev/null

echo ""
echo "=================================================="
echo "Validation Complete!"
echo "=================================================="
echo ""
echo "Next Steps:"
echo "1. Access Grafana:"
echo "   kubectl port-forward -n monitoring svc/prometheus-grafana 3001:80"
echo "   URL: http://localhost:3001"
echo "   Username: admin"
echo "   Password: changeme-staging"
echo ""
echo "2. Search for dashboard: 'Secrets & External Secrets Monitoring'"
echo ""
echo "3. Verify panels show data"
echo ""
