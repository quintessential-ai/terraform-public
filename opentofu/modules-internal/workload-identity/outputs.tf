output "client_id" {
  description = "Value for the azure.workload.identity/client-id ServiceAccount annotation."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "principal_id" {
  value = azurerm_user_assigned_identity.this.principal_id
}

output "id" {
  value = azurerm_user_assigned_identity.this.id
}

output "name" {
  value = azurerm_user_assigned_identity.this.name
}
