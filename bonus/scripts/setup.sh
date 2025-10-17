#!/bin/bash
set -e

# === CONFIGURATION ===
NAMESPACE="gitlab"
RELEASE_NAME="gitlab"
VALUES_FILE="../confs/gitlab-values.yaml"
INGRESSROUTE_FILE="../confs/gitlab-ingressroute.yaml"
APP_DIR="../app"
PROJECT_NAME="vburton-ikaismou-app"
GITLAB_URL="https://gitlab.local"

# === COULEURS ===
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
RESET="\033[0m"

sudo apt-get install jq

echo -e "${YELLOW}🧹 Nettoyage des anciens dépôts ArgoCD...${RESET}"
argocd app delete p3-app --yes || true
argocd repo rm https://github.com/islemk69/vburton-ikaismou-app.git || true

# === Vérification de Helm ===
echo -e "${YELLOW}⚙️ Vérification de Helm...${RESET}"
if ! command -v helm &>/dev/null; then
  echo "Helm non trouvé. Installation..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "✔ Helm déjà installé"
fi

# === Ajout du repo Helm GitLab ===
echo -e "${YELLOW}📦 Ajout du repo Helm GitLab...${RESET}"
if ! helm repo list | grep -q "https://charts.gitlab.io"; then
  helm repo add gitlab https://charts.gitlab.io
fi
helm repo update

# === Namespace GitLab ===
echo -e "${YELLOW}📂 Vérification du namespace GitLab...${RESET}"
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# === Installation GitLab via Helm ===
echo -e "${YELLOW}🚀 Installation de GitLab via Helm...${RESET}"
helm install ${RELEASE_NAME} gitlab/gitlab \
  -n ${NAMESPACE} \
  -f ${VALUES_FILE}

# === Attente du déploiement GitLab ===
echo -e "${YELLOW}⏳ Attente du GitLab Webservice...${RESET}"
kubectl wait --for=condition=available deployment/gitlab-webservice-default -n ${NAMESPACE} --timeout=600s

# === Génération du certificat TLS SAN gitlab.local ===

echo -e "${YELLOW}🔐 Génération du certificat TLS gitlab.local (SAN + CA:true)...${RESET}"
cat > /tmp/gitlab.cnf <<EOF
[req]
default_bits = 4096
distinguished_name = dn
x509_extensions = v3_ca
prompt = no

[dn]
CN = gitlab.local

[v3_ca]
subjectAltName = @alt_names
basicConstraints = critical,CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
extendedKeyUsage = serverAuth
[alt_names]
DNS.1 = gitlab.local
EOF

openssl req -x509 -nodes -newkey rsa:4096 \
  -keyout /tmp/gitlab.key \
  -out /tmp/gitlab.crt \
  -days 365 \
  -extensions v3_ca \
  -config /tmp/gitlab.cnf

kubectl create secret tls gitlab-tls-cert \
  --cert=/tmp/gitlab.crt \
  --key=/tmp/gitlab.key \
  -n gitlab --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f ${INGRESSROUTE_FILE}
kubectl rollout restart deployment/gitlab-webservice-default -n gitlab

# === Ajout du certificat à ArgoCD ===
echo -e "${YELLOW}📎 Ajout du certificat à ArgoCD...${RESET}"
kubectl create configmap argocd-tls-certs-cm \
  -n argocd \
  --from-file=gitlab.local=/tmp/gitlab.crt \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout restart deployment/argocd-repo-server -n argocd

# === Récupération du mot de passe root ===
echo -e "${YELLOW}🔑 Récupération du mot de passe root GitLab...${RESET}"
ROOT_PASS=$(kubectl -n ${NAMESPACE} get secret gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 -d)
echo -e "${GREEN}Mot de passe root GitLab : ${ROOT_PASS}${RESET}"

# === Vérification de disponibilité GitLab ===
echo -e "${YELLOW}🌐 Vérification de la disponibilité de GitLab (${GITLAB_URL})...${RESET}"
for i in {1..60}; do
  STATUS=$(curl -sk -o /dev/null -w "%{http_code}" "${GITLAB_URL}/users/sign_in" || true)
  if [[ "$STATUS" == "200" ]]; then
    echo -e "${GREEN}✔ GitLab est prêt.${RESET}"
    break
  fi
  echo -e "${YELLOW}⏳ GitLab pas encore prêt (${STATUS})... tentative ${i}/60${RESET}"
  sleep 10
done

