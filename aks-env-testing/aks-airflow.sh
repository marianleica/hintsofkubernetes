# Ref: https://learn.microsoft.com/en-us/azure/aks/airflow-overview
# Apache Airflow is an open-source platform built for developing, scheduling, and monitoring batch-oriented workflows.
# With its flexible Python framework, Airflow allows you to design workflows that integrate seamlessly with nearly any technology.
# In Airflow, you must define Python workflows, represented by Directed Acyclic Graph (DAG).
# You can deploy Airflow anywhere, and after deploying, you can access Airflow UI and set up workflows.
# 
# Airflow architecture
# At a high level, Airflow includes:
# - A metadata database that tracks the state of DAGs, task instances, XComs, and more.
# - A web server providing the Airflow UI for monitoring and management.
# - A scheduler responsible for triggering DAGs and task instances.
# - Executors that handle the execution of task instances.
# - Workers that perform the tasks.
# - Other components like the Command Line Interface (CLI).
#
# Airflow distributed architecture for production
# Airflow’s modular, distributed architecture offers several key advantages for production workloads:
#
# Separation of concerns: Each component has a distinct role, keeping the system simple and maintainable. The scheduler manages DAGs and task scheduling, while workers execute tasks, ensuring that each part stays focused on its specific function.
# Scalability: As workloads grow, the architecture allows for easy scaling. You can run multiple schedulers or workers concurrently and leverage a hosted database for automatic scaling to accommodate increased demand.
# Reliability: Because components are decoupled, the failure of a single scheduler or worker doesn’t lead to a system-wide outage. The centralized metadata database ensures consistency and continuity across the entire system.
# Extensibility: The architecture is flexible, allowing components like the executor or queueing service to be swapped out and customized as needed.
# (*) This design provides a robust foundation for scaling, reliability, and flexibility in managing complex data pipelines.
#
# Airflow executors
# A very important design decision when making Airflow production-ready is choosing the correct executor.
# When a task is ready to run, the executor is responsible for managing its execution. Executors interact with a pool of workers that carry out the tasks.
# The most commonly used executors are:
# - LocalExecutor: Runs task instances in parallel on the host system. This executor is ideal for testing, but offers limited scalability for larger workloads.
# - CeleryExecutor: Distributes tasks across multiple machines using a Celery pool, providing horizontal scalability by running workers on different nodes.
# - KubernetesExecutor: Tailored for Airflow deployments in Kubernetes, this executor dynamically launches worker Pods within the Kubernetes cluster. It offers excellent scalability and ensures strong resource isolation.
# As we transition Airflow to production, scaling workers becomes essential, making KubernetesExecutor the best fit for our needs. For local testing, however, LocalExecutor is the simplest option.
# 
# Ref: https://learn.microsoft.com/en-us/azure/aks/airflow-create-infrastructure
# Prerequisites
# Prerequisites
# - If you haven't already, review the Overview for deploying an Apache Airflow cluster on Azure Kubernetes Service (AKS).
# - An Azure subscription. If you don't have one, create a free account.
# - Azure CLI version 2.61.0. To install or upgrade, see Install Azure CLI.
# - Helm version 3 or later. To install, see Installing Helm.
# - kubectl, which is installed in Azure Cloud Shell by default.
# - GitHub Repo to store Airflow Dags.
# - Docker installed on your local machine. To install, see Get Docker.
#
# Set environment variables
#
random=$(echo $RANDOM | tr '[0-9]' '[a-z]')
export MY_LOCATION=canadacentral
export MY_RESOURCE_GROUP_NAME=apache-airflow-rg
export MY_IDENTITY_NAME=airflow-identity-123
export MY_ACR_REGISTRY=mydnsrandomname$(echo $random)
export MY_KEYVAULT_NAME=airflow-vault-$(echo $random)-kv
export MY_CLUSTER_NAME=apache-airflow-aks
export SERVICE_ACCOUNT_NAME=airflow
export SERVICE_ACCOUNT_NAMESPACE=airflow
export AKS_AIRFLOW_NAMESPACE=airflow
export AKS_AIRFLOW_CLUSTER_NAME=cluster-aks-airflow
export AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_NAME=airflowsasa$(echo $random)
export AKS_AIRFLOW_LOGS_STORAGE_CONTAINER_NAME=airflow-logs
export AKS_AIRFLOW_LOGS_STORAGE_SECRET_NAME=storage-account-credentials
#
# Create resource group
az group create --name $MY_RESOURCE_GROUP_NAME --location $MY_LOCATION --output table
#
# Create an identity (UMI) to access secrets in Azure Key Vault
#
az identity create --name $MY_IDENTITY_NAME --resource-group $MY_RESOURCE_GROUP_NAME --output table
export MY_IDENTITY_NAME_ID=$(az identity show --name $MY_IDENTITY_NAME --resource-group $MY_RESOURCE_GROUP_NAME --query id --output tsv)
export MY_IDENTITY_NAME_PRINCIPAL_ID=$(az identity show --name $MY_IDENTITY_NAME --resource-group $MY_RESOURCE_GROUP_NAME --query principalId --output tsv)
export MY_IDENTITY_NAME_CLIENT_ID=$(az identity show --name $MY_IDENTITY_NAME --resource-group $MY_RESOURCE_GROUP_NAME --query clientId --output tsv)
#
# Create an Azure Key Vault instance using the az keyvault create command.
az keyvault create --name $MY_KEYVAULT_NAME --resource-group $MY_RESOURCE_GROUP_NAME --location $MY_LOCATION --enable-rbac-authorization false --output table
export KEYVAULTID=$(az keyvault show --name $MY_KEYVAULT_NAME --query "id" --output tsv)
export KEYVAULTURL=$(az keyvault show --name $MY_KEYVAULT_NAME --query "properties.vaultUri" --output tsv)
#
# Create an Azure Container Registry
az acr create --name ${MY_ACR_REGISTRY} --resource-group $MY_RESOURCE_GROUP_NAME --sku Premium --location $MY_LOCATION --admin-enabled true --output table
export MY_ACR_REGISTRY_ID=$(az acr show --name $MY_ACR_REGISTRY --resource-group $MY_RESOURCE_GROUP_NAME --query id --output tsv)
#
# Create an Azure Storage Account
az storage account create --name $AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_NAME --resource-group $MY_RESOURCE_GROUP_NAME --location $MY_LOCATION --sku Standard_ZRS --output table
export AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_KEY=$(az storage account keys list --account-name $AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)
az storage container create --name $AKS_AIRFLOW_LOGS_STORAGE_CONTAINER_NAME --account-name $AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_NAME --output table --account-key $AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_KEY
az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name AKS-AIRFLOW-LOGS-STORAGE-ACCOUNT-NAME --value $AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_NAME
az keyvault secret set --vault-name $MY_KEYVAULT_NAME --name AKS-AIRFLOW-LOGS-STORAGE-ACCOUNT-KEY --value $AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_KEY
#
# Create an Azure Kubernetes Service (AKS) cluster
az aks create --location $MY_LOCATION --name $MY_CLUSTER_NAME --tier standard --resource-group $MY_RESOURCE_GROUP_NAME --network-plugin azure --node-vm-size Standard_DS4_v2 --node-count 1 --auto-upgrade-channel stable --node-os-upgrade-channel NodeImage --attach-acr ${MY_ACR_REGISTRY} --enable-oidc-issuer --enable-blob-driver --enable-workload-identity --zones 1 2 3 --generate-ssh-keys --output table
# Get the OIDC issuer URL to use for the workload identity configuration using the az aks show command.
export OIDC_URL=$(az aks show --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --query oidcIssuerProfile.issuerUrl --output tsv)
#
# Assign the AcrPull role to the kubelet identity using the az role assignment create command
export KUBELET_IDENTITY=$(az aks show -g $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --output tsv --query identityProfile.kubeletidentity.objectId)
az role assignment create --assignee ${KUBELET_IDENTITY} --role "AcrPull" --scope ${MY_ACR_REGISTRY_ID} --output table
#
# Connect to the AKS cluster
az aks get-credentials --resource-group $MY_RESOURCE_GROUP_NAME --name $MY_CLUSTER_NAME --overwrite-existing --output table
#
# Upload Apache Airflow images to your container registry
az acr import --name $MY_ACR_REGISTRY --source docker.io/apache/airflow:airflow-pgbouncer-2024.01.19-1.21.0 --image airflow:airflow-pgbouncer-2024.01.19-1.21.0
az acr import --name $MY_ACR_REGISTRY --source docker.io/apache/airflow:airflow-pgbouncer-exporter-2024.06.18-0.17.0 --image airflow:airflow-pgbouncer-exporter-2024.06.18-0.17.0
az acr import --name $MY_ACR_REGISTRY --source docker.io/bitnami/postgresql:16.1.0-debian-11-r15 --image postgresql:16.1.0-debian-11-r15
az acr import --name $MY_ACR_REGISTRY --source quay.io/prometheus/statsd-exporter:v0.26.1 --image statsd-exporter:v0.26.1 
az acr import --name $MY_ACR_REGISTRY --source docker.io/apache/airflow:2.9.3 --image airflow:2.9.3 
az acr import --name $MY_ACR_REGISTRY --source registry.k8s.io/git-sync/git-sync:v4.1.0 --image git-sync:v4.1.0
#
# Ref: https://learn.microsoft.com/en-us/azure/aks/airflow-deploy
# Configure workload identity
# Create a namespace for the Airflow cluster using the kubectl create namespace command.
kubectl create namespace ${AKS_AIRFLOW_NAMESPACE} --dry-run=client --output yaml | kubectl apply -f -
#
# Create a service account and configure workload identity using the kubectl apply command.
export TENANT_ID=$(az account show --query tenantId -o tsv)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: "${MY_IDENTITY_NAME_CLIENT_ID}"
    azure.workload.identity/tenant-id: "${TENANT_ID}"
  name: "${SERVICE_ACCOUNT_NAME}"
  namespace: "${AKS_AIRFLOW_NAMESPACE}"
