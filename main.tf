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

## Lock the key vault. It cannot be deleted because it is needed by Azure DevOps
resource "azurerm_management_lock" "lock_sp_kv" {
  name       = "lock-bs-tf-kv-${var.project_name}"
  scope      = azurerm_key_vault.sp_creds_kv.id
  lock_level = "CanNotDelete"
  notes      = "Locked because it's needed by Azure DevOps"
}

## Add myself as a KV Admin role. This assignment is required to later add the IaC SP credentials into the KV
resource "azurerm_role_assignment" "me_keyvault_role" {
  scope                            = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.tf_state_rg.name}"
  role_definition_name             = "Key Vault Administrator"
  principal_id                     = data.azurerm_client_config.current.object_id
}

##########################################################################################
## End Creating KeyVault to hold SP credentials
##########################################################################################

#########################################################################################
## Start creating SP to be used by Azure DevOps variable group  to access the Key Vault
##########################################################################################

## Create an AAD application, it's needed to create a SP
resource "azuread_application" "azdo_keyvault_app" {
  display_name = "app-bs-tf-azdo-vargroup-kv-connection-${var.project_name}"
}

## Create an AAD Service Principal
resource "azuread_service_principal" "azdo_keyvault_sp" {
  application_id = azuread_application.azdo_keyvault_app.application_id
}

## Creates a password for the AAD app
resource "azuread_application_password" "azdo_keyvault_sp_password" {
  application_object_id = azuread_application.azdo_keyvault_app.id
  display_name          = "TF generated password" 
  end_date              = "2040-01-01T00:00:00Z"
}

## Assign a KV Admin role to the SP. The role is assigned at resource group scope
resource "azurerm_role_assignment" "azdo_keyvault_role" {
  scope                            = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.tf_state_rg.name}"
  role_definition_name             = "Key Vault Administrator"
  principal_id                     = azuread_service_principal.azdo_keyvault_sp.id
  skip_service_principal_aad_check = true
}

## Create a Azure DevOps Service Endpoint to access to KV
resource "azuredevops_serviceendpoint_azurerm" "keyvault_access" {
  project_id            = data.azuredevops_project.project.id
  service_endpoint_name = "service-endpoint-bs-tf-azdo-vargroup-kv-connection-${var.project_name}"
  credentials {
    serviceprincipalid  = azuread_application.azdo_keyvault_app.application_id
    serviceprincipalkey = azuread_application_password.azdo_keyvault_sp_password.value
  }
  azurerm_spn_tenantid      = data.azurerm_client_config.current.tenant_id
  azurerm_subscription_id   = data.azurerm_client_config.current.subscription_id
  azurerm_subscription_name = "Management Subscription"
}
##########################################################################################
## End creating SP to be used by Azure DevOps variable group  to access the Key Vault
##########################################################################################

##########################################################################################
## Start creating SP to be used by AzDo Pipelines to deploy infrastructure to Azure
##########################################################################################

## Create an AAD application, it's needed to create a SP
resource "azuread_application" "iac_app" {
  display_name = "app-bs-tf-deploy-iac-azdo-pipelines-${var.project_name}"
}

## Create an AAD Service Principal
resource "azuread_service_principal" "iac_sp" {
  application_id = azuread_application.iac_app.application_id
}

## Creates a random password for the AAD app
resource "azuread_application_password" "iac_sp_password" {
  application_object_id = azuread_application.iac_app.id
  display_name          = "TF generated password"   
  end_date              = "2040-01-01T00:00:00Z"
}

# Create a custom role for this SP
resource "azurerm_role_definition" "iac_custom_role" {
  name        = "role-iac-deploy-${var.project_name}"
  scope       = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  description = "This is a custom role created via Terraform. It has the same permissions as Contributor but can create role assigmnemts. It also have permissions to read, write and delete data on  Azure Key Vault and App Configuration."
  permissions {
    actions     = ["*"]
    not_actions = [
      "Microsoft.Authorization/elevateAccess/Action",
      "Microsoft.Blueprint/blueprintAssignments/write",
      "Microsoft.Blueprint/blueprintAssignments/delete",
      "Microsoft.Compute/galleries/share/action"
    ]
    data_actions = [ 
      "Microsoft.KeyVault/vaults/*",
      "Microsoft.AppConfiguration/configurationStores/*/read",
      "Microsoft.AppConfiguration/configurationStores/*/write",
      "Microsoft.AppConfiguration/configurationStores/*/delete"
    ]
    not_data_actions = []
  }
  assignable_scopes = [
    "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  ]
}

## Assign the custom role to the SP. The role is assigned at subscription scope.
resource "azurerm_role_assignment" "iac_role_assignment" {
  scope                            = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name             = "role-iac-deploy-${var.project_name}"
  principal_id                     = azuread_service_principal.iac_sp.id
  skip_service_principal_aad_check = true
  depends_on = [
    azurerm_role_definition.iac_custom_role
  ]
}

## Store SP client secret in the KV
resource "azurerm_key_vault_secret" "iac_sp_secret" {
  name         = "sp-tf-bs-iac-client-secret"
  value        = azuread_application_password.iac_sp_password.value
  key_vault_id = azurerm_key_vault.sp_creds_kv.id
  tags = var.default_tags
}

## Store SP client secret in the KV
resource "azurerm_key_vault_secret" "iac_sp_clientid" {
  name         = "sp-tf-bs-iac-client-id"
  value        = azuread_service_principal.iac_sp.application_id
  key_vault_id = azurerm_key_vault.sp_creds_kv.id
  tags = var.default_tags
}

## Store SP client secret in the KV
resource "azurerm_key_vault_secret" "iac_sp_tenant" {
  name         = "sp-tf-bs-iac-tenant-id"
  value        = data.azurerm_client_config.current.tenant_id
  key_vault_id = azurerm_key_vault.sp_creds_kv.id
  tags = var.default_tags
}

## Store SP client secret in the KV
resource "azurerm_key_vault_secret" "iac_sp_subid" {
  name         = "sp-tf-bs-iac-subscription-id"
  value        = data.azurerm_client_config.current.subscription_id
  key_vault_id = azurerm_key_vault.sp_creds_kv.id
  tags = var.default_tags
}

##########################################################################################
## End creating SP to be used by AzDo Pipelines to deploy infrastructure to Azure
##########################################################################################

#########################################################################################
## Start creating Azure DevOps variable Group used for deploy IaC
##########################################################################################

## Create AZDO variable group with IaC SP credentials
resource "azuredevops_variable_group" "azdo_iac_var_group" {
  project_id   = data.azuredevops_project.project.id
  name         = "vargroup-bs-tf-iac-${var.project_name}"
  allow_access = true

  key_vault {
    name                = azurerm_key_vault.sp_creds_kv.name
    service_endpoint_id = azuredevops_serviceendpoint_azurerm.keyvault_access.id
  }

  variable {
    name = "sp-tf-bs-iac-client-id"
  }

  variable {
    name = "sp-tf-bs-iac-client-secret"
  }

  variable {
    name = "sp-tf-bs-iac-tenant-id"
  }

  variable {
    name = "sp-tf-bs-iac-subscription-id"
  }
}

##########################################################################################
## End creating Azure DevOps variable Group used for deploy IaC
##########################################################################################