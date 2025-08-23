# Phase 2 – Part 1: K3s + Vagrant

## 🎯 Objectif
Mettre en place un cluster Kubernetes minimal avec **K3s** en utilisant **Vagrant** :
- 1 VM `loginS` (Server / Master) → IP `192.168.56.110`
- 1 VM `loginSW` (Worker / Agent) → IP `192.168.56.111`
- Ressources minimales (1 CPU, 1024 MB RAM)
- Accès SSH sans mot de passe (via Vagrant)
- Un cluster opérationnel visible avec `kubectl`

---

## 🚀 Utilisation

### 1. Lancer le cluster
Dans le dossier `p1/` :
```bash
vagrant up
```

Cela va automatiquement :
- Créer 2 VMs
- Installer K3s en mode **server** sur `loginS`
- Installer K3s en mode **agent** sur `loginSW` (connexion au cluster)
- Configurer le cluster avec IPs fixes

---

### 2. Vérifier depuis la VM Server
```bash
vagrant ssh loginS
kubectl get nodes -o wide
```

Résultat attendu :
```
NAME        STATUS   ROLES                  AGE   VERSION
loginS      Ready    control-plane,master   Xm    v1.33.x+k3s
loginSW     Ready    <none>                 Xm    v1.33.x+k3s
```

---

## 🖥️ Utiliser `kubectl` depuis l’hôte

Si vous avez `kubectl` installé **sur votre machine hôte**, vous pouvez piloter le cluster sans entrer dans la VM.

### 1. Récupérer la configuration depuis la VM Server
```bash
vagrant ssh loginS -c "sudo cat /etc/rancher/k3s/k3s.yaml" > config/kubeconfig.yaml
```

### 2. Modifier l’adresse du serveur
Dans `config/kubeconfig.yaml`, remplacer :
```yaml
server: https://127.0.0.1:6443
```
par
```yaml
server: https://192.168.56.110:6443
```

### 3. Exporter la variable KUBECONFIG
```bash
export KUBECONFIG=$PWD/config/kubeconfig.yaml
```

### 4. Tester
```bash
kubectl get nodes
```

---

## ❗ Note importante
- Ne versionnez pas `config/kubeconfig.yaml` dans Git :  
  ce fichier contient des certificats générés à l’installation et **ils diffèrent pour chaque environnement**.  
- Chaque membre de l’équipe doit régénérer son propre fichier après un `vagrant up`.

---

## 🛑 Nettoyer l’environnement
Pour détruire toutes les VMs créées :
```bash
vagrant destroy -f
```
