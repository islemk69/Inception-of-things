#!/bin/bash
set -e

# Vérifie qu'un token GitHub est présent
if [ -z "$GITHUB_TOKEN" ]; then
  echo "[ERREUR] Variable GITHUB_TOKEN manquante."
  echo "Exportez-la avant de lancer le script :"
  echo "  export GITHUB_TOKEN='ton_token_github'"
  exit 1
fi

echo "[INFO] === Installation de Docker ==="
if ! command -v docker &> /dev/null; then
  sudo pacman -S --noconfirm docker docker-compose
  sudo usermod -aG docker $USER
  sudo systemctl enable docker
  sudo systemctl start docker
else
  echo "Docker déjà installé"
fi

echo "[INFO] === Installation de kubectl ==="
if ! command -v kubectl &> /dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "kubectl déjà installé"
fi

echo "[INFO] === Installation de k3d ==="
if ! command -v k3d &> /dev/null; then
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
else
  echo "k3d déjà installé"
fi

echo "[INFO] === Création du cluster k3d ==="
if ! k3d cluster list | grep -q "^mycluster"; then
  k3d cluster create mycluster --servers 1 --agents 1 -p "8080:80@loadbalancer"
else
  echo "Cluster 'mycluster' déjà existant, skip..."
fi

echo "[INFO] === Installation d'ArgoCD ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "[INFO] Attente du déploiement complet d'ArgoCD..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

echo "[INFO] === Installation du client ArgoCD ==="
if ! command -v argocd &>/dev/null; then
  curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  chmod +x /tmp/argocd && sudo mv /tmp/argocd /usr/local/bin/argocd
else
  echo "argocd CLI déjà installé"
fi

echo "[INFO] === Récupération du mot de passe admin ==="
ADMIN_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "[INFO] === Lancement du port-forward sur 8081 ==="
kubectl port-forward svc/argocd-server -n argocd 8081:443 >/dev/null 2>&1 &
sleep 5

kubectl create namespace dev

echo "[INFO] === Connexion CLI à ArgoCD ==="
argocd login localhost:8081 --username admin --password "${ADMIN_PASS}" --insecure --grpc-web

echo "[INFO] === Ajout du dépôt GitHub ==="
argocd repo add https://github.com/islemk69/Inception-of-things.git \
  --username islemk69 \
  --password "$GITHUB_TOKEN"

echo "[INFO] === Création de l'application ArgoCD (autosync) ==="
argocd app create p3-app \
  --repo https://github.com/islemk69/Inception-of-things.git \
  --path p3/app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --sync-policy automated \
  --self-heal \
  --auto-prune

echo "[INFO] === Synchronisation de l'application ==="
argocd app sync p3-app
argocd app wait p3-app --health --timeout 300

echo "[INFO] ✅ Déploiement terminé !"
echo "Accède à l'interface : https://localhost:8081"
echo "Identifiant : admin"
echo "Mot de passe : ${ADMIN_PASS}"