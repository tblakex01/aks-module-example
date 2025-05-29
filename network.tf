resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "aks" {
  name                = local.vnet_name
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = local.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "system" {
  name                 = local.subnets.system.name
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = local.subnets.system.address_prefixes
}

resource "azurerm_subnet" "spark" {
  name                 = local.subnets.spark.name
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = local.subnets.spark.address_prefixes
}

resource "azurerm_subnet" "endpoints" {
  name                 = local.subnets.endpoints.name
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = local.subnets.endpoints.address_prefixes
}

resource "azurerm_subnet_network_security_group_association" "system" {
  subnet_id                 = azurerm_subnet.system.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "spark" {
  subnet_id                 = azurerm_subnet.spark.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "endpoints" {
  subnet_id                 = azurerm_subnet.endpoints.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.${replace(lower(var.location), " ", "")}.azmk8s.io"
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  name                  = "vnet-link-spoke"
  resource_group_name   = azurerm_resource_group.aks.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = azurerm_virtual_network.aks.id
  registration_enabled  = false
  tags                  = var.tags
}

# Link private DNS zone to hub VNet for access from on-premises
resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  count                 = var.enable_hub_peering ? 1 : 0
  name                  = "vnet-link-hub"
  resource_group_name   = azurerm_resource_group.aks.name
  private_dns_zone_name = azurerm_private_dns_zone.aks.name
  virtual_network_id    = data.azurerm_virtual_network.hub[0].id
  registration_enabled  = false
  tags                  = var.tags
}