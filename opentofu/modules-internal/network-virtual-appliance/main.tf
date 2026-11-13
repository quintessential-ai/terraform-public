# A network appliance built from a scale set of Linux VMs that forward traffic with nftables.
#
# Egress: the nodes route 0.0.0.0/0 to the internal load balancer, which hands each flow to one
# instance. The instance masquerades it, and the public load balancer's outbound rule translates it
# to the public IP.
# Ingress: the public load balancer sends the ingress ports to the instances, which DNAT them to
# ingress_target_ip and masquerade them, so replies come back through the same instance.

locals {
  vnet_resource_group_name = split("/", var.vnet_id)[4]
  vnet_name                = split("/", var.vnet_id)[8]

  # The next hop of the nodes' egress. Azure reserves the first four addresses of every subnet.
  private_ip = cidrhost(var.subnet_cidr, 4)

  # The port the load balancers probe. Kept out of ingress_ports by that variable's validation.
  health_port = 8080

  # Seconds a draining instance keeps forwarding existing flows before resetting them.
  drain_grace_seconds = 60

  # The public IP has 64,000 SNAT ports, allocated per instance in multiples of 8. One instance more
  # than instance_count fits, for the instance a rolling upgrade or a repair adds before removing one.
  snat_ports_per_instance = floor(64000 / (var.instance_count + 1) / 8) * 8

  # Azure names Arm64 sizes with a "p" among their additive features, e.g. Standard_B2pts_v2.
  # https://learn.microsoft.com/en-us/azure/virtual-machines/vm-naming-conventions
  arm64 = can(regex("^Standard_[A-Z]+[0-9]+[a-z]*p[a-z]*(_|$)", var.vm_size))
}

# --- Subnet ---------------------------------------------------------------------------------------

resource "azurerm_subnet" "this" {
  name                 = "network-appliance"
  resource_group_name  = local.vnet_resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.subnet_cidr]
}

# A Standard load balancer only lets in what an NSG allows. The default rules already allow the
# health probes and traffic between addresses of the VNet.
resource "azurerm_network_security_group" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.region
  tags                = var.tags

  # The public ingress the appliance forwards to the gateway.
  #trivy:ignore:AZU-0047
  security_rule {
    name                       = "allow-internet-ingress"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "Internet"
    source_port_range          = "*"
    destination_address_prefix = var.subnet_cidr
    destination_port_ranges    = [for port in var.ingress_ports : tostring(port)]
  }

  # The nodes' egress. Its destination is on the internet, so the default rule for traffic within
  # the VNet doesn't match it.
  security_rule {
    name                       = "allow-vnet-egress"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_address_prefix      = "VirtualNetwork"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

# --- Internal load balancer: the K8S nodes' next hop -----------------------------------------------

resource "azurerm_lb" "internal" {
  name                = "${var.name}-internal"
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                          = "egress"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.private_ip
    zones                         = var.availability_zones
  }
}

resource "azurerm_lb_backend_address_pool" "internal" {
  name            = "instances"
  loadbalancer_id = azurerm_lb.internal.id
}

resource "azurerm_lb_probe" "internal" {
  name                = "health"
  loadbalancer_id     = azurerm_lb.internal.id
  protocol            = "Http"
  port                = local.health_port
  request_path        = "/"
  interval_in_seconds = 5
  probe_threshold     = 2
}

# HA ports: every protocol and port, so the instances see the flows as the nodes sent them.
resource "azurerm_lb_rule" "egress" {
  name                           = "egress"
  loadbalancer_id                = azurerm_lb.internal.id
  frontend_ip_configuration_name = "egress"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.internal.id]
  probe_id                       = azurerm_lb_probe.internal.id
}

# --- Public load balancer: ingress and the egress SNAT --------------------------------------------

resource "azurerm_public_ip" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = var.availability_zones
  tags                = var.tags
}

resource "azurerm_lb" "public" {
  name                = "${var.name}-public"
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.this.id
  }
}

resource "azurerm_lb_backend_address_pool" "public" {
  name            = "instances"
  loadbalancer_id = azurerm_lb.public.id
}

resource "azurerm_lb_probe" "public" {
  name                = "health"
  loadbalancer_id     = azurerm_lb.public.id
  protocol            = "Http"
  port                = local.health_port
  request_path        = "/"
  interval_in_seconds = 5
  probe_threshold     = 2
}

# The outbound rule below translates the egress. A load-balancing rule on the same frontend must not.
resource "azurerm_lb_rule" "ingress" {
  for_each = toset([for port in var.ingress_ports : tostring(port)])

  name                           = "ingress-${each.value}"
  loadbalancer_id                = azurerm_lb.public.id
  frontend_ip_configuration_name = "public"
  protocol                       = "Tcp"
  frontend_port                  = tonumber(each.value)
  backend_port                   = tonumber(each.value)
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.public.id]
  probe_id                       = azurerm_lb_probe.public.id
  disable_outbound_snat          = true
  tcp_reset_enabled              = true
}

# Each instance gets a fixed share of the public IP's SNAT ports. An idle flow is reset at both
# ends after the timeout, instead of being dropped silently.
resource "azurerm_lb_outbound_rule" "egress" {
  name                     = "egress"
  loadbalancer_id          = azurerm_lb.public.id
  protocol                 = "All"
  backend_address_pool_id  = azurerm_lb_backend_address_pool.public.id
  allocated_outbound_ports = local.snat_ports_per_instance
  idle_timeout_in_minutes  = 4
  tcp_reset_enabled        = true

  frontend_ip_configuration {
    name = "public"
  }
}

