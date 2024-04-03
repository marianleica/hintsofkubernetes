<p>Log locations to check:</p>

    /var/log/pods
    /var/log/containers
    crictl ps + crictl logs
    docker ps + docker logs (in case when Docker is used)
    kubelet logs: /var/log/syslog or journalctl

<p>Steps:</p>

    # always make a backup !
    cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/kube-apiserver.yaml.ori
    
    # make the change
    vim /etc/kubernetes/manifests/kube-apiserver.yaml
    
    # wait till container restarts
    watch crictl ps
    
    # check for apiserver pod
    k -n kube-system get pod

<p>Recover from yaml backup:</p>

    # smart people use a backup
    cp ~/kube-apiserver.yaml.ori /etc/kubernetes/manifests/kube-apiserver.yaml


