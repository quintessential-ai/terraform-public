# complexio-cluster variables

<!-- `terraform-docs` writes the table from the variables' declarations; `tf_tools autofix` runs it.
Only the text above the table is written by hand: see "Lists of variables" in terraform/README.md. -->

Every input of the recipe. Values are set in the `.tfvars` file.

Required is **yes** when the variable has no default, so a value must be given; these come first.
A variable needed only in some cases says so in its description. Two more are required although
they have a default:

- Exactly one of `resource_group_name` and `existing_resource_group_name`.
- `azure_rbac`: `cluster_admin_principal_ids` must not be empty, and must hold whoever runs Terraform.

With an existing VNet (`existing_vnet_name`), no subnet range is derived: every subnet in use needs
an explicit, free range in that VNet.

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| admin\_groups | Entra group object IDs added to both azure\_rbac.cluster\_admin\_principal\_ids and key\_vault\_secrets\_officer\_groups. Whoever runs this recipe must be in one. | `list(string)` | n/a | yes |
| customer\_name | Given by Complexio. Names the customer's deployment artifact in Complexio's registry, oci://complexio.azurecr.io/deployments/<customer\_name>. | `string` | n/a | yes |
| external\_key\_vault | Given by Complexio: the Key Vault it creates for this customer in its own tenant, by name (the `<name>` in `https://<name>.vault.azure.net`), and the client ID of the identity ExternalSecrets reads it with. The bootstrap points ExternalSecrets at it to get the ACR token Flux pulls the top-level artifact with. | <pre>object({<br/>    external_secrets_client_id = string<br/>    name                       = string<br/>  })</pre> | n/a | yes |
| region | Azure region, e.g. westeurope. | `string` | n/a | yes |
| subscription\_id | Subscription the cluster and its resource group live in. | `string` | n/a | yes |
| apiserver\_subnet\_cidr | Defaults to the second /24 of vnet\_cidr. Required when existing\_vnet\_name is set. | `string` | `null` | no |
| availability\_zones | Zones the core nodes and the network appliance Terraform creates are spread across. | `list(string)` | <pre>[<br/>  "1",<br/>  "2",<br/>  "3"<br/>]</pre> | no |
| azure\_key\_vault\_name | Key Vault names are globally unique, so a custom name is often necessary. Defaults to <cluster\_name>-<random\_string>. | `string` | `null` | no |
| azure\_rbac | Entra group object IDs per AKS built-in role, on top of admin\_groups. https://learn.microsoft.com/en-us/azure/aks/manage-azure-rbac#aks-built-in-roles | <pre>object({<br/>    admin_principal_ids         = optional(list(string), [])<br/>    cluster_admin_principal_ids = optional(list(string), [])<br/>    writer_principal_ids        = optional(list(string), [])<br/>    reader_principal_ids        = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| bastion\_subnet\_cidr | Defaults to the third /24 of vnet\_cidr. Required when existing\_vnet\_name and create\_bastion are set. | `string` | `null` | no |
| blob\_storage\_account\_name | Account names are globally unique (`<name>.blob.core.windows.net`), so a custom name is often necessary. Defaults to the cluster name's letters and digits followed by a random string. | `string` | `null` | no |
| blob\_storage\_existing\_private\_dns\_zone\_id | An existing privatelink.blob.core.windows.net zone already linked to the cluster's VNet. Created when unset. | `string` | `null` | no |
| blob\_storage\_replication\_type | LRS, ZRS, GRS, RAGRS, GZRS or RAGZRS. | `string` | `"ZRS"` | no |
| blob\_storage\_soft\_delete\_retention\_days | Days a deleted blob or container can be restored for, between 1 and 365. | `number` | `30` | no |
| blob\_storage\_subnet\_cidr | Range of the private endpoint's subnet. Defaults to the fifth /24 of vnet\_cidr. Required when existing\_vnet\_name is set. | `string` | `null` | no |
| cluster\_name | Name of the AKS cluster and its VNet; also the base of the generated resource names. | `string` | `"complexio-aks"` | no |
| core\_worker\_pool\_os\_disk\_size | OS disk size of the core node pool, in GB. | `number` | `64` | no |
| core\_worker\_pool\_vm\_size | VM size of the core node pool. | `string` | `"Standard_B2s_v2"` | no |
| create\_bastion | Create an Azure Bastion (and its subnet) to reach the private API server. Leave false when the customer has its own way in, such as a VPN. | `bool` | `false` | no |
| create\_blob\_storage | Create the storage account behind S3Proxy, reachable through a private endpoint in the cluster's VNet, and the s3proxy and neo4j-backup workload identities that read and write it. | `bool` | `true` | no |
| create\_gateway\_public\_ip | Removed: the gateway always has a private IP, and the network appliance forwards HTTPS to it. | `any` | `null` | no |
| create\_postgres | Create a private PostgreSQL flexible server in the same VNet. | `bool` | `true` | no |
| dns\_enable\_delegation | Write an NS record into the parent zone so it answers queries for the child zone. Requires write access to the parent zone. | `bool` | `false` | no |
| dns\_parent\_zone\_resource\_group\_name | Resource group of the parent DNS zone. Defaults to the cluster's resource group. | `string` | `null` | no |
| dns\_parent\_zone\_subscription\_id | Subscription of the parent DNS zone. Defaults to the cluster's subscription. | `string` | `null` | no |
| dns\_zone | Child zone to create, named `<prefix>.<parent_zone_name>`. Leave unset to not manage DNS. | <pre>object({<br/>    prefix           = string<br/>    parent_zone_name = string<br/>  })</pre> | `null` | no |
| docker\_acr\_registries | Registries holding the container images the cluster's pods run. | <pre>list(object({<br/>    name                = string<br/>    resource_group_name = string<br/>    subscription_id     = string<br/>  }))</pre> | `[]` | no |
| enable\_azure\_container\_storage | Turn on Azure Container Storage. | `bool` | `true` | no |
| existing\_network\_appliance\_private\_ip | Private IP of the existing network appliance, the next hop for all egress. Required when network\_appliance is "existing". | `string` | `null` | no |
| existing\_network\_appliance\_public\_endpoint | Public IPv4 address or DNS name of the existing network appliance, for HTTPS ingress. Required when network\_appliance is "existing" and dns\_zone is set. | `string` | `null` | no |
| existing\_network\_appliance\_subscription\_id | Subscription of existing\_network\_appliance\_vnet\_id. Defaults to the cluster's subscription. | `string` | `null` | no |
| existing\_network\_appliance\_vnet\_id | Resource ID of the VNet holding the existing network appliance. Terraform peers it with the cluster's VNet both ways. Set existing\_network\_appliance\_subscription\_id when it is in another subscription. Required when network\_appliance is "existing". | `string` | `null` | no |
| existing\_resource\_group\_name | Resource group to reuse. Mutually exclusive with resource\_group\_name. | `string` | `null` | no |
| existing\_vnet\_name | If set, the AKS subnet is created in this VNet instead of a new one. | `string` | `null` | no |
| existing\_vnet\_resource\_group\_name | Resource group of existing\_vnet\_name. Defaults to the cluster's resource group. | `string` | `null` | no |
| generic\_acr\_registries | Registries holding generic OCI artifacts such as models, pulled by inference workers. | <pre>list(object({<br/>    name                = string<br/>    resource_group_name = string<br/>    subscription_id     = string<br/>  }))</pre> | `[]` | no |
| ingress\_lb\_subnet\_cidr | Subnet for the cluster's private load balancer. Defaults to the sixth /24 of vnet\_cidr. Required when existing\_vnet\_name is set. | `string` | `null` | no |
| k8s\_namespaces | One namespace per Complexio installation in the cluster. | `list(string)` | <pre>[<br/>  "complexio-prod",<br/>  "complexio-prodv2"<br/>]</pre> | no |
| key\_vault\_secrets\_officer\_groups | Principal IDs granted Key Vault Secrets Officer and Key Vault Certificates Officer on the Key Vault, on top of admin\_groups. Whoever runs entra-app-registrations must be in one of these or in admin\_groups. | `list(string)` | `[]` | no |
| kubernetes\_version | AKS Kubernetes version. | `string` | `"1.36"` | no |
| managed\_cluster\_sku\_tier | AKS pricing tier. | `string` | `"Standard"` | no |
| network\_appliance | What all traffic in and out of the cluster goes through. "vm\_scale\_set": a scale set of Linux VMs behind load balancers, created by Terraform. "azure\_firewall": an Azure Firewall, created by Terraform. "existing": the customer's own appliance, such as a firewall in a hub reached over a VNet peering. All egress goes to the appliance's private IP, and the gateway has only a private IP that the appliance forwards HTTPS to. It can be changed on an existing cluster. | `string` | `"vm_scale_set"` | no |
| network\_appliance\_subnet\_cidr | Range of the network appliance Terraform creates, a /24 at least: the firewall takes its first half, the scale set its second. Defaults to the seventh /24 of vnet\_cidr. Required when existing\_vnet\_name is set, unless network\_appliance is "existing". | `string` | `null` | no |
| node\_provisioning\_mode | "Auto" hands node provisioning to Karpenter (NAP). | `string` | `"Auto"` | no |
| nodes\_subnet\_cidr | Defaults to the first /24 of vnet\_cidr. Required when existing\_vnet\_name is set. | `string` | `null` | no |
| postgres\_administrator\_login | Administrator user name. | `string` | `"complexio"` | no |
| postgres\_administrator\_password | Set through TF\_VAR\_postgres\_administrator\_password. Generated when unset. | `string` | `null` | no |
| postgres\_administrator\_password\_version | Increasing it rotates the administrator password: Terraform sends the current postgres\_administrator\_password, or a newly generated one, to the server and the Key Vault again. Always consult Complexio before changing it. | `number` | `1` | no |
| postgres\_backup\_retention\_days | Days of backups kept, between 7 and 35. | `number` | `14` | no |
| postgres\_existing\_private\_dns\_zone\_id | An existing privatelink.postgres.database.azure.com zone already linked to the cluster's VNet. Created when unset. | `string` | `null` | no |
| postgres\_extensions | Extensions allowed on the server (azure.extensions). Null keeps the module's list: vector, pg\_stat\_statements, pg\_trgm, pgstattuple, uuid-ossp and btree\_gin. | `list(string)` | `null` | no |
| postgres\_maintenance\_window | Weekly maintenance window in UTC; day\_of\_week 0 is Sunday. | <pre>object({<br/>    day_of_week  = optional(number, 0)<br/>    start_hour   = optional(number, 2)<br/>    start_minute = optional(number, 0)<br/>  })</pre> | <pre>{<br/>  "day_of_week": 0,<br/>  "start_hour": 2,<br/>  "start_minute": 0<br/>}</pre> | no |
| postgres\_name | Server names are globally unique (`<name>.postgres.database.azure.com`), so a custom name is often necessary. Defaults to `<cluster_name>-pg-<random_string>`. | `string` | `null` | no |
| postgres\_pgbouncer\_parameters | pgbouncer.* server parameters, merged over the module's defaults: pgbouncer.enabled = true, pgbouncer.max\_prepared\_statements = 256. The others are dropped while pgbouncer.enabled is false. A parameter removed from both keeps its last value on the server: set it to its default to revert it. | `map(string)` | `{}` | no |
| postgres\_server\_parameters | Postgres server parameters, merged over the module's defaults (tuned from the SKU's vCPUs and memory). Values are in each parameter's base unit (pg\_settings.unit), e.g. ms for idle\_in\_transaction\_session\_timeout. A parameter removed from both keeps its last value on the server: set it to its default to revert it. | `map(string)` | `{}` | no |
| postgres\_sku\_name | Compute SKU: memory optimized E (MO\_Standard\_E...) or general purpose D (GP\_Standard\_D...). Use MO\_Standard\_E16ds\_v5 where v6 is not available in the region. | `string` | `"MO_Standard_E16ds_v5"` | no |
| postgres\_storage\_iops | Provisioned disk IOPS. | `number` | `12000` | no |
| postgres\_storage\_size\_mb | Premium SSD v2 disk size in MB. 2097152 = 2 TB. | `number` | `2097152` | no |
| postgres\_storage\_throughput\_mbps | Provisioned disk throughput in MB/s. | `number` | `1000` | no |
| postgres\_subnet\_cidr | Range of the server's delegated subnet, a /28 at least. Defaults to the fourth /24 of vnet\_cidr. Required when existing\_vnet\_name is set. | `string` | `null` | no |
| postgres\_version | Postgres major version. | `string` | `"18"` | no |
| postgres\_zone | Availability zone of the server, read at creation only. Azure picks one when unset. | `string` | `null` | no |
| private\_cluster\_enabled | Keep the API server private. Set false only for internal development clusters. | `bool` | `true` | no |
| resource\_group\_name | Resource group to create. Mutually exclusive with existing\_resource\_group\_name. | `string` | `null` | no |
| tags | Applied to every taggable resource this recipe creates. | `map(string)` | `{}` | no |
| use\_existing\_network\_appliance | Replaced by network\_appliance = "existing". | `any` | `null` | no |
| vnet\_cidr | Address space of the VNet the recipe creates, carved into one /24 per subnet. Ignored when existing\_vnet\_name is set. | `string` | `"10.224.0.0/16"` | no |
| vnet\_peerings | VNets to peer the cluster's VNet with, keyed by a name stable at plan time. | <pre>map(object({<br/>    remote_virtual_network_id    = string<br/>    allow_virtual_network_access = optional(bool, true)<br/>    allow_forwarded_traffic      = optional(bool, false)<br/>    allow_gateway_transit        = optional(bool, false)<br/>    use_remote_gateways          = optional(bool, false)<br/>    create_reverse_peering       = optional(bool, true)<br/>  }))</pre> | `{}` | no |
<!-- END_TF_DOCS -->