# --- Instances ------------------------------------------------------------------------------------

# Azure requires an SSH key for the admin user. Nobody uses it: cloud-init turns SSH off, and the
# instances are reached with `az vmss run-command`.
resource "tls_private_key" "admin" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  admin_username = "azureuser"

  # Written by cloud-init on the first boot of every instance, a reimaged one included.
  files = {
    "/etc/modules-load.d/network-appliance.conf" = {
      permissions = "0644"
      content     = "nf_conntrack\n"
    }
    "/etc/sysctl.d/90-network-appliance.conf" = {
      permissions = "0644"
      content     = file("${path.module}/files/sysctl.conf")
    }
    "/etc/nftables.conf" = {
      permissions = "0644"
      content = templatefile("${path.module}/files/nftables.conf.tftpl", {
        ingress_ports     = var.ingress_ports
        ingress_target_ip = var.ingress_target_ip
      })
    }
    "/usr/local/bin/network-appliance-health" = {
      permissions = "0755"
      content     = file("${path.module}/files/network-appliance-health.py")
    }
    "/usr/local/bin/network-appliance-drain" = {
      permissions = "0755"
      content     = file("${path.module}/files/network-appliance-drain.sh")
    }
    "/usr/local/bin/network-appliance-scheduled-events" = {
      permissions = "0755"
      content     = file("${path.module}/files/network-appliance-scheduled-events.py")
    }
    "/etc/systemd/system/network-appliance-health.service" = {
      permissions = "0644"
      content     = templatefile("${path.module}/files/network-appliance-health.service.tftpl", { port = local.health_port })
    }
    "/etc/systemd/system/network-appliance-scheduled-events.service" = {
      permissions = "0644"
      content     = templatefile("${path.module}/files/network-appliance-scheduled-events.service.tftpl", { grace_seconds = local.drain_grace_seconds })
    }
    "/etc/systemd/system/network-appliance-drain-on-shutdown.service" = {
      permissions = "0644"
      content     = file("${path.module}/files/network-appliance-drain-on-shutdown.service")
    }
  }

  cloud_config = {
    write_files = [for path, file in local.files : {
      path        = path
      permissions = file.permissions
      encoding    = "b64"
      content     = base64encode(file.content)
    }]
    runcmd = [
      ["systemctl", "disable", "--now", "ssh.socket", "ssh.service"],
      ["systemctl", "restart", "systemd-modules-load.service"],
      ["sysctl", "--system"],
      ["systemctl", "daemon-reload"],
      ["systemctl", "enable", "--now", "nftables.service"],
      [
        "systemctl", "enable", "--now",
        "network-appliance-health.service",
        "network-appliance-scheduled-events.service",
        "network-appliance-drain-on-shutdown.service",
      ],
    ]
  }
}

# Uniform orchestration: automatic OS image upgrades are GA only there.
resource "azurerm_linux_virtual_machine_scale_set" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.region
  sku                 = var.vm_size
  instances           = var.instance_count
  zones               = var.availability_zones
  # Extra instances during creation would take SNAT ports that the outbound rule doesn't have.
  overprovision = false

  admin_username = local.admin_username
  admin_ssh_key {
    username   = local.admin_username
    public_key = tls_private_key.admin.public_key_openssh
  }
  disable_password_authentication = true

  custom_data = base64encode("#cloud-config\n${yamlencode(local.cloud_config)}")

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = local.arm64 ? "server-arm64" : "server"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  network_interface {
    name                  = "nic"
    primary               = true
    ip_forwarding_enabled = true

    ip_configuration {
      name      = "ipconfig"
      primary   = true
      subnet_id = azurerm_subnet.this.id
      load_balancer_backend_address_pool_ids = [
        azurerm_lb_backend_address_pool.internal.id,
        azurerm_lb_backend_address_pool.public.id,
      ]
    }
  }

  boot_diagnostics {}

  # Rolling upgrades replace one instance at a time: a surge instance is created first, then the old
  # one is deleted. A deletion raises the Terminate event that the instance drains on.
  upgrade_mode    = "Rolling"
  health_probe_id = azurerm_lb_probe.internal.id

  rolling_upgrade_policy {
    max_batch_instance_percent              = 50
    max_unhealthy_instance_percent          = 50
    max_unhealthy_upgraded_instance_percent = 50
    pause_time_between_batches              = "PT2M"
    maximum_surge_instances_enabled         = true
  }

  automatic_os_upgrade_policy {
    automatic_os_upgrade_enabled = true
    automatic_rollback_enabled   = true
  }

  # A draining instance fails its probe for drain_grace_seconds, well within the grace period.
  automatic_instance_repair {
    enabled      = true
    grace_period = "PT10M"
    action       = "Replace"
  }

  termination_notification {
    enabled = true
    timeout = "PT5M"
  }

  tags = var.tags

  # When the recipe switches to another appliance, Terraform destroys this one only after the route
  # points at the new one. Terraform extends it to every resource the scale set depends on, which is
  # the whole module.
  lifecycle {
    create_before_destroy = true
  }

  # A scale set may use a probe only once a load-balancing rule references it.
  depends_on = [
    azurerm_lb_rule.egress,
    azurerm_lb_rule.ingress,
    azurerm_lb_outbound_rule.egress,
    azurerm_subnet_network_security_group_association.this,
  ]
}
