az group create -n azrez -l uksouth

az aks create --enable-blob-driver --name aksblob --resource-group azrez --generate-ssh-keys --node-count 1

az aks get-credentials --name aksblob --resource-group azrez --admin

#################################
# BLOBFUSE DOCUMENTATION TESTING #
#################################

kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azureblob-fuse-premium-cs
provisioner: blob.csi.azure.com
parameters:
  skuName: Standard_GRS  # available values: Standard_LRS, Premium_LRS, Standard_GRS, Standard_RAGRS
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
mountOptions:
  - -o allow_other
  - --file-cache-timeout-in-seconds=120
  - --use-attr-cache=true
  - --cancel-list-on-mount-seconds=10  # prevent billing charges on mounting
  - -o attr_timeout=120
  - -o entry_timeout=120
  - -o negative_timeout=120
  - --log-level=LOG_WARNING  # LOG_WARNING, LOG_INFO, LOG_DEBUG
  - --cache-size-mb=1000  # Default will be 80% of available memory, eviction will happen beyond that.
EOF

kubectl create secret generic azure-secret --from-literal azurestorageaccountname=NAME --from-literal azurestorageaccountkey="KEY" --type=Opaque

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    pv.kubernetes.io/provisioned-by: blob.csi.azure.com
  name: pv-blob
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain  # If set as "Delete" container would be removed after pvc deletion
  storageClassName: azureblob-fuse-premium-cs
  mountOptions:
    - -o allow_other
    - --file-cache-timeout-in-seconds=120
  csi:
    driver: blob.csi.azure.com
    # volumeid has to be unique for every identical storage blob container in the cluster
    # character `#`and `/` are reserved for internal use and cannot be used in volumehandle
    volumeHandle: account-name_container-name
    volumeAttributes:
      containerName: containerName
    nodeStageSecretRef:
      name: azure-secret
      namespace: default
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-blob
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  volumeName: pv-blob
  storageClassName: azureblob-fuse-premium-cs
EOF

kubectl apply -f - <<EOF
kind: Pod
apiVersion: v1
metadata:
  name: nginx-blob
spec:
  nodeSelector:
    "kubernetes.io/os": linux
  containers:
    - image: mcr.microsoft.com/oss/nginx/nginx:1.17.3-alpine
      name: nginx-blob
      volumeMounts:
        - name: blob01
          mountPath: "/mnt/blob"
          readOnly: false
  volumes:
    - name: blob01
      persistentVolumeClaim:
        claimName: pvc-blob
EOF

#################################
# DAVE TESTING #
#################################

kubectl create ns davek-test

kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
 name: msft-azureblob-csi # do we want to name this something like GM-azureblob-csi? 
provisioner: blob.csi.azure.com
allowVolumeExpansion: true
parameters:
# storageAccount: "a228101d5staks"
  resourceGroup: "a228101-d1-musea2-rg-d5"
  networkEndpointType: privateEndpoint
  # server: "a228101d5staks.privatelink.blob.core.windows.net"
  protocol: fuse
  storeAccountKey: "false"
  allowBlobPublicAccess: "true"
reclaimPolicy: Delete # for testing, should be Retain 
volumeBindingMode: Immediate
mountOptions:           # these are optional/customizable settings
 - "-o allow_other"
 - "-o attr_timeout=240"
 - "-o entry_timeout=240" 
 - "-o negative_timeout=120"
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: davek-pvc-01
  namespace: davek-test
spec:
  accessModes:
    - ReadWriteMany
  # storageClassName: private-azureblob-csi
  storageClassName: msft-azureblob-csi
  resources:
    requests:
      storage: 5Gi
EOF

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: davek-app
  namespace: davek-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: davek-app-test
  template:
    metadata:
      labels:
        app: davek-app-test
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
        volumeMounts:
        - name: private-blobcsi-vol
          mountPath: "/mnt/privateblobcsi"
      volumes:
      - name: private-blobcsi-vol
        persistentVolumeClaim:
          claimName: davek-pvc-01
EOF