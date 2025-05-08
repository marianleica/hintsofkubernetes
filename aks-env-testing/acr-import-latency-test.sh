# Creating the two ACRs
az group create -n aztest -l westus
az acr create --name acr67567fg1 --resource-group aztest --sku Premium --location westus
az acr create --name acriuyt67r2 --resource-group aztest --sku Premium --location uaenorth

# Check
az acr list -o table

# add a test image to acr
az acr import --name acr67567fg1 --source mcr.microsoft.com/dotnet/samples:aspnetapp

# See storage space in acr67567fg1
az acr repository show --name acr67567fg1 --image dotnet/samples:aspnetapp --query "contentProperties.size" -o table

# Query the total used space in an ACR
az acr show-usage --name acr67567fg1 -g aztest -o table

# We have 450 MB of space used in acr67567fg1

# now import from acr67567fg1 to acriuyt67r2
az acr import --name acriuyt67r2 --source acr67567fg1.azurecr.io/dotnet/samples:aspnetapp --debug

# Command ran in 75.148 seconds
az acr show-usage --name acriuyt67r2 -g aztest -o table
