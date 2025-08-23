#!/bin/bash

kubectl port-forward svc/argocd-server -n argocd 8081:443
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
echo