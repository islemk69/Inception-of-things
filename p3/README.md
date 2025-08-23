# Phase 3 – Part 3: K3d + ArgoCD (GitOps)

## 🎯 Objectif
Mettre en place un cluster Kubernetes **léger avec k3d**, installer **ArgoCD** et déployer automatiquement une application depuis un dépôt GitHub public (**GitOps**).

---

## 📂 Arborescence attendue
```
p3/
├── scripts/
│   └── setup.sh
└── app/
    ├── deployment.yaml
    ├── service.yaml
    └── ingress.yaml
```

---

## 🚀 Installation du cluster + ArgoCD

Depuis `p3/scripts/` :

```bash
chmod +x setup.sh
./setup.sh
```

Le script fait :
1. installe **Docker**, **kubectl**, **k3d** (si absents)  
2. crée un cluster k3d `mycluster` avec :  
   ```
   k3d cluster create mycluster --servers 1 --agents 1 -p "8080:80@loadbalancer"
   ```
   → expose le port 80 du cluster sur `localhost:8080`  
3. installe **ArgoCD** dans le namespace `argocd`  
4. crée le namespace `dev` pour l’application

Vérifiez :

```bash
kubectl get nodes
kubectl get pods -n argocd
kubectl get ns
```

Vous devez voir `argocd` et `dev`.

---

## 🌐 Accéder à ArgoCD UI

Lancer le port-forward :
```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

Puis ouvrir [https://localhost:8081](https://localhost:8081).

- **Username** : `admin`  
- **Password** :  
  ```bash
  kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
  echo
  ```

---

## 🔗 Connecter ArgoCD à GitHub

Dans ArgoCD UI → **NEW APP** :  
- Application name : `wil-playground`  
- Project : `default`  
- Repository URL : `https://github.com/<login>/Inception-of-things`  
- Path : `p3/app`  
- Cluster URL : `https://kubernetes.default.svc`  
- Namespace : `dev`  
- Sync Policy : automatique (optionnel mais conseillé)

Valider → ArgoCD déploie l’app.

---

## ✅ Vérification

Lister les pods et services :
```bash
kubectl get pods -n dev
kubectl get svc -n dev
```

Tester l’app :  
```bash
curl -H "Host: wil.local" http://localhost:8080
```
Résultat attendu :  
```json
{"status":"ok", "message":"v1"}
```

---

## 🔄 Mise à jour GitOps

1. Modifier `deployment.yaml` → passer de `v1` à `v2` :  
   ```yaml
   image: wil42/playground:v2
   ```
2. Commit & push dans GitHub  
3. ArgoCD détecte le changement → redéploie automatiquement  
4. Vérifier :  
   ```bash
   curl -H "Host: wil.local" http://localhost:8080
   ```

Résultat attendu :  
```json
{"status":"ok", "message":"v2"}
```

---

## 🧹 Nettoyage

Détruire le cluster :  
```bash
k3d cluster delete mycluster
```
