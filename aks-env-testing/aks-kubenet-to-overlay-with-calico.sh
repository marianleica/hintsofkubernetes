#!/bin/bash
# Build cluster with kubenet and calico network policy
az group create -n azrez -l uksouth
az aks create -n akstst -g azrez --node-count 1 --network-plugin kubenet --generate-ssh-keys --enable-addons monitoring --enable-managed-identity --network-policy calico
az aks nodepool add -n npcalico -g azrez --cluster-name akstst --enable-cluster-autoscaler --min-count 1 --max-count 2 --mode User

# Check crds for projectcalico.org
az aks get-credentials -n akstst -g azrez --admin --overwrite-existing
kubectl get crds | grep projectcalico.org

#

NAME                                                    CREATED AT
adminnetworkpolicies.policy.networking.k8s.io           2026-03-02T21:14:18Z
apiservers.operator.tigera.io                           2026-03-02T21:12:23Z
baselineadminnetworkpolicies.policy.networking.k8s.io   2026-03-02T21:14:17Z
bgpconfigurations.crd.projectcalico.org                 2026-03-02T21:12:23Z
bgpfilters.crd.projectcalico.org                        2026-03-02T21:14:17Z
bgppeers.crd.projectcalico.org                          2026-03-02T21:14:17Z
blockaffinities.crd.projectcalico.org                   2026-03-02T21:14:17Z
caliconodestatuses.crd.projectcalico.org                2026-03-02T21:14:17Z
clusterinformations.crd.projectcalico.org               2026-03-02T21:14:17Z
felixconfigurations.crd.projectcalico.org               2026-03-02T21:12:23Z
gatewayapis.operator.tigera.io                          2026-03-02T21:14:18Z
globalnetworkpolicies.crd.projectcalico.org             2026-03-02T21:14:17Z
globalnetworksets.crd.projectcalico.org                 2026-03-02T21:14:18Z
goldmanes.operator.tigera.io                            2026-03-02T21:14:18Z
hostendpoints.crd.projectcalico.org                     2026-03-02T21:14:17Z
imagesets.operator.tigera.io                            2026-03-02T21:12:23Z
installations.operator.tigera.io                        2026-03-02T21:12:23Z
ipamblocks.crd.projectcalico.org                        2026-03-02T21:14:17Z
ipamconfigs.crd.projectcalico.org                       2026-03-02T21:14:17Z
ipamhandles.crd.projectcalico.org                       2026-03-02T21:14:17Z
ippools.crd.projectcalico.org                           2026-03-02T21:12:23Z
ipreservations.crd.projectcalico.org                    2026-03-02T21:14:17Z
kubecontrollersconfigurations.crd.projectcalico.org     2026-03-02T21:12:23Z
managementclusterconnections.operator.tigera.io         2026-03-02T21:14:18Z
networkpolicies.crd.projectcalico.org                   2026-03-02T21:14:17Z
networksets.crd.projectcalico.org                       2026-03-02T21:14:17Z
stagedglobalnetworkpolicies.crd.projectcalico.org       2026-03-02T21:14:17Z
stagedkubernetesnetworkpolicies.crd.projectcalico.org   2026-03-02T21:14:18Z
stagednetworkpolicies.crd.projectcalico.org             2026-03-02T21:14:17Z
tiers.crd.projectcalico.org                             2026-03-02T21:14:17Z
tigerastatuses.operator.tigera.io                       2026-03-02T21:12:24Z
volumesnapshotclasses.snapshot.storage.k8s.io           2026-03-02T21:12:10Z
volumesnapshotcontents.snapshot.storage.k8s.io          2026-03-02T21:12:10Z
volumesnapshots.snapshot.storage.k8s.io                 2026-03-02T21:12:10Z
whiskers.operator.tigera.io                             2026-03-02T21:14:18Z

#

# Remove calico network policy plugin
az aks update -g azrez -n akstst --network-policy none

#

