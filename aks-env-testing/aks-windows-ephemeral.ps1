# Scenario: AKS Windows 2022. Restart the Windows node instance and check if the data is still available in the node's ephemeral os disk after the restart.
#############

# Setting variables
$timestamp = $(Get-Date -Format "yyyy/MM/dd-HH:mm UTCK")
$scenario = "azaks-windowsnp"
$suffix=$(Get-Random -Minimum 10000 -Maximum 99999)
$RG="azrez" # Name of resource group for the AKS cluster
$location="eastus2" # Name of the location 
$AKS="aks-azurecni-${suffix}" # Name of the AKS cluster
$WINDOWS_USERNAME="azrez"
$WINDOWS_PASSWORD= -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 30 | ForEach-Object {[char]$_})

Write-Output "Creating AKS cluster ${AKS} in resource group ${RG}"
# Create new Resource Group
Write-Output "The resource group: "
az group create -n $RG -l $location

# Create virtual network and subnets
Write-Output "The BYO VNET: "
az network vnet create --resource-group $RG --name aksVnet --address-prefixes 10.0.0.0/8 --subnet-name aks_subnet --subnet-prefix 10.240.0.0/16
Write-Output "The BYO VNET subnet: "
az network vnet subnet create --resource-group $RG --vnet-name aksVnet --name vnode_subnet --address-prefixes 10.241.0.0/16

# Create AKS cluster
$subnetId=$(az network vnet subnet show --resource-group $RG --vnet-name aksVnet --name aks_subnet --query id -o tsv)

Start-Sleep 2

Write-Output "The AKS cluster: "
az aks create --resource-group $RG --name $AKS --node-count 1 --network-plugin azure --vnet-subnet-id $subnetId --enable-aad --generate-ssh-keys --windows-admin-username $WINDOWS_USERNAME --windows-admin-password $WINDOWS_PASSWORD --enable-addons monitoring
Start-Sleep -Seconds 5

# Get the AKS infrastructure resource group name
$infra_rg=$(az aks show --resource-group $RG --name $AKS --output tsv --query nodeResourceGroup)
Write-Output "The infrastructure resource group is ${infra_rg}"

az aks nodepool add --resource-group $RG --cluster-name $AKS --os-type Windows --os-sku Windows2022 --name winnp --node-count 1 --node-vm-size Standard_D4ds_v5 --node-osdisk-type Ephemeral 

Start-Sleep -Seconds 1
Write-Output "Configuring kubectl to connect to the Kubernetes cluster"
az aks get-credentials --resource-group $RG --name $AKS --admin --overwrite-existing
Write-Output "You should be able to run kubectl commands to your cluster now"

# Connect the the Windows cluster node via Host Compute Service
$nodeName = "akswinnp000000"

@"
apiVersion: v1
kind: Pod
metadata:
  labels:
    pod: hpc
  name: hpc
spec:
  securityContext:
    windowsOptions:
      hostProcess: true
      runAsUserName: "NT AUTHORITY\\SYSTEM"
  hostNetwork: true
  containers:
    - name: hpc
      image: mcr.microsoft.com/windows/nanoserver:ltsc2022 # Use nanoserver:1809 for WS2019
      command:
        - powershell.exe
        - -Command
        - "Start-Sleep 2147483"
      imagePullPolicy: IfNotPresent
  nodeSelector:
    kubernetes.io/os: windows
    kubernetes.io/hostname: $nodeName
  tolerations:
    - effect: NoSchedule
      key: node.kubernetes.io/unschedulable
      operator: Exists
    - effect: NoSchedule
      key: node.kubernetes.io/network-unavailable
      operator: Exists
    - effect: NoExecute
      key: node.kubernetes.io/unreachable
      operator: Exists
"@ | kubectl apply -f -

# Exec into the hpc pod to access the node
kubectl exec hpc -it -- powershell
# Inside the node, collect data
cd C:\k\debug
powershell .\collect-windows-logs.ps1
# Confirm data files are present
ls aks*
exit

# Restart the VM node instance manually

# Connect back to the node
kubectl exec hpc -it -- powershell
# Check if data is available
cd C:\k\debug
ls aks*