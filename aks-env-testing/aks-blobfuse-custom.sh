az group create -n azrez -l uksouth

az aks create --enable-blob-driver --name aksblob --resource-group azrez --generate-ssh-keys --node-count 1

az aks get-credentials --name aksblob --resource-group azrez --admin

kubectl create ns davek-test

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
      - name: aci-helloworld
        image: mcr.microsoft.com/azuredocs/aci-helloworld
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

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: davek-pvc-01
  namespace: davek-test
spec:
  accessModes:
    - ReadWriteMany
#  storageClassName: private-azureblob-csi
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
      - name: aci-helloworld
        image: mcr.microsoft.com/azuredocs/aci-helloworld
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
