#############
# Environment
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
Write-Output ""

# Create virtual network and subnets
Write-Output "The BYO VNET: "
az network vnet create --resource-group $RG --name aksVnet --address-prefixes 10.0.0.0/8 --subnet-name aks_subnet --subnet-prefix 10.240.0.0/16

Write-Output ""
Write-Output "The BYO VNET subnet: "

az network vnet subnet create --resource-group $RG --vnet-name aksVnet --name vnode_subnet --address-prefixes 10.241.0.0/16

# Create AKS cluster
$subnetId=$(az network vnet subnet show --resource-group $RG --vnet-name aksVnet --name aks_subnet --query id -o tsv)

Write-Output ""
Start-Sleep 2

Write-Output "The AKS cluster: "
az aks create --resource-group $RG --name $AKS --node-count 1 --network-plugin azure --vnet-subnet-id $subnetId --enable-aad --generate-ssh-keys --windows-admin-username $WINDOWS_USERNAME --windows-admin-password $WINDOWS_PASSWORD --enable-addons monitoring
Start-Sleep -Seconds 5

# Get the AKS infrastructure resource group name
$infra_rg=$(az aks show --resource-group $RG --name $AKS --output tsv --query nodeResourceGroup)
Write-Output "The infrastructure resource group is ${infra_rg}"
Write-Output ""

Write-Output ""
az aks nodepool add --resource-group $RG --cluster-name $AKS --os-type Windows --os-sku Windows2022 --name winnp --node-count 1

Write-Output ""
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

#############
# ACTION PLAN
#############

# Install Windows SDK to obtain kd.exe
$sdkUrl = "https://go.microsoft.com/fwlink/?linkid=2349110"
$installerPath = "$env:TEMP\winsdksetup.exe"
Invoke-WebRequest -Uri $sdkUrl -OutFile $installerPath

# Ensure the PowerShell session is running with elevated privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Please run this script in an elevated PowerShell session (Run as Administrator)." -ForegroundColor Red
    exit
}

# Run the installer silently to install ONLY the Debugging Tools
# 'OptionId.WindowsDesktopDebuggers' includes kd.exe and windbg.exe
Start-Process -FilePath $installerPath -ArgumentList "/features OptionId.WindowsDesktopDebuggers /quiet /norestart" -Wait

# Cleanup installer file
Remove-Item $installerPath

# Install LiveKD
# Ensure the temporary directory exists
$TempDir = "C:\Temp"
if (!(Test-Path -Path $TempDir)) {
    New-Item -Path $TempDir -ItemType Directory
}

Invoke-WebRequest -Uri https://download.sysinternals.com/files/LiveKD.zip -OutFile "$TempDir\LiveKD.zip"
Expand-Archive -Path "$TempDir\LiveKD.zip" -DestinationPath "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64"

# Capture the Live Kernel Dump

cd "C:\Program Files (x86)\Windows Kits\10\Debuggers\x64"

# Collect kernel dump (typically very large)
.\livekd.exe -o D:\temp\dumps\memory.dmp

# OR collect mirror kernel dump (typically much smaller but still useful)
.\livekd.exe -m -o D:\temp\dumps\memory_m.dmp

# Both of the above commands capture a live kernel dump without rebooting the system.

# Upload the Dump File to an Azure Storage Account
# Kernel dump files are typically very large, so using an Azure Storage Account is the most reliable way to move the dump off the VM for analysis.

# Prerequisites
# An existing Azure Storage Account with a Blob container
# Either:
# Azure AD permissions (for azcopy login), or
# A SAS token with write permissions
# Upload using AzCopy (recommended)
# Ref: https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10

# Authenticate (if using Azure AD):
azcopy login
# Upload the dump file:
azcopy copy "D:\temp\dumps\memory.dmp" "https://<storageaccount>.blob.core.windows.net/<container>/memory.dmp"
# If you are using a SAS token, append it to the destination URL:
azcopy copy "D:\temp\dumps\memory.dmp" "https://<storageaccount>.blob.core.windows.net/<container>/memory.dmp?<SAS-token>"

# Note: Uploading large dump files can take significant time depending on VM size and network bandwidth.
