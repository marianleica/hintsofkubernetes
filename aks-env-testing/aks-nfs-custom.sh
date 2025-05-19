az group create -n azrez -l uksouth

az aks create --enable-blob-driver --name aksnfs --resource-group azrez --generate-ssh-keys --node-count 2

az aks get-credentials --name aksnfs --resource-group azrez --admin --overwrite-existing

kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-nfs
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
  protocol: nfs
mountOptions:
  - nconnect=4
  - noresvport
  - actimeo=30
EOF

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: statefulset-azurefile
  labels:
    app: nginx
spec:
  podManagementPolicy: Parallel  # default is OrderedReady
  serviceName: statefulset-azurefile
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
        - name: statefulset-azurefile
          image: mcr.microsoft.com/oss/nginx/nginx:1.19.5
          command:
            - "/bin/bash"
            - "-c"
            - set -euo pipefail; while true; do echo $(date) >> /mnt/azurefile/outfile; sleep 1; done
          volumeMounts:
            - name: persistent-storage
              mountPath: /mnt/azurefile
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: nginx
  volumeClaimTemplates:
    - metadata:
        name: persistent-storage
      spec:
        storageClassName: azurefile-csi-nfs
        accessModes: ["ReadWriteMany"]
        resources:
          requests:
            storage: 100Gi
EOF

# Next testing the NFS mount while keys access are disabled in the storage account

kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-nfs-sc
provisioner: file.csi.azure.com
allowVolumeExpansion: true
parameters:
  protocol: nfs
  storageAccount: "f8a30884634fe43988e9cbd"
  resourceGroup: "MC_azrez_aksnfs_uksouth"
  networkEndpointType: privateEndpoint
  storeAccountKey: "false"
  allowBlobPublicAccess: "true"
mountOptions:
  - nconnect=4
  - noresvport
  - actimeo=30
EOF

kubectl delete sc azurefile-csi-nfs
kubectl delete sts statefulset-azurefile

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: statefulset-azurefile
  labels:
    app: nginx
spec:
  podManagementPolicy: Parallel  # default is OrderedReady
  serviceName: statefulset-azurefile
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
        - name: statefulset-azurefile
          image: mcr.microsoft.com/oss/nginx/nginx:1.19.5
          command:
            - "/bin/bash"
            - "-c"
            - set -euo pipefail; while true; do echo $(date) >> /mnt/azurefile/outfile; sleep 1; done
          volumeMounts:
            - name: persistent-storage
              mountPath: /mnt/azurefile
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: nginx
  volumeClaimTemplates:
    - metadata:
        name: persistent-storage
      spec:
        storageClassName: azurefile-csi-nfs-sc
        accessModes: ["ReadWriteMany"]
        resources:
          requests:
            storage: 100Gi
EOF