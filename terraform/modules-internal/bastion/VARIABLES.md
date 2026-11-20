# bastion variables

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| apiserver\_subnet\_cidr | Range of the API server subnet, which the NSG lets the Bastion reach on 443 and 4443. | `string` | n/a | yes |
| apiserver\_subnet\_id | Subnet of the AKS API server. Gets an NSG that lets the Bastion reach the API server and nothing else. | `string` | n/a | yes |
| name | Name of the Bastion and its public IP; its two NSGs are named after it. | `string` | n/a | yes |
| nodes\_subnet\_id | Subnet of the AKS nodes. Gets an NSG that keeps the Bastion from reaching the nodes. | `string` | n/a | yes |
| region | Region of the Bastion. Must match the VNet's. | `string` | n/a | yes |
| resource\_group\_name | Resource group the Bastion, its public IP and its NSGs are created in. | `string` | n/a | yes |
| subnet\_cidr | Range of the AzureBastionSubnet, and the source the NSG rules match. A /26 at least. | `string` | n/a | yes |
| vnet\_id | VNet holding the private API server, where the AzureBastionSubnet is created. | `string` | n/a | yes |
| scale\_units | Instances, each handling a share of concurrent sessions. 2 to 50. | `number` | `2` | no |
| tags | Applied to every taggable resource this module creates. | `map(string)` | `{}` | no |
| tunnel\_principal\_ids | Entra group object IDs allowed to open a tunnel through this Bastion. | `list(string)` | `[]` | no |
<!-- END_TF_DOCS -->
