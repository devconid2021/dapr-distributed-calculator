terraform {
  required_version = "> 0.12.0"

  backend "azurerm" {
  }
}

provider "azurerm" {
  version = ">=2.0.0"
  features {}
}

resource "azurerm_resource_group" "daprdc" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_kubernetes_cluster" "daprdc" {
  name                = format("aks-%s", var.aks_name)
  location            = azurerm_resource_group.daprdc.location
  resource_group_name = azurerm_resource_group.daprdc.name
  dns_prefix          = format("aks-%s-dns", var.aks_name)

  default_node_pool {
    name            = format("aks-%s-default-pool", var.aks_name)
    node_count      = 2
    vm_size         = "Standard_D2_v2"
    os_disk_size_gb = 30
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  role_based_access_control {
    enabled = true
  }

  addon_profile {
    kube_dashboard {
      enabled = true
    }
  }

  tags = {
    environment = "Demo"
  }
}
