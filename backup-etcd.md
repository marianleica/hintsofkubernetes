<p> To interact with the etcd datastore in Kubernetes, we use a command-line tool called etcdctl</p>

<p>etcd has its own server certificate which requires a valid client certificate and key located in /etc/kubernetes/pki/etcd </p>

<p> Just like the Kubernetes API, the etcd datastore requires authenticaiton which can be passed as a parameter with the etcdctl tool. etcdctl also requires environment variable ETCDCTL_API which is set to the version of etcdctl</p>

<p>Set this environment variable before you backup the etcd datastore with the command</p>

    export ETCDCTL_API=3

<p>Backup the etcd datastore with the etcdctl snapshot save command and pass in the certificate authority, the client or server certificate, and the private key in order to authenticate with etcd. We'll name the snapshot file "snapshot".</p>

    etcdctl snapshot save snapshot --cacert /etc/kubernetes/pki/etcd/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key

<p>Listing the contents of your current directory will now look like this:</p>

    $ ls
    filesystem snapshot

<p> Check the status of your snapshot and write the output to a table using this command</p>

    etcdctl snapshot status snapshot --write-out=table
