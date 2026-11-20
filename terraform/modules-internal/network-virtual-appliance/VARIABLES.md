# network-virtual-appliance variables

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| ingress\_target\_ip | Private IP the ingress ports are forwarded to: the gateway's internal load balancer. | `string` | n/a | yes |
| name | Prefix of every resource's name. | `string` | n/a | yes |
| region | Region of the appliance. Must match the VNet's. | `string` | n/a | yes |
| resource\_group\_name | Resource group the instances' scale set, its load balancers, public IP and NSG are created in. | `string` | n/a | yes |
| subnet\_cidr | Range of the appliance's subnet. The internal load balancer takes its fifth address, the next hop of the nodes' egress. A /28 at least. | `string` | n/a | yes |
| vnet\_id | VNet the appliance's subnet is created in. | `string` | n/a | yes |
| availability\_zones | Zones the instances and the load balancers' frontends are spread across. | `list(string)` | <pre>[<br/>  "1",<br/>  "2",<br/>  "3"<br/>]</pre> | no |
| ingress\_ports | TCP ports of the public IP forwarded to ingress\_target\_ip. | `list(number)` | <pre>[<br/>  443<br/>]</pre> | no |
| instance\_count | Instances sharing the traffic. Each keeps its own connections, which a crash drops. | `number` | `2` | no |
| tags | Applied to every taggable resource this module creates. | `map(string)` | `{}` | no |
| vm\_size | Size of each instance. A burstable B-series size forwards at full speed only while it has CPU credits. | `string` | `"Standard_B2pts_v2"` | no |
<!-- END_TF_DOCS -->
