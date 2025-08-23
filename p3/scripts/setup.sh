#!/bin/bash
set -e

echo "[INFO] Installation de Docker"
if ! command -v docker &> /dev/null; then
  sudo pacman -S docker docker-compose
  sudo usermod -aG docker $USER
else
  echo "Docker déjà installé"
fi

echo "[INFO] Installation de kubectl"
if ! command -v kubectl &> /dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "kubectl déjà installé"
fi

echo "[INFO] Installation de k3d"
if ! command -v k3d &> /dev/null; then
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
  echo "k3d déjà installé"
fi

echo "[INFO] Création du cluster k3d"
if k3d cluster list | grep -q "^mycluster"; then
  echo "Cluster 'mycluster' déjà existant, skip..."
else
  k3d cluster create mycluster --servers 1 --agents 1 -p "8080:80@loadbalancer"
fi

echo "[INFO] Installation de ArgoCD"

if kubectl get namespace argocd &>/dev/null; then
  echo "Namespace 'argocd' déjà existant, skip création..."
else
  kubectl create namespace argocd
fi

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "[INFO] Cluster prêt !"
kubectl get nodes
kubectl get pods -n argocd

echo "[INFO] Creation du namespace dev pour l'app"
if kubectl get namespace dev &>/dev/null; then
  echo "Namespace 'dev' déjà existant, skip création..."
else
  kubectl create namespace dev
fi