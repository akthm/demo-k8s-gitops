#!/usr/bin/env bash
set -euo pipefail

########################################
# CONFIG – EDIT THESE FOR YOUR SETUP
########################################

# "minikube" or "kind"
CLUSTER_PROVIDER="${CLUSTER_PROVIDER:-minikube}"
CLUSTER_NAME="${CLUSTER_NAME:-dev-platform}"

# Your GitOps repository (where the helm charts + argocd apps live)
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/your-org/your-gitops-repo.git}"
GIT_BRANCH="${GIT_BRANCH:-main}"

# Path *inside the repo* with your Argo CD Application yamls (app-of-apps pattern)
# e.g. argocd/apps with:
#   - platform.yaml (parent)
#   - flask-backend-staging.yaml
#   - nginx-frontend-staging.yaml
PLATFORM_APPS_PATH="${PLATFORM_APPS_PATH:-argocd/apps}"

########################################
# FUNCTIONS
########################################

create_minikube_cluster() {
  echo ">>> Creating Minikube cluster: ${CLUSTER_NAME}"
  minikube start \
    -p "${CLUSTER_NAME}" \
    --cpus=4 \
    --memory=7853 \
    --kubernetes-version=stable

  echo ">>> Enabling Minikube addons: ingress, metrics-server"
  minikube -p "${CLUSTER_NAME}" addons enable ingress
  minikube -p "${CLUSTER_NAME}" addons enable metrics-server

  # Point kubectl at this cluster
  kubectl config use-context "minikube"
}

create_kind_cluster() {
  echo ">>> Creating kind cluster: ${CLUSTER_NAME}"
  cat <<EOF | kind create cluster --name "${CLUSTER_NAME}" --wait 120s --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 80
        hostPort: 8080
        protocol: TCP
      - containerPort: 443
        hostPort: 8443
        protocol: TCP
  - role: worker
  - role: worker
EOF

  # Install nginx ingress for kind
  echo ">>> Installing NGINX Ingress for kind"
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

  echo ">>> Installing metrics-server (for HPA)"
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
}

install_argocd() {
  echo ">>> Creating argocd namespace"
  kubectl create namespace argocd 2>/dev/null || true

  echo ">>> Installing Argo CD"
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  echo ">>> Waiting for Argo CD to be ready..."
  kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
}

bootstrap_platform_application() {
  echo ">>> Creating platform (app-of-apps) Application"

  cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${GIT_REPO_URL}
    targetRevision: ${GIT_BRANCH}
    path: ${PLATFORM_APPS_PATH}
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ApplyOutOfSyncOnly=true
EOF
}

print_info() {
  echo
  echo "========================================"
  echo "Local cluster & Argo CD setup complete."
  echo "========================================"
  echo
  echo "Argo CD namespace   : argocd"
  echo "Platform app name   : platform"
  echo
  echo "To access Argo CD UI:"
  echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
  echo "Then open: https://localhost:8080"
  echo
  echo "Initial admin password:"
  echo "  kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d; echo"
  echo
  if [ "${CLUSTER_PROVIDER}" = "minikube" ]; then
    echo "For Ingress-based apps on Minikube:"
    echo "  minikube -p ${CLUSTER_NAME} tunnel"
  else
    echo "For Ingress-based apps on kind:"
    echo "  Use http://localhost:8080 or https://localhost:8443 depending on your ingress host rules."
  fi
  echo
  echo "Make sure your Git repo (${GIT_REPO_URL}) contains:"
  echo "  - ${PLATFORM_APPS_PATH}/flask-backend-*.yaml (Application for backend)"
  echo "  - ${PLATFORM_APPS_PATH}/nginx-frontend-*.yaml (Application for frontend)"
  echo "  pointing to helm-charts/flask-app and helm-charts/nginx-front."
  echo
}

########################################
# MAIN
########################################

case "${CLUSTER_PROVIDER}" in
  minikube)
    create_minikube_cluster
    ;;
  kind)
    create_kind_cluster
    ;;
  *)
    echo "Unsupported CLUSTER_PROVIDER: ${CLUSTER_PROVIDER}. Use 'minikube' or 'kind'."
    exit 1
    ;;
esac

install_argocd
bootstrap_platform_application
print_info
