Write-Output "Creating an Azure Container Registry (ACR)"
Start-Sleep -Seconds 1

# Setting variables
$timestamp = $(Get-Date -Format "yyyy/MM/dd-HH:mm UTCK")
$scenario="azacr-public"
$suffix=$(Get-Random -Minimum 10000 -Maximum 99999)
#suffix=$((10000 + RANDOM % 99999))
$rg="azrez"
$location="uksouth"
$acr="azacrpublic${suffix}"
$acrpath=${acr}.azurecr.io

az group create -n $rg -l $location

# Create the ACR resource
az acr create -n $acr -g $rg --sku Premium

# Login to ACR
az acr login --name $acr

# Add a basic image to the repository
az acr import -n $acr --source docker.io/library/hello-world:latest -t helloworld:test1