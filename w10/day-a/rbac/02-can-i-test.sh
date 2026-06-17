#!/usr/bin/env bash
set -e

echo "== Viewer tests =="
kubectl auth can-i get pods --as=viewer -n dev
kubectl auth can-i create pods --as=viewer -n dev
kubectl auth can-i get secrets --as=viewer -n dev

echo
echo "== Developer tests =="
kubectl auth can-i create deployments --as=developer -n dev
kubectl auth can-i delete nodes --as=developer
kubectl auth can-i create clusterrolebindings --as=developer

echo
echo "== SRE tests =="
kubectl auth can-i get nodes --as=sre
kubectl auth can-i patch deployments --as=sre -n dev
