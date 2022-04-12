terraform {

  backend "azurerm" {
    key = "bootstrap.tfstate"
  }

  required_providers {

    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }

    azuredevops = {
      source = "microsoft/azuredevops"
      version = ">=0.2.0"
    }

    azuread = {
      source  = "azuread"
      version = ">=2.20.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuredevops" {
  org_service_url       = var.azdo_org_url
  personal_access_token = var.azdo_pat
}

provider "azuread"{
}

## Get the configuration of the AzureRM provider
data "azurerm_client_config" "current" {}


## Get the AzDo Team Project 
data "azuredevops_project" "project" {
  name = var.azdo_project_name
}

##########################################################################################
## Start Importing existing resources into tf
##########################################################################################

## Create resource group. Already exists created by azure-bootstrap-terraform-init.sh
resource "azurerm_resource_group" "tf_state_rg" {
  name     = var.tf_state_resource_group_name
  location = var.azure_region
  tags = var.default_tags
}

## Creates store account that hold Terraform shared state. Already exists created by azure-bootstrap-terraform-init.sh
resource "azurerm_storage_account" "tf_state_storage" {
  name                     = var.tf_state_storage_account_name
  resource_group_name      = azurerm_resource_group.tf_state_rg.name
  location                 = azurerm_resource_group.tf_state_rg.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "LRS"
  
  tags = merge( 
    var.default_tags,
    {
      "description" = "Storage Account that holds the Terraform state files."
    })
}

## Lock the storage account. It cannot be deleted because it is needed by Terraform.
resource "azurerm_management_lock" "lock_tf_storage_account" {
  name       = "lock-bs-tf-stacct-${var.project_name}"
  scope      = azurerm_storage_account.tf_state_storage.id
  lock_level = "CanNotDelete"
  notes      = "Locked because it's needed by Terraform"
}

##########################################################################################
## End Importing existing resources into tf
##########################################################################################

##########################################################################################
## Start Creating KeyVault to hold SP credentials
##########################################################################################

## KeyVault to hold SP creds
resource "azurerm_key_vault" "sp_creds_kv" {
  name                        = "kv-bs-tf-${var.project_name}"
  location                    = azurerm_resource_group.tf_state_rg.location
  resource_group_name         = azurerm_resource_group.tf_state_rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 15
  enable_rbac_authorization   = true
  purge_protection_enabled    = false
  tags                        = merge( 
    var.default_tags,
    {
      "description" = "KeyVault that holds the SP credentials for deploying infrastructure"
    })
}

## Lock the key vault. It cannot be deleted because it is needed by Azure DevOps.
resource "azurerm_management_lock" "lock_sp_kv" {
  name       = "lock-bs-tf-sp-creds-kv-${var.project_name}"
  scope      = azurerm_key_vault.sp_creds_kv.id
  lock_level = "CanNotDelete"
  notes      = "Locked because it's needed by Azure DevOps"
}

##########################################################################################
## End Creating KeyVault to hold SP credentials
##########################################################################################