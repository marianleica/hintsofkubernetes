# To find out the service cidr in a kubeadm cluster:
<p> ssh into a control plane node</p>
<p>check the apiserver.yaml file filtered on 'range'</p>
<p>command:</p>

`cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep range`

<p></p>
<p>output:</p>

`--service-cluster-ip-range=10.96.0.0/12`
