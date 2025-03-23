az group create -n azrez -l uksouth

az aks create --enable-blob-driver --name aksblob --resource-group azrez --generate-ssh-keys --node-count 1

az aks get-credentials --name aksblob --resource-group azrez --admin

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: statefulset-blob-nfs
  labels:
    app: nginx
spec:
  serviceName: statefulset-blob-nfs
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
        - name: statefulset-blob-nfs
          image: nginx
          volumeMounts:
            - name: persistent-storage
              mountPath: /mnt/blip
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: nginx
  volumeClaimTemplates:
    - metadata:
        name: persistent-storage
      spec:
        storageClassName: azureblob-nfs-premium
        accessModes: ["ReadWriteMany"]
        resources:
          requests:
            storage: 10Gi
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azure-blob-storage
spec:
  accessModes:
  - ReadWriteMany
  storageClassName: azureblob-nfs-premium
  resources:
    requests:
      storage: 5Gi
EOF

kubectl apply -f - <<EOF
kind: Pod
apiVersion: v1
metadata:
  name: mypod
spec:
  containers:
  - name: mypod
    image: nginx
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 250m
        memory: 256Mi
    volumeMounts:
    - mountPath: "/mnt/blob"
      name: volume
      readOnly: false
  volumes:
    - name: volume
      persistentVolumeClaim:
        claimName: azure-blob-storage
EOF
