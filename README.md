# How to bootstrap an Azure subscription and an Azure DevOps project to start deploying infrastructure as code (IaC) with Terraform.

This repository contains a script (``AzureBootstrapProcessForTerraform.ps1``) used to bootstrap an Azure subscription and an Azure DevOps project to start deploying infrastructure with Terraform.

# How it works

The script does the following steps:

- Creates a Resource Group and a Storage Account using the Azure Az Powershell Module.
- Inits Terraform using the Storage Account as backend.
- Imports those 2 resources into the Terraform state.
- Uses Terraform to create the rest of the resources.

We could create all the resources using only Powershell and without the need of Terraform, but using Terraform to create and update them is simpler, less error prone and easier to mantain.

**The execute the script you need to pass it a parameter named ``ProvisionBootStrapResources``.** 

_Example: ``./Initialize-AzureBootstrapProcessForTerraform.ps1 -ProvisionBootStrapResources $True``_

When the ``ProvisionBootStrapResources`` parameter is set to ``$True`` it will execute the entire script, which means:
- Creating the resource group and the storage account for the tf state using the Az module
- Executing the Terraform Init, Plan and Apply commands to create the rest of the resources.      

If this is the first time you run the script and want to create the all the resources from zero, set it to ``$True``.

When the ``ProvisionBootStrapResources`` parameter is set to ``$False`` it will skip the steps of creating the resource group and the storage account, it will only run the Terraform Init, Plan and Apply steps.   
If you have modified the ``main.tf`` file to add or update some existing resources set it to ``$False``.


# Configuration

Reusability is key, I don't want to modify the script every time I need to bootstrap a new subscription.

To avoid that, there is a ``config.env`` file that contains the script configuration.

You can change the values on this file to your liking, but you must **NOT** change the name of the variables within the ``config.env`` file or the script will break.


- ``tf_state_resource_group_name``: The name of the resource group.
- ``tf_state_storage_account_name``: The name of the storage account.
- ``tf_state_storage_account_container_name``: The name of the storage account container.
- ``project_name``: The name of the project. It will be added as a suffix in all the created resources.
- ``azure_region``: The azure region where all the resources will be created.
- ``azure_subscription_id``: The azure subscription ID.
- ``azure_tenant_id``: The azure tenant ID.
- ``azdo_org_url``: The URL of the Azure DevOps organization.
- ``azdo_project_name``: The name of the Azure DevOps project where the variable group will be created.
- ``azdo_pat``: An Azure DevOps PAT (Personal Access Token).


Example:
```bash
## Terraform State Variable
tf_state_resource_group_name=rg-bs-tf-myproject-dev
tf_state_storage_account_name=stbstfmyprojectdev
tf_state_storage_account_container_name=tfstate

## Project Name
project_name=myproject-dev

## Azure Variables
azure_region=westeurope
azure_subscription_id=c179c52f-af4d-4a1a-adbe-2a27d480c62d
azure_tenant_id=da0d66e4-f338-454c-b0e5-cbdbf4fc385f

## Azure DevOps Variables
azdo_org_url=https://dev.azure.com/cponsn
azdo_project_name=demos
azdo_pat=12p3j12p31290j213021asdpsdj
```

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

# Permissions

To run the script you'll need to have the following permissions:

- An ``Owner`` Role on the target Azure Subscription.
- An ``Application Administrator`` Role on Azure Active Directory.
- An ``Azure DevOps PAT`` (Personal Access Token) with a Full Access scope.


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


# Azure DevOps pipeline example

The ``/samples/azure-pipelines`` folder contains an example of how you can deploy infrastructure.