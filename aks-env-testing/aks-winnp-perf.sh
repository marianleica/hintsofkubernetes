#!/bin/bash

# Setting variables
timestamp=$(date +"%Y/%m/%d-%H:%M UTCK")
scenario="azaks-windowsnp"
suffix=$(( RANDOM % 90000 + 10000 ))
RG="azrez" # Name of resource group for the AKS cluster
location="uksouth" # Name of the location 
AKS="aks-azurecni-${suffix}" # Name of the AKS cluster
WINDOWS_USERNAME="azrez"
# Generate a random 30-character alphanumeric password
WINDOWS_PASSWORD=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 30)

echo "Creating AKS cluster ${AKS} in resource group ${RG}"
# Create new Resource Group
echo "The resource group: "
az group create -n "$RG" -l "$location"
echo ""

# Create virtual network and subnets
echo "The BYO VNET: "
az network vnet create --resource-group "$RG" --name aksVnet --address-prefixes 10.0.0.0/8 --subnet-name aks_subnet --subnet-prefix 10.240.0.0/16

echo ""
echo "The BYO VNET subnet: "
az network vnet subnet create --resource-group "$RG" --vnet-name aksVnet --name vnode_subnet --address-prefixes 10.241.0.0/16

# Create AKS cluster
subnetId=$(az network vnet subnet show --resource-group "$RG" --vnet-name aksVnet --name aks_subnet --query id -o tsv)

echo ""
sleep 2

echo "The AKS cluster: "
az aks create --resource-group "$RG" --name "$AKS" --node-count 1 --network-plugin azure --vnet-subnet-id "$subnetId" --enable-aad --generate-ssh-keys --windows-admin-username "$WINDOWS_USERNAME" --windows-admin-password "$WINDOWS_PASSWORD" --enable-addons monitoring
sleep 5

# Get the AKS infrastructure resource group name
infra_rg=$(az aks show --resource-group "$RG" --name "$AKS" --output tsv --query nodeResourceGroup)
echo "The infrastructure resource group is ${infra_rg}"
echo ""

echo ""
az aks nodepool add --resource-group "$RG" --cluster-name "$AKS" --os-type Windows --os-sku Windows2022 --name winnp --node-count 1

echo ""
sleep 1
echo "Configuring kubectl to connect to the Kubernetes cluster"
az aks get-credentials --resource-group "$RG" --name "$AKS" --admin --overwrite-existing
echo "You should be able to run kubectl commands to your cluster now"
echo ""
echo "Install kubectl locally, if needed: az aks install-cli"

# Set nodeName variable to the string name of the Windows node to be used in yaml
nodeName=$(kubectl get no --no-headers | grep -i win | awk '{print $1}')
echo $nodeName


# Prepare HPC

kubectl apply -f - <<EOF
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
      runAsUserName: 'NT AUTHORITY\\SYSTEM'
  hostNetwork: true
  containers:
    - name: hpc
      image: mcr.microsoft.com/windows/servercore:ltsc2022 # Use servercore:1809 for WS2019
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
EOF

# Connect to HPC pod
kubectl exec hpc -it -- powershell

# Collecting performance data

# ACTION PLAN - Windows Performance CPU utilization

# PowerShell commands to install PowerShell 7 (Core):
# 1. Download the ZIP package:
Start-BitsTransfer https://github.com/PowerShell/PowerShell/releases/download/v7.4.2/PowerShell-7.4.2-win-x64.zip -Destination C:\PowerShell-7.4.2-win-x64.zip

# 2. Extract the ZIP to a folder, e.g. C:\pwsh742
Expand-Archive -Path C:\PowerShell-7.4.2-win-x64.zip -DestinationPath C:\pwsh742

# 3. Run PowerShell 7 from the extracted folder:
C:\pwsh742\pwsh.exe

mkdir C:\Perflogs
cd C:\Perflogs

# Create a data collector set for perfmon:
logman create counter Perfmon_Basic-Counters -v mmddhhmm -c "\Cache\*" "\Memory\*"  "\Paging File(*)\*" "\PhysicalDisk(*)\*" "\LogicalDisk(*)\*" "\Process(*)\*" "\Processor(*)\*" "\Server\*" "\Server Work Queues(*)\*" "\System\*" -max 500 -si 00:00:1 -o "c:\PerfLogs\Perfmon_Basic-Counters"

# Start the data collector set:
logman start Perfmon_Basic-Counters 

# Start WPR In elevated CMD execute:
wpr -start CPU.light -filemode
# or verbose mode use: wpr -start CPU

############ Here reproduce the issue for up to 2 minutes
# For this test, let's apply CPU stress with https://learn.microsoft.com/en-us/sysinternals/downloads/cpustres
# Download cpustres.exe from https://learn.microsoft.com/en-us/sysinternals/downloads/cpustres
# Start-BitsTransfer https://download.sysinternals.com/files/CPUSTRES.zip -Destination C:\
# Expand-Archive -Path C:\CPUSTRES.zip
# cd C:\CPUSTRES
# and then run it:
#.\CPUSTRES.EXE -c 4 -t 120

# PowerShell: CPU stress script using for loops (corrected for Bash variable expansion issues)
@'
$NumberOfLogicalProcessors = (Get-WmiObject win32_processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum

$jobs = @()
for ($core = 1; $core -le $NumberOfLogicalProcessors; $core++) {
    $jobs += Start-Job -ScriptBlock {
        $result = 1
        for ($loopnumber = 1; $loopnumber -le 100000; $loopnumber++) {
            $result = 1
            for ($loopnumber1 = 1; $loopnumber1 -le 1000; $loopnumber1++) {
                $result = 1
                for ($number = 1; $number -le 100; $number++) {
                    $result = $result * $number
                }
            }
        }
        $result
    }
}

Write-Host "CPU stress started on $NumberOfLogicalProcessors cores. Press Enter to stop..."
Read-Host

$jobs | ForEach-Object { Stop-Job -Id $_.Id }
'@ | Set-Content -Path C:\myscript.ps1

kubectl top nodes

# <wait maximum of 2 mins and then stop>
wpr -stop p.etl -skipPdbGen

# Stop perfmon tracing
logman stop Perfmon_Basic-Counters
  
# Archive C:\Perflogs and upload via HPC to local console, then zip and upload to DTM


