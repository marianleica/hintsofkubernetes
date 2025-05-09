az group create -n azrez -l uksouth

az aks create --enable-blob-driver --name aksblob --resource-group azrez --generate-ssh-keys --node-count 2

az aks get-credentials --name aksblob --resource-group azrez --admin --overwrite-existing

#################################
# BLOBFUSE DOCUMENTATION TESTING #
#################################

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: statefulset-blob
  labels:
    app: nginx
spec:
  serviceName: statefulset-blob
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
        - name: statefulset-blob
          image: nginx
          volumeMounts:
            - name: persistent-storage
              mountPath: /mnt/blob
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: nginx
  volumeClaimTemplates:
    - metadata:
        name: persistent-storage
      spec:
        storageClassName: azureblob-fuse-premium
        accessModes: ["ReadWriteMany"]
        resources:
          requests:
            storage: 100Gi
EOF

# so far it works with just this one
# NAME                 READY   STATUS    RESTARTS   AGE
# statefulset-blob-0   1/1     Running   0          24s
# 
# NAME                                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS             VOLUMEATTRIBUTESCLASS   AGE
# persistent-storage-statefulset-blob-0   Bound    pvc-14372d07-f5d1-4468-b5a0-f43ec20b98d1   100Gi      RWX            azureblob-fuse-premium   <unset>             

# trying with custom storage class now

kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azureblob-fuse-premium-cs
provisioner: blob.csi.azure.com
parameters:
  skuName: Standard_LRS  # available values: Standard_LRS, Premium_LRS, Standard_GRS, Standard_RAGRS
  protocol: fuse2
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

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: statefulset-blob
  labels:
    app: nginx
spec:
  serviceName: statefulset-blob
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
        - name: statefulset-blob
          image: nginx
          volumeMounts:
            - name: persistent-storage
              mountPath: /mnt/blob
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: nginx
  volumeClaimTemplates:
    - metadata:
        name: persistent-storage
      spec:
        storageClassName: azureblob-fuse-premium-cs
        accessModes: ["ReadWriteMany"]
        resources:
          requests:
            storage: 100Gi
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
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: blob-fuse
provisioner: blob.csi.azure.com
parameters:
  skuName: Premium_LRS  # available values: Standard_LRS, Premium_LRS, Standard_GRS, Standard_RAGRS, Standard_ZRS, Premium_ZRS
  protocol: fuse2
  networkEndpointType: privateEndpoint
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
    - image: nginx
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
# resourceGroup: "a228101-d1-musea2-rg-d5"
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

# default sc yaml
kubectl apply -f - <<EOF
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
    kubernetes.io/cluster-service: "true"
  name: azureblob-fuse-premium-davek
mountOptions:
- -o allow_other
- --file-cache-timeout-in-seconds=120
- --use-attr-cache=true
- --cancel-list-on-mount-seconds=10
- -o attr_timeout=120
- -o entry_timeout=120
- -o negative_timeout=120
- --log-level=LOG_WARNING
- --cache-size-mb=1000
parameters:
  skuName: Premium_LRS
provisioner: blob.csi.azure.com
reclaimPolicy: Delete
volumeBindingMode: Immediate
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
  # storageClassName: azureblob-fuse-premium
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

# solving error:
# Events:
#  Type     Reason            Age                  From               Message
#  ----     ------            ----                 ----               -------
#  Warning  FailedScheduling  24s (x2 over 2m34s)  default-scheduler  0/2 nodes are available: pod has unbound immediate PersistentVolumeClaims. preemption: 0/2 nodes are available: 2 Preemption is not helpful for scheduling.
#  Normal   Scheduled         21s                  default-scheduler  Successfully assigned davek-test/davek-app-5dc44fcbd-tv26g to aks-nodepool1-19147956-vmss000001
#  Warning  FailedMount       3s (x6 over 19s)     kubelet            MountVolume.MountDevice failed for volume "pvc-0b83d2a6-571c-45f1-b006-1419d1dd50b2" : rpc error: code = Internal desc = no key for storage account(fuseef40c02e018d481e86a) under resource group(MC_azrez_aksblob_uksouth), err Retriable: false, RetryAfter: 0s, HTTPStatusCode: 403, RawError: {"error":{"code":"AuthorizationFailed","message":"The client 'd8961e3b-00a9-46b3-be2e-72abf97863d7' with object id 'd8961e3b-00a9-46b3-be2e-72abf97863d7' does not have authorization to perform action 'Microsoft.Storage/storageAccounts/listKeys/action' over scope '/subscriptions/d3d07f62-04cb-4701-a543-9c40a9c5a6f4/resourceGroups/MC_azrez_aksblob_uksouth/providers/Microsoft.Storage/storageAccounts/fuseef40c02e018d481e86a' or the scope is invalid. If access was recently granted, please refresh your credentials."}}

az role assignment create --assignee /subscriptions/d3d07f62-04cb-4701-a543-9c40a9c5a6f4/resourcegroups/MC_azrez_aksblob_uksouth/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aksblob-agentpool --role "Storage Account Key Operator Service Role" --scope "/subscriptions/d3d07f62-04cb-4701-a543-9c40a9c5a6f4/resourceGroups/MC_azrez_aksblob_uksouth/providers/Microsoft.Storage/storageAccounts/fuseef40c02e018d481e86a"

# NAME                        READY   STATUS    RESTARTS   AGE
# davek-app-5dc44fcbd-tv26g   1/1     Running   0          21m

# provided contributor rights to aksblob-agentpool kube identity