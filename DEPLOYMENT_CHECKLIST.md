# Pre-Deployment Checklist - Staging

Use this checklist to ensure all prerequisites are met before deploying to staging.

---

## ✅ Infrastructure Readiness

- [ ] Kubernetes cluster is running (1.24+)
- [ ] `kubectl` is configured and can access cluster
- [ ] DNS is properly configured for staging domain
- [ ] Storage class exists for database persistence
  ```bash
  kubectl get storageclass
  ```

---

## ✅ Kubernetes Components

- [ ] **Ingress Controller** is installed
  ```bash
  kubectl get deployment -n ingress-nginx
  ```

- [ ] **External Secrets Operator** is installed
  ```bash
  kubectl get deployment -n external-secrets-system external-secrets
  ```

- [ ] **Metrics Server** is installed (for HPA)
  ```bash
  kubectl get deployment -n kube-system metrics-server
  ```

- [ ] **ArgoCD** is installed
  ```bash
  kubectl get deployment -n argocd argocd-server
  ```

---

## ✅ AWS Configuration

- [ ] AWS account has credentials configured
  ```bash
  aws sts get-caller-identity
  ```

- [ ] IAM role exists with `secretsmanager:GetSecretValue` permission

- [ ] AWS Secrets Manager contains required secrets:
  - [ ] `staging/backend/database-url`
  - [ ] `staging/backend/flask-key`
  ```bash
  aws secretsmanager list-secrets --filter Key=name,Values=staging/backend
  ```

---

## ✅ Repository Setup

- [ ] Git repository is created
  ```bash
  git remote -v
  ```

- [ ] Repository URL is accessible from cluster
  ```bash
  git clone https://github.com/YOUR-ORG/your-gitops-repo.git
  ```

- [ ] Repository has `staging` branch
  ```bash
  git branch -a
  ```

- [ ] All files are committed to `staging` branch:
  - [ ] `apps/staging/flask-backend.yaml`
  - [ ] `apps/staging/nginx-front.yaml`
  - [ ] `helm-charts/flask-app/**`
  - [ ] `helm-charts/nginx-front/**`

---

## ✅ Docker Images

- [ ] Backend image is built and pushed:
  ```bash
  docker inspect akthm/demo-back:stage-1
  ```

- [ ] Frontend image is built and pushed:
  ```bash
  docker inspect akthm/demo-front:1.0.3
  ```

- [ ] Images are scannable from cluster
  ```bash
  kubectl run test --image=akthm/demo-back:stage-1 --rm -it -- ls
  ```

---

## ✅ Configuration Review

### Backend Configuration (`values.stage.yaml`)

- [ ] `image.tag` is set to `stage-1`
- [ ] `replicaCount` is appropriate for staging (1 minimum)
- [ ] `resources.requests` are set (CPU: 100m, Memory: 256Mi)
- [ ] `resources.limits` are set (CPU: 500m, Memory: 512Mi)
- [ ] `externalSecrets.enabled` is `true`
- [ ] Database credentials are correct:
  - [ ] `db.auth.database` = `flask_staging`
  - [ ] `db.auth.username` = `flask_user`
- [ ] CORS origins include staging domain
- [ ] JWT keys secret exists:
  ```bash
  kubectl get secret backend-jwt-keys -n backend
  ```

### Frontend Configuration (`values.yaml`)

- [ ] `image.tag` is set to `1.0.3`
- [ ] `backend.serviceHost` = `flask-app.backend.svc.cluster.local`
- [ ] `backend.servicePort` = `8000`
- [ ] `ingress.enabled` is `true`
- [ ] `ingress.hosts[0].host` is staging domain
- [ ] `ingress.className` is correct (`nginx`)
- [ ] Security context is enabled
- [ ] Resource requests are set

---

## ✅ Network & Security

- [ ] Namespaces are labeled for network policies
  ```bash
  kubectl get namespace --show-labels
  ```

- [ ] Network policies are ready:
  - [ ] Backend network policy defined
  - [ ] Frontend network policy defined

- [ ] RBAC is configured:
  - [ ] Service accounts created
  - [ ] Roles and RoleBindings defined

- [ ] Pod Security Context is enabled in values

- [ ] No secrets are committed to git:
  ```bash
  git log -p | grep -i "password\|secret\|key" || echo "✓ No secrets in history"
  ```

