variable "display_names" {
  description = "Names of the two app registrations. Keep the defaults: one pair serves all your Complexio environments."
  type = object({
    sso     = optional(string, "Complexio - SSO")
    backend = optional(string, "Complexio - Backend")
  })
  default = {}
}

variable "browser_hosts" {
  description = "Host names your users open Complexio on, such as \"complexio.example.com\". Sign-in redirects back to these hosts only."
  type        = list(string)
}

variable "mcp_hosts" {
  description = "Host names of Complexio's MCP servers, if you use them. Leave empty otherwise."
  type        = list(string)
  default     = []
}

variable "features" {
  description = <<-EOT
    What Complexio may do in your Microsoft 365 tenant. Each switch grants the Microsoft Graph
    permissions that feature needs, and nothing is granted for a switch left off. Switches ending
    in "_delegated" let Stevie act as the signed-in user, limited to what that user can already
    see. The others let Complexio's services work without a signed-in user.
  EOT
  type = object({
    email_ingestion                 = optional(bool, true)
    teams_ingestion_where_installed = optional(bool, false)
    teams_ingestion_tenant_wide     = optional(bool, false)
    settings_directory              = optional(bool, true)
    automator_email                 = optional(bool, false)
    usage_metrics                   = optional(bool, true)

    stevie_mail_delegated       = optional(bool, true)
    stevie_calendar_delegated   = optional(bool, true)
    stevie_onedrive_delegated   = optional(bool, true)
    stevie_people_delegated     = optional(bool, true)
    stevie_meetings_delegated   = optional(bool, true)
    stevie_teams_delegated      = optional(bool, true)
    stevie_sharepoint_delegated = optional(bool, true)

    stevie_mail_drafting_delegated = optional(bool, false)
    stevie_mail_sending_delegated  = optional(bool, false)
  })
  default = {}

  validation {
    condition     = !var.features.stevie_mail_sending_delegated || var.features.stevie_mail_drafting_delegated
    error_message = "stevie_mail_sending_delegated needs stevie_mail_drafting_delegated: Stevie sends only drafts it has written. Both default to true, so to turn off drafting also set stevie_mail_sending_delegated = false."
  }
}

variable "additional_application_permissions" {
  description = "Further Microsoft Graph application permissions for Complexio - Backend, by name, such as \"Sites.Read.All\". Only add what Complexio has asked for."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for p in var.additional_application_permissions :
      !anytrue([for prefix in ["Mail", "Calendars.", "Contacts.", "SMTP.", "EWS."] : startswith(p, prefix)])
    ])
    error_message = "Mailbox, calendar and contact permissions can't be added here: in Microsoft Entra they reach every mailbox in the tenant. Mailbox access is granted in Exchange Online instead, scoped to the mailboxes you choose. See the exchange_mailbox_access_commands output."
  }

  validation {
    condition     = length(setintersection(var.additional_application_permissions, ["Chat.Read.All", "Chat.ReadWrite.All"])) == 0
    error_message = "Chat.Read.All and Chat.ReadWrite.All can't be added: they would reach every chat in the tenant, including one-to-one chats. Teams ingestion reads only the chats the Complexio Assistant app is installed in."
  }
}

# --- Teams ingestion ----------------------------------------------------------------------------

variable "event_hub_namespace_id" {
  description = "Resource ID of the Event Hubs namespace Microsoft Graph sends Teams change notifications to, such as \"/subscriptions/<subscription_id>/resourceGroups/<resource_group>/providers/Microsoft.EventHub/namespaces/complexio-msgraph\". Needed with teams_ingestion_where_installed or teams_ingestion_tenant_wide, and unused otherwise. It may be in another subscription than the Key Vault."
  type        = string
  default     = null

  validation {
    condition     = var.event_hub_namespace_id == null || can(regex("(?i)^/subscriptions/[0-9a-f-]{36}/resourceGroups/[^/]+/providers/Microsoft\\.EventHub/namespaces/[^/]+$", var.event_hub_namespace_id))
    error_message = "event_hub_namespace_id must be an Event Hubs namespace's resource ID: /subscriptions/<subscription_id>/resourceGroups/<resource_group>/providers/Microsoft.EventHub/namespaces/<namespace>. The namespace's Properties page in the Azure portal shows it."
  }

  validation {
    condition     = var.event_hub_namespace_id != null || !(var.features.teams_ingestion_where_installed || var.features.teams_ingestion_tenant_wide)
    error_message = "Teams ingestion needs event_hub_namespace_id: Complexio - Backend reads Microsoft Graph's Teams change notifications from that Event Hubs namespace, by default complexio-msgraph, and the recipe gives it Azure Event Hubs Data Receiver there. Set it to the namespace's resource ID, or switch off teams_ingestion_where_installed and teams_ingestion_tenant_wide."
  }
}

# --- Credentials and Key Vault ------------------------------------------------------------------

variable "key_vault_id" {
  description = "Key Vault Complexio's services read their credentials from. The client secrets, the certificates and the IDs they need are written here."
  type        = string
}

variable "key_vault_secret_prefix" {
  description = "Prefix of every Key Vault entry written, followed by \"--\". Use a different one for each Complexio environment sharing the vault."
  type        = string
  default     = "deployments"
}

variable "secret_validity_in_days" {
  description = "How long each client secret is valid. Secrets don't renew themselves: renew them before they expire."
  type        = number
  default     = 365
}

variable "certificate_validity_in_months" {
  description = "How long each certificate is valid. Certificates don't renew themselves: renew them before they expire."
  type        = number
  default     = 12
}

# --- Access groups ------------------------------------------------------------------------------

variable "create_and_assign_access_groups" {
  description = "Create Complexio's standard security groups and assign them to Complexio - SSO, so their members can sign in. You manage who is in each group."
  type        = bool
  default     = true
}

variable "access_group_name_prefix" {
  description = "Prefix of the access group names, such as \"complexio\" in \"complexio-owners\". Change it to follow your own naming convention."
  type        = string
  default     = "complexio"
}

variable "stevie_departments" {
  description = "Departments to create a Stevie access group for, named \"<prefix>-stevie-<department>\". Only used with create_and_assign_access_groups."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Applied to the Key Vault entries it writes."
  type        = map(string)
  default     = {}
}
