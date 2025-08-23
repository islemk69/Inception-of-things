#!/bin/bash
set -e

echo "[INFO] Mise à jour du système"
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates

echo "[INFO] Installation de K3s (server mode)"
if ! systemctl is-active --quiet k3s; then
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip 192.168.56.110 --tls-san 192.168.56.110" sh -
else
  echo "[INFO] K3s déjà installé, skip..."
fi

echo "[INFO] Attente que le serveur K3s soit prêt..."
# Boucle jusqu'à ce que l’API réponde
until sudo kubectl get nodes &>/dev/null; do
  echo "⏳ En attente de K3s..."
  sleep 5
done

echo "[INFO] Déploiement des applications"
sudo kubectl apply -f /home/vagrant/confs/deployments.yaml
sudo kubectl apply -f /home/vagrant/confs/services.yaml
sudo kubectl apply -f /home/vagrant/confs/ingress.yaml

echo "[INFO] Cluster en cours :"
sudo kubectl get nodes -o wide
sudo kubectl get pods -o wide
sudo kubectl get svc
sudo kubectl get ingress
