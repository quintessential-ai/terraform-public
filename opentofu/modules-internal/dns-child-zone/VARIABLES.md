# dns-child-zone variables

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| dns\_zone | Child zone to create, named `<prefix>.<parent_zone_name>`. | <pre>object({<br/>    prefix           = string<br/>    parent_zone_name = string<br/>  })</pre> | n/a | yes |
| resource\_group\_name | Resource group the zone is created in. | `string` | n/a | yes |
| dns\_enable\_delegation | Write an NS record into the parent zone so it answers queries for the child zone. Requires write access to the parent zone. | `bool` | `false` | no |
| dns\_parent\_zone\_resource\_group\_name | Resource group of the parent DNS zone. Defaults to the cluster's resource group. | `string` | `null` | no |
| ns\_record\_ttl | TTL, in seconds, of the NS record written into the parent zone when dns\_enable\_delegation is set. | `number` | `3600` | no |
| tags | Applied to every taggable resource this module creates. | `map(string)` | `{}` | no |
<!-- END_TF_DOCS -->
