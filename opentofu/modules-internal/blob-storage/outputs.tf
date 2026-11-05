output "id" {
  value = azurerm_storage_account.this.id
}

output "name" {
  value = azurerm_storage_account.this.name
}

output "primary_blob_endpoint" {
  value = azurerm_storage_account.this.primary_blob_endpoint
}

output "container_names" {
  value = keys(azurerm_storage_container.this)
}

# For role assignments scoped to one container.
output "container_ids" {
  value = { for name, container in azurerm_storage_container.this : name => container.id }
}
