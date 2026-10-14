data "azurerm_resource_group" "this" {
  count = var.location == null ? 1 : 0
  name  = var.resource_group_name
}

locals {
  location        = coalesce(var.location, one(data.azurerm_resource_group.this[*].location))
  create_subnet   = var.existing_subnet_id == null
  create_dns_zone = var.existing_private_dns_zone_id == null
}

# --- Subnet ---------------------------------------------------------------------------------------

resource "azurerm_subnet" "this" {
  count                = local.create_subnet ? 1 : 0
  name                 = coalesce(var.subnet_name, "${var.name}-subnet")
  resource_group_name  = split("/", var.vnet_id)[4]
  virtual_network_name = split("/", var.vnet_id)[8]
  address_prefixes     = [var.subnet_cidr]

  delegation {
    name = "Microsoft.DBforPostgreSQL/flexibleServers"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# --- Private DNS ----------------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "this" {
  count               = local.create_dns_zone ? 1 : 0
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  count               = local.create_dns_zone ? 1 : 0
  name                = "${var.name}-vnet"
  private_dns_zone_id = azurerm_private_dns_zone.this[0].id
  virtual_network_id  = var.vnet_id
  tags                = var.tags
}

# --- Server ---------------------------------------------------------------------------------------

resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = local.location
  version             = var.postgres_version
  sku_name            = var.sku_name
  zone                = var.zone

  delegated_subnet_id           = local.create_subnet ? azurerm_subnet.this[0].id : var.existing_subnet_id
  private_dns_zone_id           = local.create_dns_zone ? azurerm_private_dns_zone_virtual_network_link.this[0].private_dns_zone_id : var.existing_private_dns_zone_id
  public_network_access_enabled = false

  storage_type       = "PremiumV2_LRS"
  storage_mb         = var.storage.size_mb
  storage_iops       = var.storage.iops
  storage_throughput = var.storage.throughput_mbps

  backup_retention_days = var.backup_retention_days

  administrator_login               = var.administrator_login
  administrator_password_wo         = local.administrator_password
  administrator_password_wo_version = var.administrator_password_version

  dynamic "maintenance_window" {
    for_each = var.maintenance_window == null ? [] : [var.maintenance_window]
    content {
      day_of_week  = maintenance_window.value.day_of_week
      start_hour   = maintenance_window.value.start_hour
      start_minute = maintenance_window.value.start_minute
    }
  }

  tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# --- Server parameters ----------------------------------------------------------------------------

# Values are in each parameter's Postgres base unit (pg_settings.unit), as Azure expects them.
locals {
  sku_match = regex("_Standard_([A-Z])(\\d+)", var.sku_name)
  vcpus     = tonumber(local.sku_match[1])
  memory_gb = local.vcpus * (local.sku_match[0] == "E" ? 8 : 4)

  default_server_parameters = {
    shared_buffers                        = local.memory_gb / 2 * 1024 * 1024 / 8
    effective_cache_size                  = local.memory_gb * 1.5 * 1024 * 1024 / 8
    work_mem                              = max(floor(local.memory_gb / 2), 4) * 1024
    maintenance_work_mem                  = min(local.memory_gb * 64, 2047) * 1024
    wal_buffers                           = 16 * 1024 / 8
    temp_file_limit                       = 300 * 1024 * 1024
    huge_pages                            = "try"
    max_connections                       = 300
    max_worker_processes                  = max(local.vcpus * 2, 8)
    max_parallel_workers                  = max(local.vcpus, 8)
    max_parallel_workers_per_gather       = 2
    max_parallel_maintenance_workers      = max(floor(local.vcpus / 4), 2)
    effective_io_concurrency              = 16
    random_page_cost                      = "1.4"
    max_wal_size                          = 63 * 1024
    min_wal_size                          = 12 * 1024
    wal_receiver_timeout                  = 30 * 1000
    wal_sender_timeout                    = 60 * 1000
    max_replication_slots                 = 10
    max_wal_senders                       = 10
    max_logical_replication_workers       = 8
    max_sync_workers_per_subscription     = 8
    checkpoint_completion_target          = "0.9"
    checkpoint_timeout                    = 300
    default_statistics_target             = 500
    track_activity_query_size             = 4096
    track_io_timing                       = "on"
    idle_in_transaction_session_timeout   = 60 * 60 * 1000
    autovacuum_analyze_scale_factor       = "0.005"
    autovacuum_analyze_threshold          = 1000
    autovacuum_max_workers                = max(floor(local.vcpus / 2) + 1, 3)
    autovacuum_naptime                    = 20
    autovacuum_vacuum_cost_delay          = 20
    autovacuum_vacuum_cost_limit          = 10000
    autovacuum_vacuum_insert_scale_factor = "0.2"
    autovacuum_vacuum_insert_threshold    = 1000
    autovacuum_vacuum_scale_factor        = "0.025"
    autovacuum_vacuum_threshold           = 2000
    autovacuum_work_mem                   = min(local.memory_gb * 16, 2047) * 1024
    vacuum_cost_delay                     = 0
    vacuum_cost_limit                     = 10000
    vacuum_cost_page_dirty                = 30
    vacuum_cost_page_hit                  = 1
    vacuum_cost_page_miss                 = 15
    log_autovacuum_min_duration           = 0
    log_checkpoints                       = "on"
    log_connections                       = "on"
    log_disconnections                    = "on"
    log_lock_waits                        = "on"
    log_temp_files                        = 0
    shared_preload_libraries              = "auto_explain,pg_cron,pg_stat_statements"
    "pg_stat_statements.track"            = "all"
    "pg_stat_statements.max"              = 10000
    "pg_stat_statements.track_utility"    = "off"
    "pgbouncer.enabled"                   = "true"
    "pgbouncer.max_prepared_statements"   = 256
  }

  server_parameters = merge(
    { for name, value in local.default_server_parameters : name => tostring(value) },
    var.server_parameters,
  )
}

resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = join(",", var.extensions)
}

resource "azurerm_postgresql_flexible_server_configuration" "this" {
  for_each  = local.server_parameters
  name      = each.key
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = each.value

  depends_on = [azurerm_postgresql_flexible_server_configuration.extensions]
}

# --- Credentials ----------------------------------------------------------------------------------

ephemeral "random_password" "administrator" {
  length      = 32
  special     = false
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

locals {
  administrator_password = coalesce(var.administrator_password, ephemeral.random_password.administrator.result)
}

resource "azurerm_key_vault_secret" "pguser" {
  name         = "deployments-prod--PGUSER"
  key_vault_id = var.key_vault_id
  value        = var.administrator_login

  depends_on = [azurerm_postgresql_flexible_server.this]
}

resource "azurerm_key_vault_secret" "pgpassword" {
  name             = "deployments-prod--PGPASSWORD"
  key_vault_id     = var.key_vault_id
  value_wo         = local.administrator_password
  value_wo_version = var.administrator_password_version

  depends_on = [azurerm_postgresql_flexible_server.this]
}
