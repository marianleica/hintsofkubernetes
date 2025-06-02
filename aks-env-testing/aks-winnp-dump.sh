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

echo ""
read -n 1 -s -r -p "Press any key to continue..."
echo

nodeName=$(kubectl get no --no-headers | grep -i win | awk '{print $1}')

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

kubectl exec hpc -it -- powershell

(1) Prepare the node by cordoning and draining it:
kubectl get nodes
kubectl cordon $nodeName
kubectl drain $nodeName

# Also, do you have auto-scaler enabled for this node pool? Information on our side shows it is not enabled, but just to double-check with you.

# If it's enabled, annotate this node so that we avoid it getting deleted due to issues AKS might try to remmediate.
kubectl annotate node $nodeName cluster-autoscaler.kubernetes.io/scale-down-disabled=true

(2) Check the current configuration:

```powershell
Get-WmiObject Win32_OSRecoveryConfiguration -EnableAllPrivileges | fl *DebugInfoType*
```

# From this list, we'll have to modify the DebugInfoType parameter so that it is generating a Complete Memory Dump, option 1.
```powershell
Get-WmiObject -Class Win32_OSRecoveryConfiguration -EnableAllPrivileges | Set-WmiInstance -Arguments @{ DebugInfoType=1 }
```

(3) We'll need a pagefile of RAM size + 300 MB for generating a complete memory dump, you may run the commands below for setting this up and confirm with the last command:
```powershell
$pagefile = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges
$pagefile.AutomaticManagedPagefile = $false
$pagefile.put() | Out-Null
 
$pagefileset = Get-WmiObject Win32_pagefilesetting
$pagefileset.InitialSize = 16684
$pagefileset.MaximumSize = 18000
$pagefileset.Put() | Out-Null
 
Gwmi win32_Pagefilesetting | Select Name, InitialSize, MaximumSize
```

# Example: Restart all nodes in a nodepool using az aks nodepool
az aks nodepool stop --resource-group "$RG" --cluster-name "$AKS" --name winnp
az aks nodepool start --resource-group "$RG" --cluster-name "$AKS" --name winnp
az aks vmss list -g $infra_rg -o table
az aks restart -n akswinnp000001 -g $infra_rg


