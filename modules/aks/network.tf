# Optional network resources that can be created by the module
resource "azurerm_virtual_network" "aks" {
  count               = var.create_network_resources ? 1 : 0
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  for_each = var.create_network_resources ? var.subnet_config : {}

  name                 = each.value.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.aks[0].name
  address_prefixes     = each.value.address_prefixes
}

resource "azurerm_network_security_group" "aks" {
  count               = var.create_network_resources ? 1 : 0
  name                = "nsg-${var.vnet_name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowVnetInBound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerInBound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  dynamic "security_rule" {
    for_each = var.additional_security_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = lookup(security_rule.value, "source_port_range", "*")
      destination_port_range     = lookup(security_rule.value, "destination_port_range", "*")
      source_port_ranges         = lookup(security_rule.value, "source_port_ranges", null)
      destination_port_ranges    = lookup(security_rule.value, "destination_port_ranges", null)
      source_address_prefix      = lookup(security_rule.value, "source_address_prefix", null)
      destination_address_prefix = lookup(security_rule.value, "destination_address_prefix", null)
    }
  }

  security_rule {
    name                       = "DenyAllInBound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  for_each = var.create_network_resources ? var.subnet_config : {}

  subnet_id                 = azurerm_subnet.aks[each.key].id
  network_security_group_id = azurerm_network_security_group.aks[0].id
}

resource "azurerm_private_dns_zone" "aks" {
  count               = var.create_network_resources && var.private_cluster_enabled ? 1 : 0
  name                = "privatelink.${replace(lower(var.location), " ", "")}.azmk8s.io"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  count                 = var.create_network_resources && var.private_cluster_enabled ? 1 : 0
  name                  = "vnet-link-${var.cluster_name}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.aks[0].name
  virtual_network_id    = azurerm_virtual_network.aks[0].id
  registration_enabled  = false
  tags                  = var.tags
}