EOF
#
# Install the External Secrets Operator
# Add the External Secrets Helm repository and update the repository using the helm repo add and helm repo update commands.
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
# Install the External Secrets Operator using the helm install command.
helm install external-secrets \
external-secrets/external-secrets \
--namespace ${AKS_AIRFLOW_NAMESPACE} \
--create-namespace \
--set installCRDs=true \
--wait
#
# Create secrets
# Create a SecretStore resource to access the Airflow passwords stored in your key vault using the kubectl apply command.
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: azure-store
  namespace: ${AKS_AIRFLOW_NAMESPACE}
spec:
  provider:
    # provider type: azure keyvault
    azurekv:
      authType: WorkloadIdentity
      vaultUrl: "${KEYVAULTURL}"
      serviceAccountRef:
        name: ${SERVICE_ACCOUNT_NAME}
EOF
# 
# Create an ExternalSecret resource, which creates a Kubernetes Secret in the airflow namespace with the Airflow secrets stored in your key vault, using the kubectl apply command.
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: airflow-aks-azure-logs-secrets
  namespace: ${AKS_AIRFLOW_NAMESPACE}
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: azure-store
  target:
    name: ${AKS_AIRFLOW_LOGS_STORAGE_SECRET_NAME}
    creationPolicy: Owner
  data:
    # name of the SECRET in the Azure KV (no prefix is by default a SECRET)
    - secretKey: azurestorageaccountname
      remoteRef:
        key: AKS-AIRFLOW-LOGS-STORAGE-ACCOUNT-NAME
    - secretKey: azurestorageaccountkey
      remoteRef:
        key: AKS-AIRFLOW-LOGS-STORAGE-ACCOUNT-KEY
