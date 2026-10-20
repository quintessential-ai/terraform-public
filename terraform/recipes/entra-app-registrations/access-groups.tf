# Complexio's standard access groups, and one Stevie group per department, named
# <access_group_name_prefix>-<name>. Created only with var.create_and_assign_access_groups.
locals {
  standard_access_groups = {
    "owners"                      = "Full configuration rights in Complexio Settings. Keep membership to a few administrators."
    "ea"                          = "Enterprise Automator access, without email visibility."
    "ea-evidence-view-full"       = "Enterprise Automator access, with full email visibility including message bodies."
    "vendor-system-configuration" = "Settings access for named Complexio staff. Needed for initial setup; optional afterwards."
    "vendor-support"              = "Stevie and Enterprise Automator access for named Complexio staff, limited to the monitoring data set."
  }
  department_access_groups = {
    for department in var.stevie_departments :
    "stevie-${department}" => "Stevie access for ${department}, with the data access you give this group in Settings."
  }
  access_groups = var.create_and_assign_access_groups ? {
    for name, description in merge(local.standard_access_groups, local.department_access_groups) :
    "${var.access_group_name_prefix}-${name}" => description
  } : {}
}

# The access groups, as security groups: only their direct members get access, and Microsoft 365
# groups, distribution lists and nested groups wouldn't. Applying stops rather than creating a
# second group when one with the same name exists. Later applies leave their members, owners and
# descriptions as you set them.
resource "azuread_group" "access" {
  for_each = local.access_groups

  display_name            = each.key
  description             = each.value
  security_enabled        = true
  mail_enabled            = false
  prevent_duplicate_names = true

  lifecycle {
    ignore_changes = [members, owners, description]
  }
}

# Assigns each access group to Complexio - SSO, so its members can sign in.
resource "azuread_app_role_assignment" "access_group" {
  for_each = azuread_group.access

  app_role_id         = "00000000-0000-0000-0000-000000000000"
  principal_object_id = each.value.object_id
  resource_object_id  = azuread_service_principal.sso.object_id
}
