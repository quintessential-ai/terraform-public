variable "name_prefix" {
  description = "Prefixed to the identity name to keep it unique per cluster. Usually the cluster name."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  description = "Defaults to the resource group's location."
  type        = string
  default     = null
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL of the AKS cluster whose ServiceAccount tokens this identity trusts."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the ServiceAccount."
  type        = string
}

variable "service_account_name" {
  description = "The name of the K8S ServiceAccount."
  type        = string
}

variable "role_assignments" {
  description = "Azure roles granted to this identity, keyed by a name that is stable at plan time."
  type = map(object({
    role_definition_name = string
    scope                = string
    condition            = optional(string)
    condition_version    = optional(string)
  }))
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