EOF
# 
# Create a federated credential using the az identity federated-credential create command.
az identity federated-credential create --name external-secret-operator --identity-name ${MY_IDENTITY_NAME} --resource-group ${MY_RESOURCE_GROUP_NAME} --issuer ${OIDC_URL} --subject system:serviceaccount:${AKS_AIRFLOW_NAMESPACE}:${SERVICE_ACCOUNT_NAME} --output table
#
# Give permission to the user-assigned identity to access the secret using the az keyvault set-policy command.
az keyvault set-policy --name $MY_KEYVAULT_NAME --object-id $MY_IDENTITY_NAME_PRINCIPAL_ID --secret-permissions get --output table
#
# Create a persistent volume for Apache Airflow logs
# Create a persistent volume using the kubectl apply command.
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-airflow-logs
  labels:
    type: local
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain # If set as "Delete" container would be removed after pvc deletion
  storageClassName: azureblob-fuse-premium
  mountOptions:
    - -o allow_other
    - --file-cache-timeout-in-seconds=120
  csi:
    driver: blob.csi.azure.com
    readOnly: false
    volumeHandle: airflow-logs-1
    volumeAttributes:
      resourceGroup: ${MY_RESOURCE_GROUP_NAME}
      storageAccount: ${AKS_AIRFLOW_LOGS_STORAGE_ACCOUNT_NAME}
      containerName: ${AKS_AIRFLOW_LOGS_STORAGE_CONTAINER_NAME}
    nodeStageSecretRef:
      name: ${AKS_AIRFLOW_LOGS_STORAGE_SECRET_NAME}
      namespace: ${AKS_AIRFLOW_NAMESPACE}
