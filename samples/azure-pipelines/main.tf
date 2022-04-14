## Create Resource Group for external services
resource "azurerm_resource_group" "rg-shared-svc" {
    name      = "rg-shared-${var.project_name}-${var.environment}"
    location  = var.location
    tags      = var.default_tags
}

## For this example of an IaC pipeline I'm creating a single resource.