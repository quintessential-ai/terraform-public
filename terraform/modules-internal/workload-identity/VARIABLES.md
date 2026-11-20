# workload-identity variables

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name\_prefix | Prefixed to the identity name to keep it unique per cluster. Usually the cluster name. | `string` | n/a | yes |
| namespace | Kubernetes namespace of the ServiceAccount. | `string` | n/a | yes |
| oidc\_issuer\_url | OIDC issuer URL of the AKS cluster whose ServiceAccount tokens this identity trusts. | `string` | n/a | yes |
| region | Region of the identity. | `string` | n/a | yes |
| resource\_group\_name | Resource group the identity is created in. | `string` | n/a | yes |
| service\_account\_name | The name of the K8S ServiceAccount. | `string` | n/a | yes |
| role\_assignments | Azure roles granted to this identity, keyed by a name that is stable at plan time. Name a built-in role by role\_definition\_name, a custom one by role\_definition\_id. | <pre>map(object({<br/>    role_definition_name = optional(string)<br/>    role_definition_id   = optional(string)<br/>    scope                = string<br/>    condition            = optional(string)<br/>    condition_version    = optional(string)<br/>  }))</pre> | `{}` | no |
| tags | Applied to every taggable resource this module creates. | `map(string)` | `{}` | no |
<!-- END_TF_DOCS -->
