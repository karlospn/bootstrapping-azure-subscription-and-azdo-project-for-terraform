# How to bootstrap an Azure subscription and an Azure DevOps project to start deploying infrastructure as code (IaC) with Terraform.

This repository contains a script (AzureBootstrapProcessForTerraform.ps1) used to bootstrap an Azure subscription and an Azure DevOps project to start deploying infrastructure with Terraform.

# How it works


# How to run the script


# Where to run the script

To run the script on your **local machine** you'll need to have already installed:
-  Terraform 
-  Azure Powershell Az Module. 
   -  For more information go to: https://docs.microsoft.com/es-es/powershell/azure/what-is-azure-powershell?view=azps-7.4.0


You can also run the script on **Azure Cloud Shell**. In that case, you'll need to upload the following files:

- ``Initialize-AzureBootstrapProcessForTerraform.ps1``
- ``config.env``
- ``main.tf``
- ``variables.tf``

And afterwards, just execute the ``Initialize-AzureBootstrapProcessForTerraform.ps1`` script.

# Resources it creates
- A Resource Group.
- An Storage Account to hold the Terraform State.
- A Service Principal that will be used by Azure DevOps to deploy the infrastructure onto Azure. This SP will use a custom role.
- A custom role. 
  - This custom role has the same permissions as ``Contributor`` but can create role assigmnemts. It also have permissions to read, write and delete data on Azure Key Vault and App Configuration.
- A Key Vault to hold the credentials of the Service Principal.
  - The script by itself adds the SP credentials into the KV, you don't need to do anything.
- An Azure DevOps variable group that holds the credentials of the Service Principal.
  - The script links the Azure Key Vault we have created with this variable group and map the SP credentials to the variable group, but to do that we will need another Service Principal.
- A secondary Service Principal with a ``Key Vault Administrator`` role associated at the resource group scope.