#!/bin/bash
set -e

echo "[INFO] Installation de Helm"
if ! command -v helm &> /dev/null; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "[INFO] Namespace GitLab"
kubectl create namespace gitlab || true

echo "[INFO] Ajout du repo GitLab"
helm repo add gitlab https://charts.gitlab.io/
helm repo update

echo "[INFO] Déploiement de GitLab (mode light)"
helm upgrade --install gitlab gitlab/gitlab \
  -n gitlab \
  -f ../confs/gitlab-values.yaml

echo "[INFO] GitLab en cours de démarrage..."
kubectl rollout status deployment/gitlab-webservice-default -n gitlab --timeout=600s