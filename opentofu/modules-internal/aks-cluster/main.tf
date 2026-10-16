# --- Derived defaults ---------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

# Only read when the caller leaves location unset.
data "azurerm_resource_group" "this" {
  count = var.location == null ? 1 : 0
  name  = var.resource_group_name
}

locals {
  location   = coalesce(var.location, one(data.azurerm_resource_group.this[*].location))
  dns_prefix = coalesce(var.dns_prefix, var.resource_group_name)
  tenant_id  = coalesce(var.tenant_id, data.azurerm_client_config.current.tenant_id)
}

# --- Cluster identity ---------------------------------------------------------------------------

# User-assigned so it can be granted the VNet before the cluster exists: API Server VNet
# Integration fails to provision without rights on the API server subnet.
resource "azurerm_user_assigned_identity" "cluster" {
  name                = "${var.cluster_name}-identity"
  resource_group_name = var.resource_group_name
  location            = local.location
  tags                = var.tags
}

# So AKS can read and join any subnet within the VNet.
resource "azurerm_role_assignment" "network_contributor" {
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
  principal_type       = "ServicePrincipal"
  role_definition_name = "Network Contributor"
  scope                = var.vnet_id
}

# --- Cluster ------------------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
  location            = local.location
  dns_prefix          = local.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  role_based_access_control_enabled = true
  azure_policy_enabled              = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  local_account_disabled            = true

  # API server behind an internal load balancer in the API server subnet. When public, it also
  # gets a public endpoint. https://learn.microsoft.com/en-us/azure/aks/api-server-vnet-integration
  private_cluster_enabled = var.private_cluster_enabled
  api_server_access_profile {
    subnet_id                           = var.apiserver_subnet_id
    virtual_network_integration_enabled = true
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  default_node_pool {
    name = "core"
    # Needed if vm_size, os_disk_size_gb, etc. change, to allow a smooth rotation of the node pool.
    temporary_name_for_rotation = "coretmp"
    # Without an availability zone the core nodes land in a physical zone we cannot see — their
    # topology.kubernetes.io/zone reads "0" — which makes any PVC bound there regional. Karpenter
    # then cannot provision a node to attach it to, since the nodes it creates are always zonal.
    zones                        = var.availability_zones
    vm_size                      = var.core_pool_vm_size
    node_count                   = var.core_pool_node_count
    auto_scaling_enabled         = false
    fips_enabled                 = false
    node_public_ip_enabled       = false
    kubelet_disk_type            = "OS"
    max_pods                     = 110
    type                         = "VirtualMachineScaleSets"
    orchestrator_version         = var.kubernetes_version
    os_disk_size_gb              = var.core_pool_os_disk_size_gb
    os_disk_type                 = "Managed"
    scale_down_mode              = "Delete"
    # Also the subnet Karpenter provisions into by default.
    # https://learn.microsoft.com/en-us/azure/aks/node-autoprovision-networking#default-subnet-behavior
    vnet_subnet_id = var.nodes_subnet_id
    tags           = var.tags

    upgrade_settings {
      max_surge = "10%"
    }
  }

  azure_active_directory_role_based_access_control {
    tenant_id          = local.tenant_id
    azure_rbac_enabled = var.azure_rbac_enabled
  }

  # Node auto-provisioning (Karpenter), with no default NodePools so ours are the only ones.
  node_provisioning_profile {
    mode               = var.node_provisioning_mode
    default_node_pools = "None"
  }

  # Managed Vertical Pod Autoscaler: AKS runs the recommender, updater and admission controller in
  # the control plane. https://learn.microsoft.com/en-us/azure/aks/use-vertical-pod-autoscaler
  workload_autoscaler_profile {
    vertical_pod_autoscaler_enabled = true
  }

  network_profile {
    network_plugin = "azure"
    # Azure CNI Overlay keeps pod IPs out of the VNet address space.
    # https://learn.microsoft.com/en-us/azure/aks/azure-cni-overlay
    network_plugin_mode = "overlay"
    # Karpenter recommends Cilium and does not support Calico.
    # https://learn.microsoft.com/en-us/azure/aks/node-autoprovision#networking-configuration
    network_data_plane = "cilium"
    network_policy     = "cilium"
    load_balancer_sku  = "standard"
    pod_cidr           = var.pod_cidr
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.network_contributor]
}

