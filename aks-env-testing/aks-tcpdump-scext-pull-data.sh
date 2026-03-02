az group create --name remove-on-sight --location uksouth
az aks create --name securaks --resource-group remove-on-sight --enable-addons azure-keyvault-secrets-provider --enable-oidc-issuer --enable-workload-identity --generate-ssh-keys --enable-blob-driver --node-count 1
az aks get-credentials --name securaks --resource-group remove-on-sight
kubectl get pods -n kube-system -l 'app in (secrets-store-csi-driver,secrets-store-provider-azure)'
az keyvault create --name akskeys4242321 --resource-group remove-on-sight --location uksouth --enable-rbac-authorization
az keyvault secret set --vault-name akskeys4242321 --name ExampleSecret --value MyAKSExampleSecret

# Service connection between AKS and Key Vault
# https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-identity-access?tabs=azure-portal&pivots=access-with-service-connector

az provider register -n Microsoft.ServiceLinker
az provider register -n Microsoft.KubernetesConfiguration

az aks connection create keyvault --connection kvscconnection --resource-group remove-on-sight --name securaks --target-resource-group remove-on-sight --vault akskeys4242321 --enable-csi --client-type none

# The image tag:
scaksextension.azurecr.io/prod/image/sc-operator:20251013.1

# Select a cluster node from the kubectl get nodes output
kubectl get nodes

# Connect to the cluster node as /host
kubectl debug node/aks-nodepool1-38200768-vmss000001 -it --image mcr.microsoft.com/dotnet/runtime-deps:6.0 -- chroot /host

# Inside the node, test pulling the SCExtension image
crictl pull scaksextension.azurecr.io/prod/image/sc-operator:20251013.1

# On the node, install tcpdump and capture traffic
apt-get update && apt-get install -y tcpdump

# Start to capture all traffic to the SCExtension registry
tcpdump --snapshot-length=0 -vvv -w /pullscext.cap

# From another debug node session test pulling the image again to generate traffic, do it a couple of times
crictl pull scaksextension.azurecr.io/prod/image/sc-operator:20251013.1

# Stop the tcpdump (Ctrl+C) and exit the debug node session

# Copy the capture file to local machine path
kubectl cp node-debugger-aks-nodepool1-38200768-vmss000001-ndq2f:host/pullscext.cap pullscext.cap

