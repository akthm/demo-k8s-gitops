# Secrets Monitoring - Quick Reference Guide

## 🎯 Access Points

### Grafana Dashboard
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3001:80
```
- **URL:** http://localhost:3001
- **Username:** `admin`
- **Password:** `changeme-staging`
- **Dashboard:** Search for "Secrets & External Secrets Monitoring"

### Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```
- **URL:** http://localhost:9090
- **Targets:** http://localhost:9090/targets

---

## ✅ Verification Commands

### 1. Check kube-state-metrics is Running
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=kube-state-metrics
```
**Expected:** 1 pod in Running state

### 2. Check ESO Metrics Service
```bash
kubectl get svc -n external-secrets external-secrets-metrics
kubectl get endpoints -n external-secrets external-secrets-metrics
```
**Expected:** Service on port 8080 with endpoints

### 3. Query Prometheus for Secrets
```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &

# Query backend secrets
curl -s 'http://localhost:9090/api/v1/query?query=kube_secret_info' | \
  jq '.data.result[] | select(.metric.namespace == "backend") | .metric.secret'
```
**Expected:** List of 5 secrets (flask-app-admin-credentials, flask-app-db, flask-app-db-credentials, flask-app-jwt-keys, flask-app-secret)

### 4. Check Dashboard ConfigMap
```bash
kubectl get cm flask-app-dashboard-rotation -n backend -o jsonpath='{.data}' | jq 'keys'
```
**Expected:** `["secrets-monitoring-final.json"]`

### 5. Verify ServiceMonitors are Scraped
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &
curl -s 'http://localhost:9090/api/v1/targets' | \
  jq -r '.data.activeTargets[] | select(.labels.job | contains("kube-state") or contains("external-secrets")) | {job: .labels.job, health: .health}'
```
**Expected:**
```json
{"job":"kube-state-metrics","health":"up"}
{"job":"external-secrets-metrics","health":"up"}
```

---

## 📊 Dashboard Panels & Queries

### Panel 1: Secrets in Backend Namespace
**Query:** `count(count by (secret) (kube_secret_labels{namespace="backend"}))`  
**Expected Value:** 5  
**Source:** kube-state-metrics

### Panel 2: Pods Running - Backend
**Query:** `count(kube_pod_info{namespace="backend"})`  
**Expected Value:** 2-4 (depending on replicas)  
**Source:** kube-state-metrics

### Panel 3: Container Restarts (24h)
**Query:** `sum(changes(kube_pod_container_status_restarts_total{namespace="backend"}[24h]))`  
**Expected Value:** 0 (or low number)  
**Source:** kube-state-metrics

### Panel 4: Appointments Booked (Optional)
**Query:** `mokhaback_appointments_booked_total`  
**Expected Value:** Data if app exposes metric, otherwise no data  
**Source:** Flask application (requires instrumentation)

---

## 🔧 Troubleshooting

### Dashboard Shows "No Data"

#### Step 1: Check kube-state-metrics Pod
```bash
kubectl get pods -n monitoring | grep kube-state-metrics
```
If not running, check kube-prometheus-stack deployment.

#### Step 2: Check Prometheus Targets
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open: http://localhost:9090/targets
# Look for: serviceMonitor/monitoring/prometheus-kube-state-metrics/0
# Status should be: UP
```

#### Step 3: Test Metric Query
```bash
curl -s 'http://localhost:9090/api/v1/query?query=up{job="kube-state-metrics"}' | jq '.data.result'
```
Should return `"value":["<timestamp>","1"]`

#### Step 4: Check Dashboard was Loaded
```bash
# Restart Grafana to reload dashboards
kubectl rollout restart deployment/prometheus-grafana -n monitoring

# Wait for restart
kubectl rollout status deployment/prometheus-grafana -n monitoring

# Check dashboard exists in ConfigMap
kubectl get cm -n backend | grep dashboard-rotation
```

#### Step 5: Verify Grafana Sidecar Configuration
```bash
kubectl get deployment prometheus-grafana -n monitoring -o yaml | grep -A 10 "sidecar"
```
Should have `SC_LABEL=grafana_dashboard` and `SC_LABEL_VALUE=1`

### ESO Metrics Not Available

#### Check ESO Metrics Service
```bash
kubectl get svc -n external-secrets external-secrets-metrics
```
If missing, ensure `externalSecretsOperator.monitoring.enabled: true` in values.stage.yaml

#### Check ServiceMonitor
```bash
kubectl get servicemonitor -n monitoring external-secrets-operator -o yaml
```
Verify:
- `namespaceSelector.matchNames` includes "external-secrets"
- `endpoints[0].port` == "metrics"

#### Test ESO Metrics Directly
```bash
# Get ESO pod name
ESO_POD=$(kubectl get pods -n external-secrets -l app.kubernetes.io/name=external-secrets -o jsonpath='{.items[0].metadata.name}')

# Port-forward to ESO pod
kubectl port-forward -n external-secrets $ESO_POD 8080:8080 &

# Query metrics
curl -s http://localhost:8080/metrics | grep externalsecret_
```

### Application Metrics Missing

The Flask application doesn't currently expose custom metrics. To add them:

1. Install `prometheus-client` in Flask app
2. Create `/metrics` endpoint
3. Expose metrics: `mokhaback_jwt_key_rotation_timestamp_seconds`, `mokhaback_db_encryption_key_age_seconds`, etc.
4. Ensure ServiceMonitor in backend namespace scrapes Flask app pods

---

## 🚀 Deployment Checklist

- [x] kube-state-metrics enabled in kube-prometheus-stack
- [x] external-secrets-metrics Service created
- [x] Prometheus cross-namespace ServiceMonitor discovery enabled
- [x] secrets-monitoring-final.json dashboard created
- [x] Dashboard ConfigMap deployed to backend namespace
- [x] Grafana restarted to load dashboard
- [x] Metrics verified in Prometheus
- [ ] Application custom metrics instrumentation (future)

---

## 📈 Metrics Available

### From kube-state-metrics (Works Now)
```
kube_secret_info{namespace="backend"}
kube_secret_labels{namespace="backend"}
kube_pod_info{namespace="backend"}
kube_pod_status_phase{namespace="backend"}
kube_pod_container_status_restarts_total{namespace="backend"}
```

### From External Secrets Operator (Works if Service Created)
```
externalsecret_status_condition{name="...", namespace="backend"}
externalsecret_sync_calls_total{name="...", namespace="backend"}
externalsecret_sync_calls_error{name="...", namespace="backend"}
```

### From Flask Application (Requires Instrumentation)
```
mokhaback_jwt_key_rotation_timestamp_seconds
mokhaback_db_encryption_key_age_seconds
mokhaback_appointments_booked_total
mokhaback_sms_queue_depth
mokhaback_appointments_slots_checked_total
```

---

## 📝 Related Documentation

- [SECRETS_MONITORING_IMPLEMENTATION.md](SECRETS_MONITORING_IMPLEMENTATION.md) - Complete implementation guide
- [EXTERNAL_SECRETS_RETRY_CONFIG.md](EXTERNAL_SECRETS_RETRY_CONFIG.md) - External Secrets retry configuration
- [AWS_SECRETS_SETUP.md](docs/AWS_SECRETS_SETUP.md) - LocalStack secrets setup

---

## 🔗 Useful Links

- [Kube-State-Metrics Documentation](https://github.com/kubernetes/kube-state-metrics/tree/main/docs)
- [External Secrets Operator Metrics](https://external-secrets.io/latest/guides-metrics/)
- [Prometheus Querying Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)

---

**Last Updated:** 2024  
**Status:** ✅ Implementation Complete
