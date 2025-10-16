#!/bin/bash
set -e

echo "[INFO] === Installation de Docker ==="
if ! command -v docker &>/dev/null; then
  sudo pacman -S --noconfirm docker docker-compose
  sudo usermod -aG docker $USER
  sudo systemctl enable docker
  sudo systemctl start docker
else
  echo "Docker déjà installé"
fi

echo "[INFO] === Installation de kubectl ==="
if ! command -v kubectl &>/dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "kubectl déjà installé"
fi

echo "[INFO] === Installation de k3d ==="
if ! command -v k3d &>/dev/null; then
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
  echo "k3d déjà installé"
fi

echo "[INFO] === Création du cluster k3d ==="
k3d cluster delete mycluster || true
k3d cluster create mycluster \
  --servers 1 --agents 1 \
  -p "443:443@loadbalancer" \
  --host-alias 10.0.2.15:gitlab.local

echo "[INFO] === Installation d'ArgoCD ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "[INFO] Attente du déploiement complet d'ArgoCD..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

echo "[INFO] === Désactivation du TLS interne d'ArgoCD ==="
kubectl patch deployment argocd-server -n argocd --type=json -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/command", "value": ["/usr/local/bin/argocd-server"]},
  {"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": [
      "--staticassets", "/shared/app",
      "--repo-server", "argocd-repo-server:8081",
      "--dex-server", "http://argocd-dex-server:5556",
      "--redis", "argocd-redis:6379",
      "--insecure"
  ]}
]'
kubectl rollout status deployment argocd-server -n argocd

echo "[INFO] === Création de l'IngressRoute Traefik ==="
kubectl apply -f ../confs/argocd-ingressroute.yml
echo "[INFO] Attente que le service ArgoCD soit disponible..."
kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n argocd
sleep 5

echo "[INFO] === Installation du client ArgoCD ==="
if ! command -v argocd &>/dev/null; then
  curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  chmod +x /tmp/argocd && sudo mv /tmp/argocd /usr/local/bin/argocd
else
  echo "argocd CLI déjà installé"
fi

echo "[INFO] === Récupération du mot de passe admin ==="
ADMIN_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

echo "[INFO] === Connexion CLI à ArgoCD via Ingress HTTPS ==="
argocd login argocd.local --username admin --password "${ADMIN_PASS}" --insecure --grpc-web

echo "[INFO] === Ajout du dépôt GitHub ==="
argocd repo add https://github.com/islemk69/vburton-ikaismou-app.git

echo "[INFO] === Création de l'application ArgoCD (autosync) ==="
argocd app create p3-app \
  --repo https://github.com/islemk69/vburton-ikaismou-app.git \
  --path / \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --sync-policy automated \
  --self-heal \
  --auto-prune

echo "[INFO] === Synchronisation de l'application ==="
argocd app sync p3-app
argocd app wait p3-app --health --timeout 300

echo "[INFO] ✅ Déploiement terminé !"
echo ""
echo "🔗 Accès à ArgoCD : https://argocd.local"
echo "👤 Identifiant : admin"
echo "🔑 Mot de passe : ${ADMIN_PASS}"
echo ""
echo "⚠️ Assure-toi d'avoir dans ton /etc/hosts :"
echo "    127.0.0.1 argocd.local"
echo "    127.0.0.1 ikaismou.local"
