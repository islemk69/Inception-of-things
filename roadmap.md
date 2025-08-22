# 🚀 Roadmap du projet IoT (Inception-of-Things)

## 🟢 Phase 1 : Préparation de l’environnement
1. Installer sur ta machine hôte :
   - VirtualBox (ou autre provider compatible Vagrant)
   - Vagrant
   - Docker + Docker Compose
   - kubectl
   - Git
2. Créer ton repo Git avec la structure demandée :
   ```
   p1/
   p2/
   p3/
   bonus/
   ```

---

## 🟠 Phase 2 : Part 1 – K3s + Vagrant
🎯 Objectif : Avoir un cluster K3s (1 master + 1 worker) qui tourne avec Vagrant.

1. Écrire un Vagrantfile qui crée :
   - VM `loginS` (IP 192.168.56.110)
   - VM `loginSW` (IP 192.168.56.111)
   - Ressources minimales (1 CPU, 512–1024MB RAM)
   - SSH sans mot de passe
2. Installer K3s :
   - Sur `loginS` → **server mode**
   - Sur `loginSW` → **agent mode** (jointure au cluster du server)
3. Installer `kubectl` et tester :
   ```bash
   kubectl get nodes
   ```
   👉 Doit montrer 2 nœuds (1 master, 1 worker).

---

## 🟡 Phase 3 : Part 2 – K3s + 3 applications
🎯 Objectif : Déployer plusieurs applis via Kubernetes + Ingress.

1. Créer une VM `loginS` avec K3s (server mode)
2. Définir 3 applications simples (par ex. **nginx, apache, whoami**)
3. Écrire les **Deployments + Services** :
   - App1 → 1 pod
   - App2 → 3 replicas
   - App3 → 1 pod
4. Créer un **Ingress** qui route selon le `Host` :
   - `app1.com` → App1
   - `app2.com` → App2
   - sinon → App3 (default backend)
5. Vérifier avec :
   ```bash
   curl -H "Host: app1.com" http://192.168.56.110
   ```

---

## 🔵 Phase 4 : Part 3 – K3d + ArgoCD
🎯 Objectif : GitOps avec ArgoCD + déploiement auto depuis GitHub.

1. Installer **k3d** (via script avec Docker, kubectl, etc.)
2. Créer un cluster avec k3d :
   ```bash
   k3d cluster create mycluster
   ```
3. Installer **ArgoCD** dans le namespace `argocd`
4. Créer un namespace `dev`
5. Préparer un **repo GitHub public** contenant :
   - Manifests (Deployment, Service, Ingress)
   - Ton appli Docker (soit `wil42/playground`, soit ton image perso avec `v1` et `v2`)
6. Connecter ArgoCD à ton repo GitHub
7. Vérifier :
   - Version v1 déployée
   - Modifier le manifest GitHub → ArgoCD applique v2 automatiquement

---

## 🔴 Phase 5 : Bonus – GitLab
🎯 Objectif : Remplacer GitHub par GitLab, déployé **dans ton cluster**.

1. Déployer **GitLab** dans le namespace `gitlab` (Helm recommandé)
2. Configurer GitLab pour qu’il fonctionne en local
3. Héberger tes manifests/app dans GitLab
4. Refaire la logique de la Part 3 :
   - ArgoCD lit depuis GitLab au lieu de GitHub
   - Changement dans GitLab → mise à jour auto de l’app

---

## 🟣 Phase 6 : Finalisation & Validation
1. Vérifier la **structure du repo** (`p1`, `p2`, `p3`, `bonus`)
2. Ajouter :
   - `scripts/` (installations automatisées)
   - `confs/` (manifests yaml)
3. Tester chaque partie **comme si tu étais évaluateur**
4. Écrire un petit **README** clair expliquant comment lancer chaque étape

---

✅ Résultat attendu :
- P1 → Cluster K3s (2 VM) fonctionnel
- P2 → 3 applis accessibles via Ingress
- P3 → K3d + ArgoCD + GitHub → déploiement auto v1/v2
- Bonus → GitLab local + ArgoCD + CI/CD
