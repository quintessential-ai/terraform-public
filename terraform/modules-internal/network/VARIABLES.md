# network variables

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| network\_appliance\_ip | Private IP of the network appliance that takes the nodes' egress. Given back as the network\_appliance\_ip output once the appliance is reachable from this VNet. | `string` | n/a | yes |
| region | Region of the VNet. | `string` | n/a | yes |
| resource\_group\_name | Resource group the VNet is created in. existing\_vnet\_name is looked up in it too, unless existing\_vnet\_resource\_group\_name is set. | `string` | n/a | yes |
| vnet\_name | Name of the VNet to create. Ignored when existing\_vnet\_name is set. | `string` | n/a | yes |
| existing\_vnet\_name | If set, this VNet is used instead of creating one. | `string` | `null` | no |
| existing\_vnet\_resource\_group\_name | Defaults to this module's resource group. | `string` | `null` | no |
| network\_appliance\_vnet\_id | VNet holding network\_appliance\_ip, when it is not this one. Peered both ways with this VNet; its side is created with the azurerm.network\_appliance provider. | `string` | `null` | no |
| peerings | VNets to peer this one with, keyed by a name that is stable at plan time. | <pre>map(object({<br/>    remote_virtual_network_id    = string<br/>    allow_virtual_network_access = optional(bool, true)<br/>    allow_forwarded_traffic      = optional(bool, false)<br/>    allow_gateway_transit        = optional(bool, false)<br/>    use_remote_gateways          = optional(bool, false)<br/>    # A peering only carries traffic once both directions exist. The reverse side is created with<br/>    # this module's provider, so it only works when the remote VNet is in the same subscription;<br/>    # turn this off for a cross-subscription peer and create that side where the remote VNet lives.<br/>    create_reverse_peering = optional(bool, true)<br/>  }))</pre> | `{}` | no |
| tags | Applied to every taggable resource this module creates. | `map(string)` | `{}` | no |
| vnet\_cidr | Address space of the VNet this module creates. Ignored when existing\_vnet\_name is set. | `string` | `"10.224.0.0/16"` | no |
<!-- END_TF_DOCS -->
