# postgres-flexible-server variables

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| key\_vault\_id | Key Vault the administrator login and password are stored in, as deployments-prod--PGUSER and deployments-prod--PGPASSWORD. | `string` | n/a | yes |
| name | Globally unique: it becomes `<name>.postgres.database.azure.com`. | `string` | n/a | yes |
| region | Region of the server. Must match the VNet's. | `string` | n/a | yes |
| resource\_group\_name | Resource group the server is created in, and the private DNS zone when one is created. | `string` | n/a | yes |
| storage | Premium SSD v2 disk. size\_mb: disk size in MB, 2097152 = 2 TB. iops: provisioned disk IOPS. throughput\_mbps: provisioned disk throughput in MB/s. | <pre>object({<br/>    size_mb         = number<br/>    iops            = number<br/>    throughput_mbps = number<br/>  })</pre> | n/a | yes |
| administrator\_login | Postgres administrator username. | `string` | `"complexio"` | no |
| administrator\_password | Generated when unset. Sent through write-only arguments, so it is never stored in state. | `string` | `null` | no |
| administrator\_password\_version | Increasing this value rotates the administrator password: Terraform sends the current administrator\_password to the server again. Always consult Complexio before changing it. | `number` | `1` | no |
| backup\_retention\_days | Days the server's backups are kept, 7 to 35. | `number` | `14` | no |
| existing\_private\_dns\_zone\_id | A privatelink.postgres.database.azure.com zone already linked to the VNet. Created and linked to vnet\_id when unset. | `string` | `null` | no |
| existing\_subnet\_id | A subnet already delegated to Microsoft.DBforPostgreSQL/flexibleServers. | `string` | `null` | no |
| extensions | Extensions allowed on the server (azure.extensions). | `list(string)` | <pre>[<br/>  "vector",<br/>  "pg_stat_statements",<br/>  "pg_trgm",<br/>  "pgstattuple",<br/>  "uuid-ossp",<br/>  "btree_gin"<br/>]</pre> | no |
| maintenance\_window | In UTC; day\_of\_week 0 is Sunday. Defaults to Sunday 02:00. | <pre>object({<br/>    day_of_week  = optional(number, 0)<br/>    start_hour   = optional(number, 2)<br/>    start_minute = optional(number, 0)<br/>  })</pre> | <pre>{<br/>  "day_of_week": 0,<br/>  "start_hour": 2,<br/>  "start_minute": 0<br/>}</pre> | no |
| pgbouncer\_parameters | pgbouncer.* server parameters, merged over the module's defaults: pgbouncer.enabled = true, pgbouncer.max\_prepared\_statements = 256. The others are dropped while pgbouncer.enabled is false. A parameter removed from both keeps its last value on the server: set it to its default to revert it. | `map(string)` | `{}` | no |
| postgres\_version | Postgres major version. | `string` | `"18"` | no |
| server\_parameters | Postgres server parameters, merged over the module's defaults (tuned from the SKU's vCPUs and memory). Values are in each parameter's base unit (pg\_settings.unit). A parameter removed from both keeps its last value on the server: set it to its default to revert it. | `map(string)` | `{}` | no |
| sku\_name | A memory optimized E (MO\_Standard\_E<vCPUs>...) or general purpose D (GP\_Standard\_D<vCPUs>...) SKU. | `string` | `"MO_Standard_E16ds_v5"` | no |
| subnet\_cidr | Range of the delegated subnet created for the server. A /28 is the minimum. | `string` | `null` | no |
| subnet\_name | Defaults to `<name>-subnet`. | `string` | `null` | no |
| tags | Applied to every taggable resource this module creates. | `map(string)` | `{}` | no |
| vnet\_id | VNet the server is injected into. Its subnet is created here unless existing\_subnet\_id is set. | `string` | `null` | no |
| zone | Availability zone of the primary, read at creation only. Azure picks one when unset. | `string` | `null` | no |
<!-- END_TF_DOCS -->