EOF
#
# Create a persistent volume claim for Apache Airflow logs
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-airflow-logs
  namespace: ${AKS_AIRFLOW_NAMESPACE}
spec:
  storageClassName: azureblob-fuse-premium
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 5Gi
  volumeName: pv-airflow-logs
EOF
#
# Deploy Apache Airflow using Helm
# Configure an airflow_values.yaml file to change the default deployment configurations for the chart and update the container registry for the images.
cat <<EOF > airflow_values.yaml
images:
  airflow:
    repository: $MY_ACR_REGISTRY.azurecr.io/airflow
    tag: 2.9.3
    # Specifying digest takes precedence over tag.
    digest: ~
    pullPolicy: IfNotPresent
  # To avoid images with user code, you can turn this to 'true' and
  # all the 'run-airflow-migrations' and 'wait-for-airflow-migrations' containers/jobs
  # will use the images from 'defaultAirflowRepository:defaultAirflowTag' values
  # to run and wait for DB migrations .
  useDefaultImageForMigration: false
  # timeout (in seconds) for airflow-migrations to complete
  migrationsWaitTimeout: 60
  pod_template:
    # Note that `images.pod_template.repository` and `images.pod_template.tag` parameters
    # can be overridden in `config.kubernetes` section. So for these parameters to have effect
    # `config.kubernetes.worker_container_repository` and `config.kubernetes.worker_container_tag`
    # must be not set .
    repository: $MY_ACR_REGISTRY.azurecr.io/airflow
    tag: 2.9.3
    pullPolicy: IfNotPresent
  flower:
    repository: $MY_ACR_REGISTRY.azurecr.io/airflow
    tag: 2.9.3
    pullPolicy: IfNotPresent
  statsd:
    repository: $MY_ACR_REGISTRY.azurecr.io/statsd-exporter
    tag: v0.26.1
    pullPolicy: IfNotPresent
  pgbouncer:
    repository: $MY_ACR_REGISTRY.azurecr.io/airflow
    tag: airflow-pgbouncer-2024.01.19-1.21.0
    pullPolicy: IfNotPresent
  pgbouncerExporter:
    repository: $MY_ACR_REGISTRY.azurecr.io/airflow
    tag: airflow-pgbouncer-exporter-2024.06.18-0.17.0
    pullPolicy: IfNotPresent
  gitSync:
    repository: $MY_ACR_REGISTRY.azurecr.io/git-sync
    tag: v4.1.0
    pullPolicy: IfNotPresent
    
