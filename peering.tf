# VNet Peering Configuration for ExpressRoute Connectivity

# Data source to get hub VNet information
data "azurerm_virtual_network" "hub" {
  name                = local.hub_vnet_name
  resource_group_name = var.hub_resource_group_name
}

# Peering from Spoke to Hub
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-${local.vnet_name}-to-${local.hub_vnet_name}"
  resource_group_name       = azurerm_resource_group.aks.name
  virtual_network_name      = azurerm_virtual_network.aks.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true # Use ExpressRoute Gateway in hub

  depends_on = [
    azurerm_virtual_network.aks,
    azurerm_subnet.system,
    azurerm_subnet.spark,
    azurerm_subnet.endpoints
  ]
}

# Peering from Hub to Spoke (requires permissions on hub)
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-${local.hub_vnet_name}-to-${local.vnet_name}"
  resource_group_name       = var.hub_resource_group_name
  virtual_network_name      = local.hub_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.aks.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true # Allow spoke to use hub's gateway
  use_remote_gateways          = false
}

# Route Table for ExpressRoute Traffic
resource "azurerm_route_table" "aks_expressroute" {
  name                          = "rt-aks-expressroute"
  location                      = azurerm_resource_group.aks.location
  resource_group_name           = azurerm_resource_group.aks.name
  bgp_route_propagation_enabled = true # Allow BGP routes from ExpressRoute

  tags = var.tags
}

# Route for internal traffic to go through ExpressRoute
resource "azurerm_route" "to_onprem_aws" {
  name                = "route-to-onprem-aws"
  resource_group_name = azurerm_resource_group.aks.name
  route_table_name    = azurerm_route_table.aks_expressroute.name
  address_prefix      = "10.0.0.0/16" # All internal traffic
  next_hop_type       = "VirtualNetworkGateway"
}

# Associate route table with subnets
resource "azurerm_subnet_route_table_association" "system" {
  subnet_id      = azurerm_subnet.system.id
  route_table_id = azurerm_route_table.aks_expressroute.id
}

resource "azurerm_subnet_route_table_association" "spark" {
  subnet_id      = azurerm_subnet.spark.id
  route_table_id = azurerm_route_table.aks_expressroute.id
}

resource "azurerm_subnet_route_table_association" "endpoints" {
  subnet_id      = azurerm_subnet.endpoints.id
  route_table_id = azurerm_route_table.aks_expressroute.id
}