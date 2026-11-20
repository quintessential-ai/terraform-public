# cluster-bootstrap variables

<!-- BEGIN_TF_DOCS -->
## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| cluster | The AKS cluster to bootstrap. | <pre>object({<br/>    id                  = string<br/>    name                = string<br/>    resource_group_name = string<br/>    subscription_id     = string<br/>  })</pre> | n/a | yes |
| cluster\_access\_granted | IDs of the role assignments that let whoever runs Terraform into the cluster. The bootstrap waits for them. | `list(string)` | n/a | yes |
| customer\_key\_vault | Information the ExternalSecrets consumes to pull the Terraform inputs and outputs (`tf-complexio-cluster--INPUTS` and `--OUTPUTS`) from the customer's Key Vault, the one the recipe creates. | <pre>object({<br/>    tenant_id                  = string<br/>    external_secrets_client_id = string<br/>    key_vault_url              = string<br/>  })</pre> | n/a | yes |
| external\_key\_vault | Information the ExternalSecrets consumes to pull secrets from the external Key Vault that Complexio provisions for the customer. This Key Vault contains the secrets that Complexio must provide to the customer. | <pre>object({<br/>    tenant_id                  = string<br/>    external_secrets_client_id = string<br/>    key_vault_url              = string<br/>  })</pre> | n/a | yes |
| oci\_source\_artifact | The top-level OCI artifact Flux syncs from. ref takes exactly one of tag, semver or digest. | <pre>object({<br/>    url = string<br/>    ref = optional(object({<br/>      tag    = optional(string)<br/>      semver = optional(string)<br/>      digest = optional(string)<br/>    }), { tag = "latest" })<br/>    path = string<br/>  })</pre> | n/a | yes |
<!-- END_TF_DOCS -->
