# To find out the number of resources are in a namespace:


`kubectl get <api-resource> -n <namespace> --no-headers | wc -l`

<p></p>
<p>Example:</p>

`k -n project-c14 get role --no-headers | wc -l`
<p></p>
Output: 300
