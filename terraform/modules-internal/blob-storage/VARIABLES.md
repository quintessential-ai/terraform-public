# blob-storage variables

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Globally unique: it becomes `<name>.blob.core.windows.net`. | `string` | n/a | yes |
| region | Region of the account and its private endpoint. Must match the VNet's. | `string` | n/a | yes |
| resource\_group\_name | Resource group the storage account and its private endpoint are created in, and the private DNS zone when one is created. | `string` | n/a | yes |
| vnet\_id | VNet the private endpoint lives in. Its subnet is created here unless existing\_subnet\_id is set. | `string` | n/a | yes |
| container\_names | Containers created with the account. Clients with Storage Blob Data Contributor on the account can create more. | `set(string)` | `[]` | no |
| existing\_private\_dns\_zone\_id | A privatelink.blob.core.windows.net zone already linked to the VNet. Created and linked to vnet\_id when unset. | `string` | `null` | no |
| existing\_subnet\_id | A subnet to place the private endpoint in. | `string` | `null` | no |
| replication\_type | LRS, ZRS, GRS, RAGRS, GZRS or RAGZRS. | `string` | `"ZRS"` | no |
| soft\_delete\_retention\_days | Days a deleted blob or container can be restored for. | `number` | `30` | no |
| subnet\_cidr | Range of the subnet created for the private endpoint. | `string` | `null` | no |
| subnet\_name | Defaults to `<name>-subnet`. | `string` | `null` | no |
| tags | Applied to every taggable resource this module creates. | `map(string)` | `{}` | no |
<!-- END_TF_DOCS -->