# === Génération du token OAuth root ===
echo -e "${YELLOW}🔐 Génération du token OAuth root...${RESET}"
TOKEN_JSON=$(curl -sk --request POST "${GITLAB_URL}/oauth/token" \
  --form "grant_type=password" \
  --form "username=root" \
  --form "password=${ROOT_PASS}")

TOKEN=$(echo "$TOKEN_JSON" | jq -r '.access_token' 2>/dev/null || true)
if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
  echo -e "${RED}❌ Échec génération du token OAuth.${RESET}"
  echo "$TOKEN_JSON"
  exit 1
fi
echo -e "${GREEN}✔ Token récupéré avec succès.${RESET}"

# === Création du projet GitLab ===
echo -e "${YELLOW}📁 Création du projet GitLab ${PROJECT_NAME}...${RESET}"
PROJECT_ID=$(curl -sk --request POST "${GITLAB_URL}/api/v4/projects" \
  --header "Authorization: Bearer ${TOKEN}" \
  --header "Content-Type: application/json" \
  --data "{\"name\": \"${PROJECT_NAME}\", \"visibility\": \"private\"}" | jq -r '.id')

if [ "$PROJECT_ID" == "null" ] || [ -z "$PROJECT_ID" ]; then
  echo -e "${RED}❌ Impossible de créer le projet GitLab.${RESET}"
  exit 1
fi
echo -e "${GREEN}✔ Projet GitLab créé (ID=${PROJECT_ID}).${RESET}"

# === Initialisation du dépôt local ===
echo -e "${YELLOW}📦 Initialisation du dépôt local...${RESET}"
cd "${APP_DIR}"
if [ ! -d ".git" ]; then git init; fi
git add .
git config --global user.email "auto@script.fr"
git config --global user.name "autoscript"
git commit -m "Initial commit" || true
git remote remove origin 2>/dev/null || true
git remote add origin "${GITLAB_URL}/root/${PROJECT_NAME}.git"

# === Authentification Git ===
echo -e "${YELLOW}🔐 Configuration des identifiants Git...${RESET}"
git config --global credential.helper store
cat <<EOF > ~/.git-credentials
https://root:${TOKEN}@gitlab.local
EOF
git config --global http.sslVerify false

# === Push du code ===
echo -e "${YELLOW}🚀 Push du code vers GitLab...${RESET}"
git branch -M main
git push -u origin main
echo -e "${GREEN}✔ Code poussé avec succès vers GitLab.${RESET}"

# === Création Deploy Token pour ArgoCD ===
echo -e "${YELLOW}🔐 Création du Deploy Token pour ArgoCD...${RESET}"
DEPLOY_TOKEN=$(curl -sk --request POST "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/deploy_tokens" \
  --header "Authorization: Bearer ${TOKEN}" \
  --data "name=argo-deploy" \
  --data "scopes[]=read_repository" \
  --data "username=argocd" | jq -r '.token')

if [ -z "$DEPLOY_TOKEN" ] || [ "$DEPLOY_TOKEN" == "null" ]; then
  echo -e "${RED}❌ Échec création Deploy Token.${RESET}"
  exit 1
fi
echo -e "${GREEN}✔ Deploy Token créé avec succès.${RESET}"

sleep 20

kubectl apply -f ../confs/gitlab-redirect.yml

# === Connexion du dépôt GitLab à ArgoCD ===
echo -e "${YELLOW}🔄 Connexion du dépôt GitLab à ArgoCD...${RESET}"
argocd repo add https://gitlab.local/root/${PROJECT_NAME}.git \
  --username argocd \
  --password "${DEPLOY_TOKEN}"

# === Création application ArgoCD ===
echo -e "${YELLOW}🌀 Création de l'application ArgoCD...${RESET}"
argocd app create bonus-app \
  --repo https://gitlab.local/root/${PROJECT_NAME}.git \
  --path . \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --sync-policy automated \
  --self-heal \
  --auto-prune

# === Fin ===
echo -e "${GREEN}✅ Bonus terminé avec succès !${RESET}"
echo ""
echo "🔗 Accès GitLab : ${GITLAB_URL}"
echo "👤 Identifiant : root"
echo "🔑 Mot de passe : ${ROOT_PASS}"
echo "🌱 Projet : ${GITLAB_URL}/root/${PROJECT_NAME}"
echo ""
echo "⚠️ Ajoute dans ton /etc/hosts :"
echo "    127.0.0.1 gitlab.local"