NAME                                                    CREATED AT
adminnetworkpolicies.policy.networking.k8s.io           2026-03-02T21:14:18Z
apiservers.operator.tigera.io                           2026-03-02T21:12:23Z
baselineadminnetworkpolicies.policy.networking.k8s.io   2026-03-02T21:14:17Z
bgpconfigurations.crd.projectcalico.org                 2026-03-02T21:12:23Z
bgpfilters.crd.projectcalico.org                        2026-03-02T21:14:17Z
bgppeers.crd.projectcalico.org                          2026-03-02T21:14:17Z
blockaffinities.crd.projectcalico.org                   2026-03-02T21:14:17Z
caliconodestatuses.crd.projectcalico.org                2026-03-02T21:14:17Z
clusterinformations.crd.projectcalico.org               2026-03-02T21:14:17Z
felixconfigurations.crd.projectcalico.org               2026-03-02T21:12:23Z
gatewayapis.operator.tigera.io                          2026-03-02T21:14:18Z
globalnetworkpolicies.crd.projectcalico.org             2026-03-02T21:14:17Z
globalnetworksets.crd.projectcalico.org                 2026-03-02T21:14:18Z
goldmanes.operator.tigera.io                            2026-03-02T21:14:18Z
hostendpoints.crd.projectcalico.org                     2026-03-02T21:14:17Z
imagesets.operator.tigera.io                            2026-03-02T21:12:23Z
installations.operator.tigera.io                        2026-03-02T21:12:23Z
ipamblocks.crd.projectcalico.org                        2026-03-02T21:14:17Z
ipamconfigs.crd.projectcalico.org                       2026-03-02T21:14:17Z
ipamhandles.crd.projectcalico.org                       2026-03-02T21:14:17Z
ippools.crd.projectcalico.org                           2026-03-02T21:12:23Z
ipreservations.crd.projectcalico.org                    2026-03-02T21:14:17Z
kubecontrollersconfigurations.crd.projectcalico.org     2026-03-02T21:12:23Z
managementclusterconnections.operator.tigera.io         2026-03-02T21:14:18Z
networkpolicies.crd.projectcalico.org                   2026-03-02T21:14:17Z
networksets.crd.projectcalico.org                       2026-03-02T21:14:17Z
stagedglobalnetworkpolicies.crd.projectcalico.org       2026-03-02T21:14:17Z
stagedkubernetesnetworkpolicies.crd.projectcalico.org   2026-03-02T21:14:18Z
stagednetworkpolicies.crd.projectcalico.org             2026-03-02T21:14:17Z
tiers.crd.projectcalico.org                             2026-03-02T21:14:17Z
tigerastatuses.operator.tigera.io                       2026-03-02T21:12:24Z
volumesnapshotclasses.snapshot.storage.k8s.io           2026-03-02T21:12:10Z
volumesnapshotcontents.snapshot.storage.k8s.io          2026-03-02T21:12:10Z
volumesnapshots.snapshot.storage.k8s.io                 2026-03-02T21:12:10Z
whiskers.operator.tigera.io                             2026-03-02T21:14:18Z

#

# Migrate from kubenet to overlay 
az aks update -g azrez -n akstst --network-plugin azure --network-plugin-mode overlay

# Check crds for projectcalico.org again
kubectl get crds | grep projectcalico.org

kubectl delete crd apiservers.operator.tigera.io bgpconfigurations.crd.projectcalico.org bgpfilters.crd.projectcalico.org bgppeers.crd.projectcalico.org blockaffinities.crd.projectcalico.org caliconodestatuses.crd.projectcalico.org clusterinformations.crd.projectcalico.org felixconfigurations.crd.projectcalico.org gatewayapis.operator.tigera.io globalnetworkpolicies.crd.projectcalico.org globalnetworksets.crd.projectcalico.org goldmanes.operator.tigera.io hostendpoints.crd.projectcalico.org imagesets.operator.tigera.io installations.operator.tigera.io ipamblocks.crd.projectcalico.org ipamconfigs.crd.projectcalico.org ipamhandles.crd.projectcalico.org ippools.crd.projectcalico.org ipreservations.crd.projectcalico.org kubecontrollersconfigurations.crd.projectcalico.org managementclusterconnections.operator.tigera.io networkpolicies.crd.projectcalico.org networksets.crd.projectcalico.org stagedglobalnetworkpolicies.crd.projectcalico.org stagedkubernetesnetworkpolicies.crd.projectcalico.org stagednetworkpolicies.crd.projectcalico.org tiers.crd.projectcalico.org tigerastatuses.operator.tigera.io whiskers.operator.tigera.io

# Enable back calico network policy plugin
az aks update -g azrez -n akstst --network-policy calico