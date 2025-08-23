# Phase 2 – Part 2: K3s + 3 applications

## 🎯 Objectif
Déployer 3 applications simples sur un cluster **K3s** démarré via **Vagrant**, et exposer le tout avec un **Ingress (Traefik)** qui route selon le `Host`.

- App1 → 1 pod (nginx)
- App2 → 3 replicas (apache/httpd)
- App3 → 1 pod (traefik/whoami)
- Ingress:
  - `app1.com` → App1
  - `app2.com` → App2
  - toute autre valeur de Host → App3 (catch‑all)

---

## 📂 Arborescence attendue
```
p2/
├── Vagrantfile
├── provision.sh
└── confs/
    ├── deployments.yaml
    ├── services.yaml
    └── ingress.yaml
```

> Les manifests de `confs/` sont montés dans la VM et appliqués automatiquement par `provision.sh`.

---

## 🚀 Démarrage
Dans `p2/` :
```bash
vagrant up
```

Ce que fait `provision.sh` :
1) installe K3s (server) avec IP fixe `192.168.56.110` et SAN TLS;  
2) attend que l’API K3s soit prête;  
3) applique les manifests `deployments.yaml`, `services.yaml`, `ingress.yaml`.

---

## ✅ Vérifications rapides
Se connecter à la VM server :
```bash
vagrant ssh ikaismouS
kubectl get nodes -o wide
kubectl get pods -o wide
kubectl get svc
kubectl get ingress
```

Vous devez voir 3 services (app1, app2, app3) et un ingress `apps-ingress` avec les hosts `app1.com,app2.com`.

---

## 🌐 Tests depuis l’hôte
```bash
curl -H "Host: app1.com" http://192.168.56.110   # → Nginx (App1)
curl -H "Host: app2.com" http://192.168.56.110   # → Apache (App2, 3 replicas derrière)
curl -H "Host: whatever.com" http://192.168.56.110   # → Whoami (App3, catch‑all)
```

### Tester dans un navigateur (optionnel)
Ajoutez ces lignes dans votre fichier `hosts` pour résoudre les noms vers la VM :
```
192.168.56.110 app1.com
192.168.56.110 app2.com
192.168.56.110 whatever.com
```
Ensuite ouvrez `http://app1.com`, `http://app2.com`, etc.

---

## 🛠️ Détails techniques

### Ingress (Traefik)
Traefik ne traite pas le champ `defaultBackend` du manifeste Ingress.  
Pour un **fallback/catch‑all**, on ajoute **une règle sans `host`** qui pointe vers App3 :
```yaml
- http:
    paths:
    - path: /
      pathType: Prefix
      backend:
        service:
          name: app3
          port:
            number: 80
```

### K3s côté VM
Le serveur est installé avec :
```
--node-ip 192.168.56.110 --tls-san 192.168.56.110
```
afin que l’IP privée soit utilisée comme `INTERNAL-IP` et incluse dans le certificat TLS.

---

## 🔁 Re-déployer / mettre à jour
Après modification de vos YAML dans `confs/`, appliquez :
```bash
vagrant ssh ikaismouS -c "kubectl apply -f /home/vagrant/confs/deployments.yaml && kubectl apply -f /home/vagrant/confs/services.yaml && kubectl apply -f /home/vagrant/confs/ingress.yaml"
```

Ou relancez le provisionnement :
```bash
vagrant provision ikaismouS
```

---

## 🧹 Nettoyage
```bash
vagrant destroy -f
```

---

## ❗ Troubleshooting
- **Ingress renvoie 404 pour les hosts non définis** → vérifiez que l’Ingress contient bien une **règle sans `host`** (catch‑all) pointant vers `app3`.
- **Pods restent en `ContainerCreating`** → attendez quelques secondes ou regardez `kubectl describe pod <name>` pour voir l’événement bloquant.
- **Pas de ressources listées juste après l’apply** → le provision script applique immédiatement; les pods peuvent mettre 5–10s à apparaître (`kubectl get pods -w`).

---

## 🙅 À ne pas versionner
Ajoutez (à la racine du repo) dans `.gitignore` :
```
**/.vagrant/
**/node-token
```
