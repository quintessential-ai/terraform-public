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

# Moves each subnet, and the nodes subnet's egress association, from the network module to the module
# that creates it. Without these, Terraform replaces the subnets of applied clusters. The ingress
# subnet and the association had a count in both modules: the aks-cluster module drops their index.

moved {
  from = module.network.azurerm_subnet.nodes
  to   = module.cluster.azurerm_subnet.nodes
}

moved {
  from = module.network.azurerm_subnet.apiserver
  to   = module.cluster.azurerm_subnet.apiserver
}

moved {
  from = module.network.azurerm_subnet.ingress_lb[0]
  to   = module.cluster.azurerm_subnet.ingress_lb[0]
}

moved {
  from = module.network.azurerm_subnet_route_table_association.nodes[0]
  to   = module.cluster.azurerm_subnet_route_table_association.nodes[0]
}

# The egress route table moved to the module that creates the nodes subnet. It used to have a count.
moved {
  from = module.network.azurerm_route_table.egress[0]
  to   = module.cluster.azurerm_route_table.egress
}

moved {
  from = module.network.azurerm_subnet.bastion[0]
  to   = module.bastion[0].azurerm_subnet.this
}
