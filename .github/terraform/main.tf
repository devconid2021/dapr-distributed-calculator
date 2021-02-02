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
    host                   = azurerm_kubernetes_cluster.daprdc.kube_config[0].host
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
  name                = var.aks_name
  location            = azurerm_resource_group.daprdc.location
  resource_group_name = azurerm_resource_group.daprdc.name
  dns_prefix          = format("%s-dns", var.aks_name)

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

resource "azurerm_redis_cache" "daprdc" {
  name                = var.arc_name
  location            = azurerm_resource_group.daprdc.location
  resource_group_name = azurerm_resource_group.daprdc.name
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"
  enable_non_ssl_port = true
}

resource "azurerm_key_vault_secret" "archostname" {
  name         = "arc-hostname"
  value        = join(":", [azurerm_redis_cache.daprdc.hostname, azurerm_redis_cache.daprdc.port])
  key_vault_id = format("/subscriptions/%s/resourceGroups/%s/providers/Microsoft.KeyVault/vaults/%s", var.subscription_id, var.tfstaterg, var.akv_name)
}

resource "azurerm_key_vault_secret" "arckey" {
  name         = "arc-key"
  value        = azurerm_redis_cache.daprdc.primary_access_key
  key_vault_id = format("/subscriptions/%s/resourceGroups/%s/providers/Microsoft.KeyVault/vaults/%s", var.subscription_id, var.tfstaterg, var.akv_name)
}
