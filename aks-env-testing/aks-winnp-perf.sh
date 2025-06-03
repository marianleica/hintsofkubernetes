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
# Adding some workload

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample
  labels:
    app: sample
spec:
  replicas: 1
  template:
    metadata:
      name: sample
      labels:
        app: sample
    spec:
      nodeSelector:
        "kubernetes.io/hostname": $nodeName
      containers:
      - name: sample
        image: mcr.microsoft.com/dotnet/framework/samples:aspnetapp
        resources:
          limits:
            cpu: 1
            memory: 100M
#          requests:
#            cpu: 1
#            memory: 100M
        ports:
          - containerPort: 80
  selector:
    matchLabels:
      app: sample
---
apiVersion: v1
kind: Service
metadata:
  name: sample
spec:
  type: LoadBalancer
  ports:
  - protocol: TCP
    port: 80
  selector:
    app: sample
EOF

kubectl top nodes

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

# <wait maximum of 2 mins and then stop>
wpr -stop p.etl -skipPdbGen

# Stop perfmon tracing
logman stop Perfmon_Basic-Counters
  
# Archive C:\Perflogs and upload via HPC to local console, then zip and upload to DTM