# Airflow executor
executor: "KubernetesExecutor"

# Environment variables for all airflow containers
env:
  - name: ENVIRONMENT
    value: dev

extraEnv: |
  - name: AIRFLOW__CORE__DEFAULT_TIMEZONE
    value: 'America/New_York'

# Configuration for postgresql subchart
# Not recommended for production! Instead, spin up your own Postgresql server and use the `data` attribute in this
# yaml file.
postgresql:
  enabled: true

# Enable pgbouncer. See https://airflow.apache.org/docs/helm-chart/stable/production-guide.html#pgbouncer
pgbouncer:
  enabled: true

dags:
  gitSync:
    enabled: true
    repo: https://github.com/donhighmsft/airflowexamples.git
    branch: main
    rev: HEAD
    depth: 1
    maxFailures: 0
    subPath: "dags"
    # sshKeySecret: airflow-git-ssh-secret
    # knownHosts: |
    #   github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=

logs:
  persistence:
    enabled: true
    existingClaim: pvc-airflow-logs
    storageClassName: azureblob-fuse-premium

# We disable the log groomer sidecar because we use Azure Blob Storage for logs, with lifecyle policy set.
triggerer:
  logGroomerSidecar:
    enabled: false

scheduler:
  logGroomerSidecar:
    enabled: false

workers:
  logGroomerSidecar:
    enabled: false

EOF
# Add the Apache Airflow Helm repository and update the repository using the helm repo add and helm repo update commands.
helm repo add apache-airflow https://airflow.apache.org
helm repo update
#
# Search the Helm repository for the Apache Airflow chart using the helm search repo command.
helm search repo airflow
#
# Install the Apache Airflow chart using the helm install command.
helm install airflow apache-airflow/airflow --namespace airflow --create-namespace -f airflow_values.yaml --debug
#
# Verify the installation using the kubectl get pods command.
kubectl get pods -n airflow
#
# Access Airflow UI
# Securely access the Airflow UI through port-forwarding using the kubectl port-forward command.
kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow
# Open your browser and navigate to localhost:8080 to access the Airflow UI.
# Use the default webserver URL and login credentials provided during the Airflow Helm chart installation to log in.
# Explore and manage your workflows securely through the Airflow UI.
#
# Integrate Git with Airflow
# Integrating Git with Apache Airflow enables seamless version control and streamlined management of your workflow definitions, ensuring that all DAGs are both organized and easily auditable.
# Set up a Git repository for DAGs. Create a dedicated Git repository to house all your Airflow DAG definitions.
# This repository serves as the central source of truth for your workflows, allowing you to manage, track, and collaborate on DAGs effectively.
# Configure Airflow to sync DAGs from Git.
# Update Airflow’s configuration to automatically pull DAGs from your Git repository by setting the Git repository URL and any required authentication credentials directly in Airflow’s configuration files or through Helm chart values.
# This setup enables automated synchronization of DAGs, ensuring that Airflow is always up to date with the latest version of your workflows.
# This integration enhances the development and deployment workflow by introducing full version control, enabling rollbacks, and supporting team collaboration in a production-grade setup.
#
# Make your Airflow on Kubernetes production-grade
# The following best practices can help you make your Apache Airflow on Kubernetes deployment production-grade:
# - Ensure you have a robust setup focused on scalability, security, and reliability.
# - Use dedicated, autoscaling nodes, and select a resilient executor like KubernetesExecutor, CeleryExecutor, or CeleryKubernetesExecutor.
# - Use a managed, high-availability database back end like MySQL or PostgreSQL.
# - Establish comprehensive monitoring and centralized logging to maintain performance insights.
# - Secure your environment with network policies, SSL, and Role-Based Access Control (RBAC), and configure Airflow components (Scheduler, Web Server, Workers) for high availability.
# - Implement CI/CD pipelines for smooth DAG deployment, and set up regular backups for disaster recovery.
#
# All done!
