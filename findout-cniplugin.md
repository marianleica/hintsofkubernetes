# To find out the CNI plugin in an upstream Kubernetes cluster:

<p>Connect via ssh to a control plane node</p>
<p>look for:</p>

`find /etc/cni/net.d/`

<p>example output:</p>
/etc/cni/net.d/
/etc/cni/net.d/10-weave.conflist

<p>then you can verify:</p>

`cat /etc/cni/net.d/10-weave.conflist`

<p>example output:</p>
{
    "cniVersion": "0.3.0",
    "name": "weave",
