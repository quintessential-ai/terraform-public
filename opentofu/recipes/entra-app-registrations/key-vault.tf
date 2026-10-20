# The IDs and client secrets Complexio's services read from your Key Vault, named
# <key_vault_secret_prefix>--CPX-<name>.
locals {
  key_vault_entry_prefix = "${var.key_vault_secret_prefix}--CPX"

  key_vault_secrets = {
    TENANT-ID           = data.azuread_client_config.current.tenant_id
    SSO-CLIENT-ID       = azuread_application.sso.client_id
    SSO-CHAT-API-SECRET = azuread_application_password.sso_chat_api.value
    SSO-GATEWAY-SECRET  = azuread_application_password.sso_gateway.value
    BACKEND-CLIENT-ID   = azuread_application.backend.client_id
    BACKEND-SECRET      = azuread_application_password.backend.value
  }
}

resource "azurerm_key_vault_secret" "this" {
  for_each = toset(keys(local.key_vault_secrets))

  name         = "${local.key_vault_entry_prefix}-${each.key}"
  value        = local.key_vault_secrets[each.key]
  content_type = "text/plain"
  key_vault_id = var.key_vault_id
  tags         = var.tags
}