# --- Kubelet identity grants --------------------------------------------------------------------

# What `az aks update --attach-acr` does: let the kubelet identity pull images.
# https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration#use-kubelet-identity
resource "azurerm_role_assignment" "acr_pull" {
  for_each = var.acr_ids

  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  principal_type       = "ServicePrincipal"
  role_definition_name = "AcrPull"
  scope                = each.value
}

# --- Gateway public IP --------------------------------------------------------------------------

# The gateway's LoadBalancer Service borrows this IP through the azure-pip-name annotation rather
# than letting AKS create one in the node resource group. An AKS-created IP is deleted with its
# Service, so a recreated Gateway would come back on a new address and break DNS.
# https://learn.microsoft.com/en-us/azure/aks/static-ip
resource "azurerm_public_ip" "gateway" {
  count               = var.create_gateway_public_ip ? 1 : 0
  name                = "${var.cluster_name}-gateway"
  resource_group_name = var.resource_group_name
  location            = local.location
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = var.availability_zones
  tags                = var.tags

  # Off while we test apply/destroy. Uncomment for customer clusters, or terraform destroy deletes the IP.
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# AKS can only use resources in its own node resource group (MC_...) by default. This IP lives
# outside it, so the cluster needs Network Contributor here to attach the IP to its load balancer.
resource "azurerm_role_assignment" "gateway_public_ip" {
  count                = var.create_gateway_public_ip ? 1 : 0
  principal_id         = azurerm_user_assigned_identity.cluster.principal_id
  principal_type       = "ServicePrincipal"
  role_definition_name = "Network Contributor"
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
}

# --- Azure Container Storage --------------------------------------------------------------------

# See https://learn.microsoft.com/en-us/azure/storage/container-storage/container-storage-introduction
resource "azurerm_kubernetes_cluster_extension" "azure_container_storage" {
  count             = var.enable_azure_container_storage ? 1 : 0
  name              = "acstor"
  cluster_id        = azurerm_kubernetes_cluster.this.id
  extension_type    = "microsoft.azurecontainerstoragev2"
  release_train     = "stable"
  release_namespace = "kube-system"

  configuration_settings = {
    "csiDriverConfigs.local-csi-driver.enabled" = "True"
  }
}

# --- RBAC Access to the cluster ------------------------------------------------------------------

# Kubernetes authorization delegated to Azure RBAC: these built-in roles are scoped to the cluster
# and map onto in-cluster permissions.
# https://learn.microsoft.com/en-us/azure/aks/manage-azure-rbac#aks-built-in-roles

locals {
  role_names = {
    cluster_admin = "Azure Kubernetes Service RBAC Cluster Admin"
    admin         = "Azure Kubernetes Service RBAC Admin"
    writer        = "Azure Kubernetes Service RBAC Writer"
    reader        = "Azure Kubernetes Service RBAC Reader"
  }

  # For each principal define in `var.principal_id`, create a map entry with the principal_id and the
  # corresponding actual role name.
  assignments = merge([
    for role, principals in var.principal_ids : {
      for principal_id in principals :
      "${role}-${principal_id}" => { role = local.role_names[role], principal_id = principal_id }
    }
  ]...)
}

resource "azurerm_role_assignment" "this" {
  for_each = local.assignments

  principal_id         = each.value.principal_id
  principal_type       = "Group"
  role_definition_name = each.value.role
  scope                = azurerm_kubernetes_cluster.this.id
}

# Lets cluster admins run `az aks get-credentials`. The kubeconfig holds no secrets; what they can
# do in the cluster still comes from their RBAC role above.
resource "azurerm_role_assignment" "cluster_user" {
  for_each = toset(var.principal_ids.cluster_admin)

  principal_id         = each.value
  principal_type       = "Group"
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  scope                = azurerm_kubernetes_cluster.this.id
}
