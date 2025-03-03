# Setting variables
RG="aks-unit-testing"
AKS="aks-nginx-ingress"
az group create -n $RG -l uksouth

# unmanaged ingress controller as per
# Ref:
# https://learn.microsoft.com/en-us/troubleshoot/azure/azure-kubernetes/load-bal-ingress-c/create-unmanaged-ingress-controller?tabs=azure-cli#clean-up-resources

# Cluster create
az aks create -n $AKS -g $RG --generate-ssh-keys --node-count 2 -o table
az aks get-credentials -n $AKS -g $RG --admin

# The ingress part:

NAMESPACE=ingress-basic

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

 helm install ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace \
  --namespace $NAMESPACE \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
  --set controller.service.externalTrafficPolicy=Local

# In this tutorial, service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path is being set to /healthz.
# This means if the response code of the requests to /healthz is not 200, the entire ingress controller will be down.
# You can modify the value to other URI in your own scenario.
# You cannot delete this part or unset the value, or the ingress controller will still be down.
# The package ingress-nginx used in this tutorial, which is provided by Kubernetes official,
# will always return 200 response code if requesting /healthz,
# as it is designed as default backend for users to have a quick start, unless it is being overwritten by ingress rules.

# ACR part

az acr create -n aksunmanagedingress -g $RG --sku Standard
az aks update -n $AKS -g $RG --attach-acr aksunmanagedingress

REGISTRY_NAME="aksunmanagedingress"
SOURCE_REGISTRY=registry.k8s.io
CONTROLLER_IMAGE=ingress-nginx/controller
CONTROLLER_TAG=v1.8.1
PATCH_IMAGE=ingress-nginx/kube-webhook-certgen
PATCH_TAG=v20230407
DEFAULTBACKEND_IMAGE=defaultbackend-amd64
DEFAULTBACKEND_TAG=1.5

az acr import --name $REGISTRY_NAME --source $SOURCE_REGISTRY/$CONTROLLER_IMAGE:$CONTROLLER_TAG --image $CONTROLLER_IMAGE:$CONTROLLER_TAG
az acr import --name $REGISTRY_NAME --source $SOURCE_REGISTRY/$PATCH_IMAGE:$PATCH_TAG --image $PATCH_IMAGE:$PATCH_TAG
az acr import --name $REGISTRY_NAME --source $SOURCE_REGISTRY/$DEFAULTBACKEND_IMAGE:$DEFAULTBACKEND_TAG --image $DEFAULTBACKEND_IMAGE:$DEFAULTBACKEND_TAG

# Add the ingress-nginx repository
#helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
#helm repo update

# Set variable for ACR location to use for pulling images
ACR_LOGIN_SERVER="aksunmanagedingress.azurecr.io"

# Use Helm to deploy an NGINX ingress controller
``
#helm install app-nginx ingress-nginx/ingress-nginx \
#    --version 4.7.1 \
#    --namespace ingress-basic \
#    --create-namespace \
#    --set controller.replicaCount=2 \
#    --set controller.nodeSelector."kubernetes\.io/os"=linux \
#    --set controller.image.registry=$ACR_LOGIN_SERVER \
#    --set controller.image.image=$CONTROLLER_IMAGE \
#    --set controller.image.tag=$CONTROLLER_TAG \
#    --set controller.image.digest="" \
#    --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
#    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
#    --set controller.service.externalTrafficPolicy=Local \
#    --set controller.admissionWebhooks.patch.image.registry=$ACR_LOGIN_SERVER \
#    --set controller.admissionWebhooks.patch.image.image=$PATCH_IMAGE \
#    --set controller.admissionWebhooks.patch.image.tag=$PATCH_TAG \
#    --set controller.admissionWebhooks.patch.image.digest="" \
#    --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
#    --set defaultBackend.image.registry=$ACR_LOGIN_SERVER \
#    --set defaultBackend.image.image=$DEFAULTBACKEND_IMAGE \
#    --set defaultBackend.image.tag=$DEFAULTBACKEND_TAG \
#    --set defaultBackend.image.digest=""
#

