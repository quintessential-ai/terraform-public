# These used to have a count. They keep the resources of a state applied before they became
# unconditional.

moved {
  from = azurerm_subnet.ingress_lb[0]
  to   = azurerm_subnet.ingress_lb
}

moved {
  from = azurerm_subnet_route_table_association.nodes[0]
  to   = azurerm_subnet_route_table_association.nodes
}

moved {
  from = azurerm_role_assignment.route_table[0]
  to   = azurerm_role_assignment.route_table
}
