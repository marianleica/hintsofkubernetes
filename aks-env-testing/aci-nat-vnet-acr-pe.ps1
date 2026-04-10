# Requires: Azure CLI logged in (az login)
# Recommended: set correct subscription first:
# az account set --subscription "<SUBSCRIPTION_ID>"

$ErrorActionPreference = "Stop"

# -------------------------
# Variables
# -------------------------
$prefix         = "reproaciacr"
$location       = "italynorth"

$rand           = (Get-Random -Maximum 99999)
$rg             = "$prefix-rg-$rand"

$vnetName       = "$prefix-vnet-$rand"
$vnetCidr       = "10.50.0.0/16"

$aciSubnetName  = "aci-subnet"
$aciSubnetCidr  = "10.50.1.0/24"   # /29 is minimum, /24 is simpler for repro

$peSubnetName   = "pe-subnet"
$peSubnetCidr   = "10.50.2.0/24"

$acrName        = ("acr" + $prefix + $rand).ToLower()   # must be globally unique, 5-50 chars, alnum
$acrSku         = "Premium"

$peName         = "$prefix-pe-acr-$rand"
$peConnName     = "$prefix-conn-$rand"

$privateDnsZone = "privatelink.azurecr.io"
$dnsLinkName    = "$prefix-dnslink-$rand"
$dnsZoneGroup   = "$prefix-zonegroup-$rand"

$repoName       = "nginx"
$tag            = "repro-$rand"
$sourceImage    = "docker.io/library/nginx:latest"
$importedImage  = "$repoName`:$tag"

$aciName        = "$prefix-aci-$rand"

# NAT GW (no public IP/prefix in this repro phase)
$natName        = "$prefix-nat-$rand"

Write-Host "Resource Group: $rg"
Write-Host "ACR Name:       $acrName"
Write-Host "ACI Name:       $aciName"
Write-Host "Region:         $location"

# -------------------------
# 1) Resource group
# -------------------------
az group create `
  --name $rg `
  --location $location | Out-Null

# -------------------------
# 2) VNET + subnets
#    - ACI subnet must be delegated to Microsoft.ContainerInstance/containerGroups
# -------------------------
az network vnet create `
  --resource-group $rg `
  --name $vnetName `
  --location $location `
  --address-prefixes $vnetCidr | Out-Null

# ACI delegated subnet
az network vnet subnet create `
  --resource-group $rg `
  --vnet-name $vnetName `
  --name $aciSubnetName `
  --address-prefixes $aciSubnetCidr `
  --delegations Microsoft.ContainerInstance/containerGroups | Out-Null

# Private Endpoint subnet
az network vnet subnet create `
  --resource-group $rg `
  --vnet-name $vnetName `
  --name $peSubnetName `
  --address-prefixes $peSubnetCidr | Out-Null

# Get subnet IDs
$aciSubnetId = az network vnet subnet show `
  --resource-group $rg `
  --vnet-name $vnetName `
  --name $aciSubnetName `
  --query id -o tsv

$peSubnetId = az network vnet subnet show `
  --resource-group $rg `
  --vnet-name $vnetName `
  --name $peSubnetName `
  --query id -o tsv

# -------------------------
# 3) NAT Gateway WITHOUT public IP
#    Associate it to the ACI subnet.
#    (No internet egress until you add public IP/prefix later)
# -------------------------
az network nat gateway create `
  --resource-group $rg `
  --name $natName `
  --location $location `
  --idle-timeout 4 `
  --sku Standard | Out-Null

az network vnet subnet update `
  --resource-group $rg `
  --vnet-name $vnetName `
  --name $aciSubnetName `
  --nat-gateway $natName | Out-Null

# -------------------------
# 4) Create ACR Premium
# -------------------------
az acr create `
  --resource-group $rg `
  --name $acrName `
  --sku $acrSku `
  --location $location | Out-Null

# Enable admin (simplest auth for ACI repro)
az acr update `
  --name $acrName `
  --admin-enabled true | Out-Null

# Get ACR resource id + login server
$acrId = az acr show --name $acrName --resource-group $rg --query id -o tsv
$acrLoginServer = az acr show --name $acrName --resource-group $rg --query loginServer -o tsv

# -------------------------
# 5) Private DNS Zone + link to VNET
# -------------------------
az network private-dns zone create `
  --resource-group $rg `
  --name $privateDnsZone | Out-Null

$vnetId = az network vnet show --resource-group $rg --name $vnetName --query id -o tsv

