az group create -n azrez -l uksouth

az aks create --enable-blob-driver --name aksdsk --resource-group azrez --generate-ssh-keys --node-count 1 --node-vm-size Standard_D16ds_v5
# az aks create --enable-blob-driver --name aksdsk --resource-group azrez --generate-ssh-keys --node-count 1 --node-vm-size Standard_D16ds_v5 --node-osdisk-size 650

az aks get-credentials --name aksdsk --resource-group azrez --admin --overwrite-existing

az aks nodepool add -g azrez -n bigdisknp2 --cluster-name aksdsk --node-osdisk-type Ephemeral --node-vm-size Standard_D16ds_v5 --node-osdisk-size 650 --node-count 1

kubectl get nodes
kubectl cordon node1 node2 node3
kubectl drain node1 node2 node3

az aks nodepool delete -g azrez --cluster-name azdsk -n nodepool1