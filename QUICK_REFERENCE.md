# Quick Reference - Common Commands

**Use this for quick copy-paste commands during deployment and operations.**

---

## Prerequisites Check

```bash
# Check all components installed
kubectl get deployment -n ingress-nginx nginx-ingress-controller
kubectl get deployment -n external-secrets-system external-secrets
kubectl get deployment -n kube-system metrics-server
kubectl get deployment -n argocd argocd-server

# Verify AWS credentials
aws sts get-caller-identity

# Test git access
git clone https://github.com/your-org/your-gitops-repo.git
cd your-gitops-repo
git checkout staging
```

---

## Initial Setup

```bash
# Make scripts executable
chmod +x setup-staging.sh
chmod +x validate-deployment.sh

# Create AWS secrets (example values)
aws secretsmanager create-secret \
  --name staging/backend/database-url \
  --secret-string "mysql://flask_user:mypassword@flask-app-db:3306/flask_staging" \
  --region ap-south-1

aws secretsmanager create-secret \
  --name staging/backend/flask-key \
  --secret-string "your-very-secret-flask-key-here" \
  --region ap-south-1

# Run setup script
./setup-staging.sh
```

---

## Deployment

```bash
# Deploy via ArgoCD
kubectl apply -f apps/staging/flask-backend.yaml
kubectl apply -f apps/staging/nginx-front.yaml

# OR: Deploy via Helm directly
helm repo update
helm dependency update helm-charts/flask-app/

helm install flask-backend helm-charts/flask-app/ \
  -n backend --create-namespace \
  -f helm-charts/flask-app/values.yaml \
  -f helm-charts/flask-app/values.stage.yaml

helm install nginx-frontend helm-charts/nginx-front/ \
  -n frontend --create-namespace
```

---

## Monitoring & Debugging

```bash
# Watch pods
kubectl get pods -n backend -w
kubectl get pods -n frontend -w

# Check pod status
kubectl get pods -n backend
kubectl get pods -n frontend

# View logs
kubectl logs -n backend -l app.kubernetes.io/name=flask-app --tail=100
kubectl logs -n frontend -l app.kubernetes.io/name=nginx-front --tail=100

# Stream logs
kubectl logs -n backend -l app.kubernetes.io/name=flask-app -f

# Check events
kubectl describe pod -n backend <pod-name>
kubectl describe pod -n frontend <pod-name>

# Check resource usage
kubectl top pods -n backend
kubectl top pods -n frontend
```

---

## Service Connectivity Testing

```bash
# Port forward to Flask
kubectl port-forward -n backend svc/flask-app 8000:8000 &

# Port forward to Nginx
kubectl port-forward -n frontend svc/nginx-frontend 8080:80 &

# Test API health
curl http://localhost:8000/health

# Test frontend
curl http://localhost:8080/

# Test API through proxy
curl http://localhost:8080/api/health
```

---

## Database Operations

```bash
# Get database pod
kubectl get pod -n backend -l app.kubernetes.io/name=mysql

# Access database shell
kubectl exec -it <db-pod> -n backend -- mysql -u root -p

# Check database user
kubectl exec -it <db-pod> -n backend -- mysql -u root -p -e "SELECT User, Host FROM mysql.user;"

# Check databases
kubectl exec -it <db-pod> -n backend -- mysql -u root -p -e "SHOW DATABASES;"

# Backup database
kubectl exec <db-pod> -n backend -- mysqldump -u root -p --all-databases > backup.sql

# Run SQL query
kubectl exec -it <db-pod> -n backend -- mysql -u flask_user -p flask_staging -e "SELECT * FROM users LIMIT 5;"
```

---

## Configuration & Secrets

```bash
# View ConfigMap
kubectl get configmap -n backend
kubectl describe configmap flask-app-config -n backend

# View Secret
kubectl get secret -n backend
kubectl get secret flask-app-secret -n backend -o yaml

# Decode secret value
kubectl get secret flask-app-secret -n backend \
  -o jsonpath='{.data.SECRET_KEY}' | base64 -d

# Check External Secrets status
kubectl get externalsecrets -n backend
kubectl describe externalsecrets flask-app-secret -n backend

# View AWS Secrets Manager integration
kubectl logs -n external-secrets-system -l app=external-secrets
```

---

## Scaling Operations

```bash
# Check current replicas
kubectl get deployment -n backend
kubectl get deployment -n frontend

# Scale manually
kubectl scale deployment flask-app -n backend --replicas=2
kubectl scale deployment nginx-frontend -n frontend --replicas=2

# Enable HPA
kubectl patch values flask-app -n backend \
  -p '{"autoscaling.enabled": true}'

# Check HPA status
kubectl get hpa -n backend
kubectl get hpa -n frontend
kubectl describe hpa flask-app -n backend
```

---

## Networking

```bash
# Check services
kubectl get svc -n backend
kubectl get svc -n frontend

# Check service endpoints
kubectl get endpoints -n backend
kubectl get endpoints -n frontend

# Check ingress
kubectl get ingress -n frontend
kubectl describe ingress -n frontend

# Check network policies
kubectl get networkpolicy -n backend
kubectl get networkpolicy -n frontend

# Describe network policy
kubectl describe networkpolicy flask-app -n backend
```

---

## RBAC Verification

```bash
# List service accounts
kubectl get sa -n backend
kubectl get sa -n frontend

# Check RBAC roles
kubectl get role -n backend
kubectl get role -n frontend

# Check role bindings
kubectl get rolebinding -n backend
kubectl get rolebinding -n frontend

# View role permissions
kubectl describe role flask-app -n backend
```

---

## Upgrades & Updates

