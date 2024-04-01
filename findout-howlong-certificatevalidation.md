# You can do this with openssl or kubeadm

<p> You can use kubeadm to renew the certificates </p>

## From openssl
<p>ssh into the control plane node</p>

`find /etc/kubernetes/pki | grep apiserver`

<p>output example:</p>

  /etc/kubernetes/pki/apiserver.crt
  /etc/kubernetes/pki/apiserver-etcd-client.crt
  /etc/kubernetes/pki/apiserver-etcd-client.key
  /etc/kubernetes/pki/apiserver-kubelet-client.crt
  /etc/kubernetes/pki/apiserver.key
  /etc/kubernetes/pki/apiserver-kubelet-client.key

<p>next use oppenssl to find out the expiration date from the *.crt file</p>

`openssl x509 -noout -text -in /etc/kubernetes/pki/apiserver.crt | grep Validitity -A2`

<p>output example:</p>

        Validity
            Not Before: Dec 20 18:05:20 2022 GMT
            Not After : Dec 20 18:05:20 2023 GMT

## From kubeadm

`kubadm certs check-expiration | grep apiserver`

<p>And to renew all certificates in the same location:</p>

`kubeadm certs renew apiserver`
