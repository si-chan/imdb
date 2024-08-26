# Configure the required providers
terraform {
  required_version = ">= 1.1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}

# Configure features for the azurerm provider
provider "azurerm" {
  features {}
}
  
# Azure naming module to create unique names for resources
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4.1"
  suffix  = [var.suffix]
}

# Current date
resource "time_rotating" "t" {
  rotation_days = 1
}

locals {
  current_date = "${formatdate("YYYY-MM-DD",time_rotating.t.rfc3339)}"
}

# Default resource group
resource "azurerm_resource_group" "imdb_rg" {
  name     = module.naming.resource_group.name
  location = var.azure_region
}

# Storage account
resource "azurerm_storage_account" "imdb_sa" {
  name                            = module.naming.storage_account.name
  resource_group_name             = azurerm_resource_group.imdb_rg.name
  location                        = var.azure_region
  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  access_tier                     = "Hot"
  https_traffic_only_enabled      = "true"
  shared_access_key_enabled       = "true"
  allow_nested_items_to_be_public = "false" # This is the "anonymous read access" property (badly named!)
}

# Storage Container
resource "azurerm_storage_container" "imdb_sac" {
  name                  = module.naming.storage_container.name
  storage_account_name  = azurerm_storage_account.imdb_sa.name
  container_access_type = "private"
  metadata = {
    sourcedate = local.current_date
  }
}

# Upload initial blobs
# The blob will only get refreshed if the time_rotating provider has updated the timestamp, which occurs every X days
resource "azurerm_storage_blob" "imdb_blob" {
  for_each = toset(local.imdb_data_files)
  name                   = each.key
  storage_account_name   = azurerm_storage_account.imdb_sa.name
  storage_container_name = azurerm_storage_container.imdb_sac.name
  type                   = "Block"
  source_uri             = "${var.imdb_uri_base}${each.key}"
  metadata               = {
    sourcedate = local.current_date
  }
  timeouts {
    create = "5m"
  }
  lifecycle {
    replace_triggered_by = [
      azurerm_storage_container.imdb_sac.metadata["sourcedate"]
    ]
  }
}

# Automation account
resource "azurerm_automation_account" "imdb_aa" {
  name                          = module.naming.automation_account.name
  location                      = var.azure_region
  resource_group_name           = azurerm_resource_group.imdb_rg.name
  sku_name                      = "Basic"
  public_network_access_enabled = "false"
  identity {
    type = "SystemAssigned"
  }
}

# Runbook Schedule
#resource "azurerm_automation_schedule" "aa_sched" {
#}

# Python3 dependencies for Runbook
resource "azurerm_automation_python3_package" "aa_py_azure_storage_blob" {
  resource_group_name     = azurerm_resource_group.imdb_rg.name
  automation_account_name = azurerm_automation_account.imdb_aa.name
  name                    = "aa_py_azure_storage_blob"
  content_uri             = "https://files.pythonhosted.org/packages/a8/52/b578c94048469fbf9f6378e2b2a46a2d0ccba3d59a7845dbed22ebf61601/azure_storage_blob-12.22.0-py3-none-any.whl"
}

resource "azurerm_automation_python3_package" "aa_py_azure_identity" {
  resource_group_name     = azurerm_resource_group.imdb_rg.name
  automation_account_name = azurerm_automation_account.imdb_aa.name
  name                    = "aa_py_azure_identity"
  content_uri             = "https://files.pythonhosted.org/packages/49/83/a777861351e7b99e7c84ff3b36bab35e87b6e5d36e50b6905e148c696515/azure_identity-1.17.1-py3-none-any.whl"
}

resource "azurerm_automation_python3_package" "aa_py_azure_core" {
  resource_group_name     = azurerm_resource_group.imdb_rg.name
  automation_account_name = azurerm_automation_account.imdb_aa.name
  name                    = "aa_py_azure_core"
  content_uri             = "https://files.pythonhosted.org/packages/ef/d7/69d53f37733f8cb844862781767aef432ff3152bc9b9864dc98c7e286ce9/azure_core-1.30.2-py3-none-any.whl"
}


# Runbook
resource "azurerm_automation_runbook" "aa_runbook" {
  name                    = module.naming.automation_runbook.name
  location                = var.azure_region
  resource_group_name     = azurerm_resource_group.imdb_rg.name
  automation_account_name = azurerm_automation_account.imdb_aa.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Runbook for IMDb data download"
  runbook_type            = "Python3"
  publish_content_link {
    uri = "https://github.com/si-chan/imdb/raw/main/python/IMDb_downloader.py"
    # hash {
    #   algorithm = "SHA256"
    #   value = "062A7ADE39E0AEBCD67602DD042E5C5D47B3504F3938BE2F0313ACB3C5FE9DE5"
    # }
  }
}