az network private-dns link vnet create `
  --resource-group $rg `
  --zone-name $privateDnsZone `
  --name $dnsLinkName `
  --virtual-network $vnetId `
  --registration-enabled false | Out-Null

# -------------------------
# 6) Create Private Endpoint for ACR in PE subnet
#    Include BOTH group-ids for pulls:
#      - registry (control plane)
#      - registry_data (data plane)
# -------------------------
az network private-endpoint create `
  --resource-group $rg `
  --name $peName `
  --location $location `
  --subnet $peSubnetId `
  --private-connection-resource-id $acrId `
  --group-ids registry `
  --connection-name $peConnName | Out-Null

# Attach Private DNS Zone to the Private Endpoint (zone group)
az network private-endpoint dns-zone-group create `
  --resource-group $rg `
  --endpoint-name $peName `
  --name $dnsZoneGroup `
  --private-dns-zone $privateDnsZone `
  --zone-name $privateDnsZone | Out-Null

# -------------------------
# 7) Import hello-world into ACR
#    Store image reference in a variable
# -------------------------
az acr import `
  --name $acrName `
  --source $sourceImage `
  --image $importedImage | Out-Null

# Full image reference for ACI
$imageRef = "$acrLoginServer/$repoName`:$tag"
Write-Host "Imported image ref: $imageRef"

# -------------------------
# 8) Disable public network access on ACR
# -------------------------
az acr update `
  --name $acrName `
  --public-network-enabled false | Out-Null

# -------------------------
# 9) Create ACI in delegated subnet and pull from ACR via Private Endpoint DNS
#    Use ACR admin creds for simplicity
# -------------------------
$acrUser = az acr credential show --name $acrName --query username -o tsv
$acrPass = az acr credential show --name $acrName --query "passwords[0].value" -o tsv

# ACI will pull on container group creation. If you want it to "pull each time it starts",
# use a unique tag each run OR delete/recreate the container group.
az container create `
  --resource-group $rg `
  --name $aciName `
  --location $location `
  --image $imageRef `
  --vnet $vnetId `
  --subnet $aciSubnetId `
  --registry-login-server $acrLoginServer `
  --registry-username $acrUser `
  --registry-password $acrPass `
  --restart-policy Never `
  --os-type Linux `
  --cpu 1 `
  --memory 1.5 | Out-Null

Write-Host "`nRepro deployed successfully."
Write-Host "Next checks:"
Write-Host "  - Validate DNS resolution from within ACI (optional exec): nslookup $acrLoginServer"
Write-Host "  - Then add a Public IP to NAT GW to reproduce the 'switch to public endpoint' behavior."

#
#ERROR: (InaccessibleImage) The image 'acrreproaciacr66244.azurecr.io/hello-world:repro-66244' in container group 'reproaciacr-aci-66244' is not accessible. Please check the image and registry credential.
#Code: InaccessibleImage
#Message: The image 'acrreproaciacr66244.azurecr.io/hello-world:repro-66244' in container group 'reproaciacr-aci-66244' is not accessible. Please check the image and registry credential.
#

# Adding temp public IP

# Create a Standard Public IP (static)
$natPipName = "$prefix-natpip-$rand"

az network public-ip create `
  --resource-group $rg `
  --name $natPipName `
  --location $location `
  --sku Standard `
  --allocation-method Static | Out-Null

# Associate the Public IP to the NAT Gateway
az network nat gateway update `
  --resource-group $rg `
  --name $natName `
  --public-ip-addresses $natPipName | Out-Null

# Checking
az container create `
  --resource-group $rg `
  --name $aciName `
  --location $location `
  --image $imageRef `
  --vnet $vnetId `
  --subnet $aciSubnetId `
  --registry-login-server $acrLoginServer `
  --registry-username $acrUser `
  --registry-password $acrPass `
  --restart-policy Never `
  --os-type Linux `
  --cpu 1 `
  --memory 1.5 | Out-Null

# Remove public IP from NAT Gateway

# Remove the public IP association from the NAT gateway
az network nat gateway update `
  --resource-group $rg `
  --name $natName `
  --remove publicIpAddresses | Out-Null

# Delete the public IP resource (optional cleanup)
az network public-ip delete `
  --resource-group $rg `
  --name $natPipName
#


# Trying registry id

az identity create --resource-group $rg --name myACRId

# Get resource ID of the user-assigned identity
$USERID=$(az identity show --resource-group $rg --name myACRId --query id --output tsv)
# Get service principal ID of the user-assigned identity
$SPID=$(az identity show --resource-group $rg --name myACRId --query principalId --output tsv)

echo $USERID
echo $SPID

az role assignment create --assignee $SPID --scope $acrId --role acrpull

