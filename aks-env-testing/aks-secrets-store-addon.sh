az group create --name remove-on-sight --location uksouth
az aks create --name securaks --resource-group remove-on-sight --enable-addons azure-keyvault-secrets-provider --enable-oidc-issuer --enable-workload-identity --generate-ssh-keys
az aks get-credentials --name securaks --resource-group remove-on-sight
kubectl get pods -n kube-system -l 'app in (secrets-store-csi-driver,secrets-store-provider-azure)'
az keyvault create --name akskeys4242321 --resource-group remove-on-sight --location uksouth --enable-rbac-authorization
az keyvault secret set --vault-name akskeys4242321 --name ExampleSecret --value MyAKSExampleSecret
