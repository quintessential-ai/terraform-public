variable "cluster" {
  description = "The AKS cluster to bootstrap."
  type = object({
    id                  = string
    name                = string
    resource_group_name = string
    subscription_id     = string
  })
}

variable "cluster_access_granted" {
  description = "IDs of the role assignments that let whoever runs Terraform into the cluster. The bootstrap waits for them."
  type        = list(string)
}

variable "external_key_vault" {
  description = "Information the ExternalSecrets consumes to pull secrets from the external Key Vault that Complexio provisions for the customer. This Key Vault contains the secrets that Complexio must provide to the customer."
  type = object({
    tenant_id                  = string
    external_secrets_client_id = string
    key_vault_url              = string
  })

  validation {
    condition = alltrue([
      for id in [var.external_key_vault.tenant_id, var.external_key_vault.external_secrets_client_id] :
      can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))
    ])
    error_message = "external_key_vault.tenant_id and external_key_vault.external_secrets_client_id must be lowercase GUIDs."
  }

  validation {
    condition     = can(regex("^https://[a-z0-9-]+\\.vault\\.azure\\.net/?$", var.external_key_vault.key_vault_url))
    error_message = "external_key_vault.key_vault_url must be a Key Vault URL, e.g. https://<name>.vault.azure.net/."
  }
}

variable "customer_key_vault" {
  description = "Information the ExternalSecrets consumes to pull the Terraform inputs and outputs (`tf-complexio-cluster--INPUTS` and `--OUTPUTS`) from the customer's Key Vault, the one the recipe creates."
  type = object({
    tenant_id                  = string
    external_secrets_client_id = string
    key_vault_url              = string
  })

  validation {
    condition = alltrue([
      for id in [var.customer_key_vault.tenant_id, var.customer_key_vault.external_secrets_client_id] :
      can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", id))
    ])
    error_message = "customer_key_vault.tenant_id and customer_key_vault.external_secrets_client_id must be lowercase GUIDs."
  }

  validation {
    condition     = can(regex("^https://[a-z0-9-]+\\.vault\\.azure\\.net/?$", var.customer_key_vault.key_vault_url))
    error_message = "customer_key_vault.key_vault_url must be a Key Vault URL, e.g. https://<name>.vault.azure.net/."
  }
}

variable "oci_source_artifact" {
  description = "The top-level OCI artifact Flux syncs from. ref takes exactly one of tag, semver or digest."
  type = object({
    url = string
    ref = optional(object({
      tag    = optional(string)
      semver = optional(string)
      digest = optional(string)
    }), { tag = "latest" })
    path = string
  })

  validation {
    condition     = can(regex("^oci://[^/]+/.+", var.oci_source_artifact.url))
    error_message = "oci_source_artifact.url must be oci://<registry>/<repository>."
  }

  validation {
    condition     = length([for value in values(var.oci_source_artifact.ref) : value if value != null]) == 1
    error_message = "oci_source_artifact.ref must set exactly one of tag, semver or digest."
  }
}
