# azure-firewall variables

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| egress\_source\_cidrs | Ranges allowed to reach the internet through the firewall, on any protocol and port. | `list(string)` | n/a | yes |
| ingress\_target\_ip | Private IP the ingress ports are forwarded to: the gateway's internal load balancer. | `string` | n/a | yes |
| name | Prefix of every resource's name. | `string` | n/a | yes |
| region | Region of the firewall. Must match the VNet's. | `string` | n/a | yes |
| resource\_group\_name | Resource group the firewall, its policy and its two public IPs are created in. | `string` | n/a | yes |
| subnet\_cidr | Range split into the firewall's two /26 subnets: AzureFirewallSubnet and, for the Basic tier, AzureFirewallManagementSubnet. A /25 at least. | `string` | n/a | yes |
| vnet\_id | VNet the firewall's subnets are created in. | `string` | n/a | yes |
| availability\_zones | Zones the firewall and its public IPs are spread across. | `list(string)` | <pre>[<br/>  "1",<br/>  "2",<br/>  "3"<br/>]</pre> | no |
| ingress\_ports | TCP ports of the public IP forwarded to ingress\_target\_ip. | `list(number)` | <pre>[<br/>  443<br/>]</pre> | no |
| sku\_tier | Basic forwards up to 250 Mbps. Standard scales up to 30 Gbps. Moving to or from Basic replaces the firewall. | `string` | `"Basic"` | no |
| tags | Applied to every taggable resource this module creates. | `map(string)` | `{}` | no |
<!-- END_TF_DOCS -->