---

## ✅ Deployment Prerequisites

- [ ] Setup script is prepared:
  ```bash
  chmod +x setup-staging.sh
  ```

- [ ] Database initialization scripts are ready (if needed)

- [ ] Application health endpoint is implemented:
  - [ ] `GET /health` returns 200

- [ ] Environment variables are documented in values

---

## ✅ Monitoring & Logging

- [ ] Logging solution is configured (if using ELK/Datadog/etc)
- [ ] Monitoring/metrics collection is configured
- [ ] Alerting rules are defined (optional for staging)

---

## ✅ ArgoCD Configuration

- [ ] ArgoCD has access to Git repository
  ```bash
  argocd repo list
  ```

- [ ] Repository URL is added to ArgoCD:
  ```bash
  argocd repo add https://github.com/YOUR-ORG/your-gitops-repo.git
  ```

- [ ] Application manifests reference correct:
  - [ ] Git repository URL
  - [ ] Target revision (staging)
  - [ ] Path to charts

---

## ✅ Final Verification

Before deploying, verify:

1. **No conflicts between environments**
   ```bash
   helm template flask-backend helm-charts/flask-app/ \
     -f helm-charts/flask-app/values.yaml \
     -f helm-charts/flask-app/values.stage.yaml | grep -i "TODO\|FIXME\|XXX" || echo "✓ Clean"
   ```

2. **All required fields are set**
   ```bash
   helm lint helm-charts/flask-app/
   helm lint helm-charts/nginx-front/
   ```

3. **No hardcoded secrets**
   ```bash
   grep -r "password\|secret\|api.?key" helm-charts/ || echo "✓ No hardcoded secrets"
   ```

4. **DNS is resolvable**
   ```bash
   nslookup frontend-staging.example.internal
   nslookup api-staging.example.internal
   ```

---

## ✅ Deployment Execution

- [ ] Run setup script:
  ```bash
  ./setup-staging.sh
  ```

- [ ] Apply ArgoCD applications:
  ```bash
  kubectl apply -f apps/staging/flask-backend.yaml
  kubectl apply -f apps/staging/nginx-front.yaml
  ```

- [ ] Monitor deployment progress:
  ```bash
  kubectl get applications -n argocd --watch
  ```

- [ ] Validate deployment:
  ```bash
  chmod +x validate-deployment.sh
  ./validate-deployment.sh
  ```

---

## ✅ Post-Deployment

- [ ] All pods are running:
  ```bash
  kubectl get pods -n backend
  kubectl get pods -n frontend
  ```

- [ ] Services have endpoints:
  ```bash
  kubectl get endpoints -n backend
  kubectl get endpoints -n frontend
  ```

- [ ] Ingress has IP/hostname:
  ```bash
  kubectl get ingress -n frontend
  ```

- [ ] Application is accessible:
  ```bash
  curl https://frontend-staging.example.internal/
  curl https://api-staging.example.internal/health
  ```

- [ ] Logs show no errors:
  ```bash
  kubectl logs -n backend -l app.kubernetes.io/name=flask-app --all-containers=true --tail=100
  kubectl logs -n frontend -l app.kubernetes.io/name=nginx-front --all-containers=true --tail=100
  ```

---

## ✅ Rollback Plan

In case of issues:

1. **Pause ArgoCD sync:**
   ```bash
   argocd app set flask-backend --sync-policy none
   argocd app set nginx-frontend --sync-policy none
   ```

2. **Rollback Helm release:**
   ```bash
   helm rollback flask-backend -n backend
   helm rollback nginx-frontend -n frontend
   ```

3. **Revert Git changes:**
   ```bash
   git revert HEAD
   git push origin staging
   ```

4. **Enable ArgoCD sync again:**
   ```bash
   argocd app set flask-backend --sync-policy automated
   argocd app set nginx-frontend --sync-policy automated
   ```

---

## Support Contacts

| Role | Contact | Method |
|------|---------|--------|
| Kubernetes Admin | TBD | Slack/Email |
| Database Admin | TBD | Slack/Email |
| Security Team | TBD | Slack/Email |
| DevOps Lead | TBD | Slack/Email |

---

**Checklist Version:** 1.0  
**Last Updated:** 2025-11-17  
**Status:** Ready for Deployment ✅
