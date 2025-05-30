# Optional monitoring resources that can be created by the module
resource "azurerm_log_analytics_workspace" "aks" {
  count               = var.create_monitoring_resources ? 1 : 0
  name                = "law-${var.cluster_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days

  tags = var.tags
}

resource "azurerm_log_analytics_solution" "aks" {
  count                 = var.create_monitoring_resources ? 1 : 0
  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.aks[0].id
  workspace_name        = azurerm_log_analytics_workspace.aks[0].name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = var.tags
}