# Create with internal LB
# Add the ingress-nginx repository
#helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
#helm repo update

# Set variable for ACR location to use for pulling images
ACR_LOGIN_SERVER="aksunmanagedingress.azurecr.io"

# Use Helm to deploy an NGINX ingress controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
    --version 4.7.1 \
    --namespace ingress-basic \
    --create-namespace \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.image.registry=$ACR_LOGIN_SERVER \
    --set controller.image.image=$CONTROLLER_IMAGE \
    --set controller.image.tag=$CONTROLLER_TAG \
    --set controller.image.digest="" \
    --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.service.loadBalancerIP=10.224.0.42 \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal"=true \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
    --set controller.admissionWebhooks.patch.image.registry=$ACR_LOGIN_SERVER \
    --set controller.admissionWebhooks.patch.image.image=$PATCH_IMAGE \
    --set controller.admissionWebhooks.patch.image.tag=$PATCH_TAG \
    --set controller.admissionWebhooks.patch.image.digest="" \
    --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
    --set defaultBackend.image.registry=$ACR_LOGIN_SERVER \
    --set defaultBackend.image.image=$DEFAULTBACKEND_IMAGE \
    --set defaultBackend.image.tag=$DEFAULTBACKEND_TAG \
    --set defaultBackend.image.digest=""

# Check the LB

kubectl get services --namespace ingress-basic -o wide -w ingress-nginx-controller

# NAME                       TYPE           CLUSTER-IP    EXTERNAL-IP     PORT(S)                      AGE   SELECTOR
# ingress-nginx-controller   LoadBalancer   10.0.65.205   EXTERNAL-IP     80:30957/TCP,443:32414/TCP   1m   app.kubernetes.io/component=controller,app.kubernetes.io/instance=ingress-nginx,app.kubernetes.io/name=ingress-nginx

# Running demo app

apiVersion: apps/v1
kind: Deployment
metadata:
  name: aks-helloworld-one  
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aks-helloworld-one
  template:
    metadata:
      labels:
        app: aks-helloworld-one
    spec:
      containers:
      - name: aks-helloworld-one
        image: mcr.microsoft.com/azuredocs/aks-helloworld:v1
        ports:
        - containerPort: 80
        env:
        - name: TITLE
          value: "Welcome to Azure Kubernetes Service (AKS)"
---
apiVersion: v1
kind: Service
metadata:
  name: aks-helloworld-one  
spec:
  type: ClusterIP
  ports:
  - port: 80
  selector:
    app: aks-helloworld-one

apiVersion: apps/v1
kind: Deployment
metadata:
  name: aks-helloworld-two  
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aks-helloworld-two
  template:
    metadata:
      labels:
        app: aks-helloworld-two
    spec:
      containers:
      - name: aks-helloworld-two
        image: mcr.microsoft.com/azuredocs/aks-helloworld:v1
        ports:
        - containerPort: 80
        env:
        - name: TITLE
          value: "AKS Ingress Demo"
---
apiVersion: v1
kind: Service
metadata:
  name: aks-helloworld-two  
spec:
  type: ClusterIP
  ports:
  - port: 80
  selector:
    app: aks-helloworld-two

kubectl apply -f aks-helloworld-one.yaml --namespace ingress-basic
kubectl apply -f aks-helloworld-two.yaml --namespace ingress-basic

# Create ingress route

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /hello-world-one(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: aks-helloworld-one
            port:
              number: 80
      - path: /hello-world-two(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: aks-helloworld-two
            port:
              number: 80
      - path: /(.*)
        pathType: Prefix
        backend:
          service:
            name: aks-helloworld-one
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-ingress-static
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/rewrite-target: /static/$2
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /static(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: aks-helloworld-one
            port: 
              number: 80

kubectl apply -f hello-world-ingress.yaml --namespace ingress-basic
# ASK: how to properly clean without impacting another running ingress controller like