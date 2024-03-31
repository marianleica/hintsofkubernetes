# Find where the kube-scheduler is running in the control plane nodes
kubectl -n kube-system get pod | grep schedule

# ssh into the control plane node and change in place the scheduler yaml
cd /etc/kubernetes/manifests/
mv kube-scheduler.yaml ..

# When checking again, it should be stopped and the pod won't show anymore
kubectl -n kube-system get pod | grep schedule

# Creating a new pod will show with no node assigned
kubectl run pod1 --image=httpd:2.4-alpine

# But you can manually schedule it via its manifest

k get pod pod1 -o yaml > new.yaml

# new.yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: "2020-09-04T15:51:02Z"
  labels:
    run: pod1
  managedFields:
...
    manager: kubectl-run
    operation: Update
    time: "2020-09-04T15:51:02Z"
  name: pod1
  namespace: default
  resourceVersion: "3515"
  selfLink: /api/v1/namespaces/default/pods/pod1
  uid: 8e9d2532-4779-4e63-b5af-feb82c74a935
spec:
  nodeName: cluster2-controlplane1        # add the controlplane node name
  containers:
  - image: httpd:2.4-alpine
    imagePullPolicy: IfNotPresent
    name: pod1
    resources: {}
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: default-token-nxnc7
      readOnly: true
  dnsPolicy: ClusterFirst
...

# The only thing a scheduler does, is that it sets the nodeName for a Pod declaration
# How it finds the correct node to schedule on, that's a very much complicated matter and takes many variables into account

# As we cannot kubectl apply or kubectl edit , in this case we need to delete and create or replace:
kubectl -f new.yaml replace --force

kubectl get pod pod1 -o wide

NAME              READY   STATUS    ...   NODE            
manual-schedule   1/1     Running   ...   cluster2-controlplane1

# It looks like our Pod is running on the controlplane node, although no tolerations were specified
# Only the scheduler takes tains/tolerations/affinity into account when finding the correct node name
# That's why it's still possible to assign Pods manually directly to a controlplane node and skip the scheduler

# To start the kube-scheduler again, ssh into the controlplane node

cd /etc/kubernetes/manifests/
mv ../kube-scheduler.yaml .

# Confirm it's running
kubectl -n kube-system get pod | grep schedule

# Schedule a second pod
kubectl run pod2 --image=httpd:2.4-alpine

# Should be back to normal
