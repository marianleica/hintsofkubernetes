az group create --name remove-on-sight --location uksouth
az aks create --name securaks --resource-group remove-on-sight --enable-addons azure-keyvault-secrets-provider --enable-oidc-issuer --enable-workload-identity --generate-ssh-keys
az aks get-credentials --name securaks --resource-group remove-on-sight
kubectl get pods -n kube-system -l 'app in (secrets-store-csi-driver,secrets-store-provider-azure)'
az keyvault create --name akskeys4242321 --resource-group remove-on-sight --location uksouth --enable-rbac-authorization
az keyvault secret set --vault-name akskeys4242321 --name ExampleSecret --value MyAKSExampleSecret

# Service connection between AKS and Key Vault
# https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-identity-access?tabs=azure-portal&pivots=access-with-service-connector

az provider register -n Microsoft.ServiceLinker
az provider register -n Microsoft.KubernetesConfiguration

az aks connection create keyvault --connection kvscconnection --resource-group remove-on-sight --name securaks --target-resource-group remove-on-sight --vault akskeys4242321 --enable-csi --client-type none

