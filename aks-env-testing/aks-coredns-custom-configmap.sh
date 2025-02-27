az group create -n removeonsight -l uksouth

az aks create -n akscrdns -g removeonsight --node-count 1 --generate-ssh-keys

az aks get-credentials -n akscrdns -g removeonsight --admin

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
    mqsxzme.mf.corpintra.net:4509 {
        hosts {
            53.113.100.193 mqsxzme.mf.corpintra.net
            fallthrough
        }
    }
EOF