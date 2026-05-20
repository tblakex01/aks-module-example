terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.73"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"

  features {}
}
