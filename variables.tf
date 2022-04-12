variable "tf_state_storage_account_name" {
  type        = string
  description = "Storage account created by bootstrap to hold all Terraform state"
}

variable "tf_state_resource_group_name" {
  type        = string
  description = "Shared management resource group"
}

variable "azure_region" {
  type        = string
  description = "Region used for all resources"
}

variable "project_name" {
  type        = string
  description = "Project Name. It will be appended to all resources"
}

variable "default_tags" {
  type    = map(string)
  description = "Default tags to be applied"
  default = {
    "region" = "west europe"
    "environment" = "dev"
    "business-unit" = "It"
    "workload-name": "myproject"
    "owner-name": "me@mytechramblings.com"
    "technical-contact" : "me@mytechramblings.com"
    "scope" : "private"
    "active-period" : "24/7"
    "customer" : "Customer1"
    "priority" : "L2"
  } 
}

## Start Azure DevOps config block
variable "azdo_org_url" {
  type        = string
  description = "URL of the Azure DevOps org"
}

variable "azdo_project_name" {
  type        = string
  description = "Name of the project in above org"
}

variable "azdo_pat" {
  type        = string
  description = "Access token with rights in Azure DevOps to set up service connections"
}

## End Azure DevOps config block