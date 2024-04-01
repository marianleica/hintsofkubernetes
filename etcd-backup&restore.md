# Backing up etcd and restoring it


### Back up etcd

<p>ssh into the control plane</p>

`ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db`

<p>it should fail because one needs to authenticate:</p>

`vim /etc/kubernetes/manifests/etcd.yaml`
<!> don't change it

/etc/kubernetes/manifests/etcd.yaml

    apiVersion: v1
    kind: Pod
    metadata:
      creationTimestamp: null
      labels:
        component: etcd
        tier: control-plane
      name: etcd
      namespace: kube-system
    spec:
      containers:
      - command:
        - etcd
        - --advertise-client-urls=https://192.168.100.31:2379
        - --cert-file=/etc/kubernetes/pki/etcd/server.crt                           # use
        - --client-cert-auth=true
        - --data-dir=/var/lib/etcd
        - --initial-advertise-peer-urls=https://192.168.100.31:2380
        - --initial-cluster=cluster3-controlplane1=https://192.168.100.31:2380
        - --key-file=/etc/kubernetes/pki/etcd/server.key                            # use
        - --listen-client-urls=https://127.0.0.1:2379,https://192.168.100.31:2379   # use
        - --listen-metrics-urls=http://127.0.0.1:2381
        - --listen-peer-urls=https://192.168.100.31:2380
        - --name=cluster3-controlplane1
        - --peer-cert-file=/etc/kubernetes/pki/etcd/peer.crt
        - --peer-client-cert-auth=true
        - --peer-key-file=/etc/kubernetes/pki/etcd/peer.key
        - --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt                    # use
        - --snapshot-count=10000
        - --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.crt
        image: k8s.gcr.io/etcd:3.3.15-0
        imagePullPolicy: IfNotPresent
        livenessProbe:
          failureThreshold: 8
          httpGet:
            host: 127.0.0.1
            path: /health
            port: 2381
            scheme: HTTP
          initialDelaySeconds: 15
          timeoutSeconds: 15
        name: etcd
        resources: {}
        volumeMounts:
        - mountPath: /var/lib/etcd
          name: etcd-data
        - mountPath: /etc/kubernetes/pki/etcd
          name: etcd-certs
      hostNetwork: true
      priorityClassName: system-cluster-critical
      volumes:
      - hostPath:
          path: /etc/kubernetes/pki/etcd
          type: DirectoryOrCreate
        name: etcd-certs
      - hostPath:
          path: /var/lib/etcd                                                     # important
          type: DirectoryOrCreate
        name: etcd-data
    status: {}

<p>The api-server is also connecting to etcd, so check how its manifest is configured:</p>

`cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep etcd`

<p>example output:</p>

    - --etcd-cafile=/etc/kubernetes/pki/etcd/ca.crt
    - --etcd-certfile=/etc/kubernetes/pki/apiserver-etcd-client.crt
    - --etcd-keyfile=/etc/kubernetes/pki/apiserver-etcd-client.key
    - --etcd-servers=https://127.0.0.1:2379

<p>use that information and pass it to etcdctl:</p>

`ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--cert /etc/kubernetes/pki/etcd/server.crt \
--key /etc/kubernetes/pki/etcd/server.key`

(!) don't use `snapshot status`, it can alter the snapshot file and render it invalid

### Restore etcd
