# Setting variables
$timestamp = $(Get-Date -Format "yyyy/MM/dd-HH:mm UTCK")
$suffix=$(Get-Random -Minimum 10000 -Maximum 99999)
$RG="azrez" # Name of resource group for the AKS cluster
$location="uksouth" # Name of the location 
$AKS="aks-azurecni-${suffix}" # Name of the AKS cluster

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
az aks create --resource-group $RG --name $AKS --node-count 1 --network-plugin azure --vnet-subnet-id $subnetId --enable-aad --generate-ssh-keys --enable-addons policy
Start-Sleep -Seconds 5

az aks get-credentials --resource-group $RG --name $AKS --admin --overwrite-existing

###################################################

$constrainttemplate = @"
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sblocksystemauthenticated
spec:
  crd:
    spec:
      names:
        kind: K8sBlockSystemAuthenticated
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblocksystemauthenticated

        violation[{"msg": msg}] {
          input.review.kind.kind == "ClusterRoleBinding"
          subject := input.review.object.subjects[_]
          subject.kind == "Group"
          subject.name == "system:authenticated"
          msg := "ClusterRoleBinding to system:authenticated is not allowed"
        }
"@

$constrainttemplate | kubectl apply -f -

$constraint = @"
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockSystemAuthenticated
metadata:
  name: block-clusterrolebinding-system-authenticated
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["ClusterRoleBinding"]
"@

$constraint | kubectl apply -f -

##################

# Creating clusterrolebinding yaml for system:authenticated
while ($true){

$crb = @"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: test-system-authenticated-binding
subjects:
  - kind: Group
    name: system:authenticated
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
"@
$crb | kubectl apply -f -

kubectl delete clusterrolebinding test-system-authenticated-binding
}

$ilbservice = @"

"@

$ilbservice | kubectl apply -f -

# Trigger a scan of the policy state
az policy state trigger-scan --resource-group azrez

# Policy definition JSON
{
  "mode": "Microsoft.Kubernetes.Data",
  "policyRule": {
    "if": {
      "field": "type",
      "in": [
        "AKS Engine",
        "Microsoft.Kubernetes/connectedClusters",
        "Microsoft.ContainerService/managedClusters"
      ]
    },
    "then": {
      "effect": "[parameters('effect')]",
      "details": {
        "templateInfo": {
          "sourceType": "Base64Encoded",
          "content": "YXBpVmVyc2lvbjogdGVtcGxhdGVzLmdhdGVrZWVwZXIuc2gvdjFiZXRhMQpraW5kOiBDb25zdHJhaW50VGVtcGxhdGUKbWV0YWRhdGE6CiAgbmFtZTogYmxvY2stY2x1c3RlcnJvbGViaW5kaW5nLXN5c3RlbS1hdXRoZW50aWNhdGVkCnNwZWM6CiAgY3JkOgogICAgc3BlYzoKICAgICAgbmFtZXM6CiAgICAgICAga2luZDogQmxvY2tDbHVzdGVyUm9sZUJpbmRpbmdTeXN0ZW1BdXRoZW50aWNhdGVkCiAgdGFyZ2V0czoKICAgIC0gdGFyZ2V0OiBhZG1pc3Npb24uazhzLmdhdGVrZWVwZXIuc2gKICAgICAgcmVnbzogfAogICAgICAgIHBhY2thZ2UgY2x1c3RlcnJvbGViaW5kaW5nLmRlbnlhdXRoZW50aWNhdGVkCgogICAgICAgIHZpb2xhdGlvblt7Im1zZyI6IG1zZ31dIHsKICAgICAgICAgIGlucHV0LnJldmlldy5raW5kLmtpbmQgPT0gIkNsdXN0ZXJSb2xlQmluZGluZyIKICAgICAgICAgIHNvbWUgaQogICAgICAgICAgaW5wdXQucmV2aWV3Lm9iamVjdC5zdWJqZWN0c1tpXS5uYW1lID09ICJzeXN0ZW06YXV0aGVudGljYXRlZCIKICAgICAgICAgIG1zZyA6PSAiQ2x1c3RlclJvbGVCaW5kaW5nIHdpdGggc3lzdGVtOmF1dGhlbnRpY2F0ZWQgc3ViamVjdCBpcyBub3QgYWxsb3dlZCIKICAgICAgICB9Cg=="
        },
        "apiGroups": [
          "rbac.authorization.k8s.io"
        ],
        "kinds": [
          "ClusterRoleBinding"
        ]
      }
    }
  },
  "parameters": {
    "effect": {
      "type": "String",
      "metadata": {
        "displayName": "Effect",
        "description": "Enable or disable the execution of the policy"
      },
      "allowedValues": [
        "audit",
        "deny",
        "disabled"
      ],
      "defaultValue": "audit"
    }
  }
}

apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: block-clusterrolebinding-system-authenticated
spec:
  crd:
    spec:
      names:
        kind: BlockClusterRoleBindingSystemAuthenticated
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package clusterrolebinding.denyauthenticated

        violation[{"msg": msg}] {
          input.review.kind.kind == "ClusterRoleBinding"
          some i
          input.review.object.subjects[i].name == "system:authenticated"
          msg := "ClusterRoleBinding with system:authenticated subject is not allowed"
        }


YXBpVmVyc2lvbjogdGVtcGxhdGVzLmdhdGVrZWVwZXIuc2gvdjFiZXRhMQpraW5kOiBDb25zdHJhaW50VGVtcGxhdGUKbWV0YWRhdGE6CiAgbmFtZTogYmxvY2stY2x1c3RlcnJvbGViaW5kaW5nLXN5c3RlbS1hdXRoZW50aWNhdGVkCnNwZWM6CiAgY3JkOgogICAgc3BlYzoKICAgICAgbmFtZXM6CiAgICAgICAga2luZDogQmxvY2tDbHVzdGVyUm9sZUJpbmRpbmdTeXN0ZW1BdXRoZW50aWNhdGVkCiAgdGFyZ2V0czoKICAgIC0gdGFyZ2V0OiBhZG1pc3Npb24uazhzLmdhdGVrZWVwZXIuc2gKICAgICAgcmVnbzogfAogICAgICAgIHBhY2thZ2UgY2x1c3RlcnJvbGViaW5kaW5nLmRlbnlhdXRoZW50aWNhdGVkCgogICAgICAgIHZpb2xhdGlvblt7Im1zZyI6IG1zZ31dIHsKICAgICAgICAgIGlucHV0LnJldmlldy5raW5kLmtpbmQgPT0gIkNsdXN0ZXJSb2xlQmluZGluZyIKICAgICAgICAgIHNvbWUgaQogICAgICAgICAgaW5wdXQucmV2aWV3Lm9iamVjdC5zdWJqZWN0c1tpXS5uYW1lID09ICJzeXN0ZW06YXV0aGVudGljYXRlZCIKICAgICAgICAgIG1zZyA6PSAiQ2x1c3RlclJvbGVCaW5kaW5nIHdpdGggc3lzdGVtOmF1dGhlbnRpY2F0ZWQgc3ViamVjdCBpcyBub3QgYWxsb3dlZCIKICAgICAgICB9Cg==