terraform {
  required_version = "> 0.12.0"

  backend "azurerm" {
  }
}

provider "azurerm" {
  version = ">=2.0.0"
  features {}
}

provider "helm" {
  version = "1.2.2"
  kubernetes {
    host = azurerm_kubernetes_cluster.daprdc.kube_config[0].host

    client_key             = base64decode(azurerm_kubernetes_cluster.daprdc.kube_config[0].client_key)
    client_certificate     = base64decode(azurerm_kubernetes_cluster.daprdc.kube_config[0].client_certificate)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.daprdc.kube_config[0].cluster_ca_certificate)
    load_config_file       = false
  }
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
    name            = "defaultpool"
    node_count      = 2
    vm_size         = "Standard_D2_v3"
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
    http_application_routing {
      enabled = true
    }
  }

  tags = {
    environment = "Demo"
  }
}

resource "helm_release" "dapr" {
    name             = "dapr"
    repository       = "https://dapr.github.io/helm-charts/"
    chart            = "dapr"
    version          = "v0.11.3"
    namespace        = "dapr-system"
    create_namespace = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.daprdc.kube_config_raw
}
