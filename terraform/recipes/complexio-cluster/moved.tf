# The Key Vault used to be optional, with an existing vault as an alternative. These keep the
# resources of a state applied before it became unconditional.

moved {
  from = random_string.key_vault_suffix[0]
  to   = random_string.key_vault_suffix
}

moved {
  from = azurerm_key_vault.this[0]
  to   = azurerm_key_vault.this
}

moved {
  from = azurerm_role_assignment.created_key_vault_admins
  to   = azurerm_role_assignment.key_vault_admins
}

moved {
  from = azurerm_role_assignment.created_key_vault_secrets_officers
  to   = azurerm_role_assignment.key_vault_secrets_officers
}

moved {
  from = terraform_data.created_key_vault_id_after_grants[0]
  to   = terraform_data.key_vault_id_after_grants
}

moved {
  from = module.workload_identity["external-secrets"].azurerm_role_assignment.this["keyvault-created"]
  to   = module.workload_identity["external-secrets"].azurerm_role_assignment.this["keyvault"]
}
