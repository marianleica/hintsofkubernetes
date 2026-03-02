#!/bin/bash
# Build cluster with kubenet and calico network policy
az group create -n azrez -l uksouth
az aks create -n akstst -g azrez --node-count 1 --network-plugin kubenet --generate-ssh-keys --enable-addons monitoring --enable-managed-identity --enable-network-policy calico
az aks nodepool add -n npcalico -g azrez --cluster-name akstst --enable-cluster-autoscaler --min-count 2 --max-count 4 --network-plugin kubenet --enable-network-policy calico --mode User

# Remove calico network policy plugin
az aks nodepool update -n npcalico -g azrez --cluster-name akstst --network-policy none

# Check crds for projectcalico.org
az aks get-credentials -n akstst -g azrez --admin --overwrite-existing
kubectl get crds | grep projectcalico.org

# Migrate from kubenet to overlay 
az aks nodepool update -n appnodes -g azrez --cluster-name akstst --network-cni azure --network-plugin overlay

# Check crds for projectcalico.org again
kubectl get crds | grep projectcalico.org