```bash
# Check Helm releases
helm list -n backend
helm list -n frontend

# Dry-run upgrade
helm upgrade flask-backend helm-charts/flask-app/ \
  -n backend --dry-run --debug \
  -f helm-charts/flask-app/values.yaml \
  -f helm-charts/flask-app/values.stage.yaml

# Perform upgrade
helm upgrade flask-backend helm-charts/flask-app/ \
  -n backend \
  -f helm-charts/flask-app/values.yaml \
  -f helm-charts/flask-app/values.stage.yaml

# Rollback release
helm rollback flask-backend 1 -n backend

# Check rollout status
kubectl rollout status deployment/flask-app -n backend
```

---

## Troubleshooting

```bash
# Get cluster events
kubectl get events -n backend --sort-by='.lastTimestamp'
kubectl get events -n frontend --sort-by='.lastTimestamp'

# Check node status
kubectl get nodes -o wide

# Check pod status in detail
kubectl describe pod <pod-name> -n backend

# Check resource quotas
kubectl get resourcequota -n backend
kubectl get resourcequota -n frontend

# Exec into pod for debugging
kubectl exec -it <pod-name> -n backend -- /bin/bash
kubectl exec -it <pod-name> -n backend -- sh

# Check DNS resolution inside pod
kubectl exec -it <pod-name> -n backend -- nslookup kubernetes.default

# Check service DNS from pod
kubectl exec -it <pod-name> -n backend -- nslookup flask-app.backend.svc.cluster.local

# View pod resource usage
kubectl top pod <pod-name> -n backend
```

---

## Cleanup & Removal

```bash
# Delete pod (will respawn if deployment exists)
kubectl delete pod <pod-name> -n backend

# Delete service
kubectl delete svc flask-app -n backend

# Delete deployment
kubectl delete deployment flask-app -n backend

# Uninstall Helm release
helm uninstall flask-backend -n backend
helm uninstall nginx-frontend -n frontend

# Delete namespace (careful!)
kubectl delete namespace backend
kubectl delete namespace frontend

# Delete ArgoCD application
kubectl delete application flask-backend -n argocd
```

---

## ArgoCD Operations

```bash
# List applications
kubectl get applications -n argocd
kubectl get applications -n argocd -o wide

# Describe application
kubectl describe application flask-backend -n argocd

# Check application sync status
kubectl get application flask-backend -n argocd -o jsonpath='{.status.sync.status}'

# Force sync
kubectl patch application flask-backend -n argocd \
  -p '{"spec":{"syncPolicy":{"syncOptions":["Refresh=true"]}}}' --type merge

# View application details
kubectl get application flask-backend -n argocd -o yaml
```

---

## Performance & Metrics

```bash
# Check pod CPU/Memory usage
kubectl top pods -n backend
kubectl top pods -n frontend

# Check node resources
kubectl top nodes

# Get resource requests/limits
kubectl get pods -n backend -o json | \
  jq '.items[].spec.containers[] | {name, resources}'

# Check storage usage
kubectl get pvc -n backend
kubectl describe pvc -n backend
```

---

## Backup & Disaster Recovery

```bash
# Backup database
kubectl exec <db-pod> -n backend -- \
  mysqldump -u root -p --all-databases > backup-$(date +%Y%m%d).sql

# Backup configmaps
kubectl get configmap -n backend -o yaml > configmap-backup.yaml

# Backup secrets (WARNING: contains sensitive data!)
kubectl get secret -n backend -o yaml > secret-backup.yaml

# Export current state
kubectl get all -n backend -o yaml > backend-state.yaml
kubectl get all -n frontend -o yaml > frontend-state.yaml
```

---

## Quick Validations

```bash
# Run full validation
./validate-deployment.sh

# Manual validation steps
echo "=== Pods ===" && \
kubectl get pods -n backend && \
kubectl get pods -n frontend && \
echo "=== Services ===" && \
kubectl get svc -n backend && \
kubectl get svc -n frontend && \
echo "=== Ingress ===" && \
kubectl get ingress -n frontend && \
echo "=== Storage ===" && \
kubectl get pvc -n backend
```

---

## Useful Aliases (add to ~/.bashrc)

```bash
# Kubernetes aliases
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'

# Staging specific
alias k-backend='kubectl -n backend'
alias k-frontend='kubectl -n frontend'
alias k-argocd='kubectl -n argocd'

# Usage: k-backend get pods
```

---

## Emergency Commands

```bash
# Pod is stuck, force delete
kubectl delete pod <pod-name> -n backend --grace-period=0 --force

# Restart deployment
kubectl rollout restart deployment/flask-app -n backend

# Scale to 0 then back up (hard reset)
kubectl scale deployment flask-app -n backend --replicas=0
sleep 5
kubectl scale deployment flask-app -n backend --replicas=1

# Check cluster health
kubectl get nodes
kubectl get events -n kube-system

# Emergency drain node (if needed)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

---

## Information Gathering Commands

```bash
# Get all info about Flask deployment
kubectl get deployment flask-app -n backend -o yaml

# Get all pods with labels
kubectl get pods -n backend --show-labels

# Get all resources in namespace
kubectl get all -n backend

# Get API versions available
kubectl api-resources

# Check Kubernetes version
kubectl version --short

# Get cluster info
kubectl cluster-info
```

---

## Performance Tuning

```bash
# Check if metrics server is running
kubectl get deployment metrics-server -n kube-system

# Check HPA metrics
kubectl get hpa flask-app -n backend --watch

# View HPA details
kubectl describe hpa flask-app -n backend

# Check for pod throttling (Memory/CPU)
kubectl describe pod <pod-name> -n backend | grep -A 5 "Requests\|Limits"

# List resource intensive pods
kubectl top pods -n backend --sort-by=memory
kubectl top pods -n backend --sort-by=cpu
```

---

**Last Updated:** 2025-11-17  
**Usage:** Copy-paste these commands for quick operations
