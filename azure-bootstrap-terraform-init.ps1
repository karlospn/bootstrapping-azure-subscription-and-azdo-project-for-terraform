Param(
    [Parameter(Mandatory=$True)]
    [bool] $ProvisionBootstrapResources
)
function Set-ConfigVars
{
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $FileName
    )

    if (Test-Path -Path $FileName) 
    {
        $values = @{}

        Get-Content $FileName | Where-Object {$_.length -gt 0} | Where-Object {!$_.StartsWith("#")} | ForEach-Object {
            $var = $_.Split('=',2).Trim()
            $values[$var[0]] = $var[1]
        }

        return $values
    }
    else
    {
        Write-Error "Configuration file missing."
        exit 1
    }
}

function Connect-AzureSubscription
{
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $SubId,
        [Parameter(Mandatory=$true, Position=0)]
        [string] $TenantId
    )

    if (-not (Get-AzContext | Where-Object { $_.Subscription.Id -eq $SubId })) {
        Write-Verbose "Logging in to Azure Subscription..."
        Connect-AzAccount -SubscriptionId $SubId -TenantId $TenantId -ErrorAction Stop | Out-Null
    }

    Write-Host "Using Azure Subscription:" $(Get-AzContext).Subscription.Name -ForegroundColor Yellow
}

function New-ResourceGroup
{
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $RgName,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $Region
    )

    if( -not (Get-AzResourceGroup -Name $RgName -ErrorAction SilentlyContinue))
    {
        Write-Verbose "Resource Group $RgName doesn't exist. Creating..."
        New-AzResourceGroup -Name $RgName -Location $Region -ErrorAction Stop
    }
    else
    {
        Write-Verbose "Resource Group $RgName already exists."
    }
}

function New-StorageAccount
{
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $RgName,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $StAccName,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $ContainerName,
        [Parameter(Mandatory=$true, Position=3)]
        [string] $Region
    )

    if( -not (Get-AzStorageAccount -Name $StAccName -ResourceGroupName $RgName -ErrorAction SilentlyContinue))
    {
        Write-Verbose "Storage Account $StAccName doesn't exist. Creating..."
        $storageAccount = New-AzStorageAccount -ResourceGroupName $RgName -Name $StAccName -Location $Region -SkuName Standard_LRS -ErrorAction Stop
        New-AzStorageContainer -Name $StAccName -Permission Off -Context $storageAccount.Context -ErrorAction Stop
    }
    else
    {
        Write-Verbose "Storage Account $StAccName already exists."
        $storageAccount = Get-AzStorageAccount -Name $StAccName -ResourceGroupName $RgName -ErrorAction Stop
        If( -not (Get-AzStorageContainer -Name $StAccName -Context $storageAccount.Context -ErrorAction SilentlyContinue))
        {
            Write-Verbose "Storage Container $StAccName doesn't exist. Creating..."
            New-AzStorageContainer -Name $ContainerName -Permission Off -Context $storageAccount.Context -ErrorAction Stop
        }
        else
        {
            Write-Verbose "Storage Container $StAccName already exists."
        }
    }
}


function Set-EnvVarsAsTfVars
{
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [hashtable] $ConfigVars
    )

    $env:TF_VAR_tf_state_resource_group_name=$ConfigVars.tf_state_resource_group_name
    $env:TF_VAR_tf_state_storage_account_name=$ConfigVars.tf_state_storage_account_name
    $env:TF_VAR_tf_project_name=$ConfigVars.project_name
    $env:TF_VAR_tf_azure_region=$ConfigVars.azure_region
    $env:TF_VAR_azdo_org_url=$ConfigVars.azdo_org_url
    $env:TF_VAR_tf_azdo_project_name=$ConfigVars.azdo_project_name
    $env:TF_VAR_azdo_pat=$ConfigVars.azdo_pat
}

function Invoke-TerraformInit
{
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $RgName,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $StAccName,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $ContainerName
    )

    terraform init -input=false -backend=true -reconfigure `
        -backend-config="resource_group_name=$RgName" `
        -backend-config="storage_account_name=$StAccName" `
        -backend-config="container_name=$ContainerName"
}

function Import-TerraformState
{
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $SubId,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $RgName,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $StAccName
    )

    terraform import azurerm_resource_group.tf_state_rg "/subscriptions/$SubId/resourceGroups/$RgName"
    terraform import azurerm_storage_account.tf_state_storage "/subscriptions/$SubId/resourceGroups/$RgName/providers/Microsoft.Storage/storageAccounts/$StAccName"
}

function Invoke-TerraformPlan
{
    terraform plan
}

function Invoke-TerraformApply
{
    terraform apply -auto-approve
}

function main 
{
    $configVarsFileName = "config.env"

    $configValues = Set-ConfigVars -FileName $configVarsFileName
    
    Connect-AzureSubscription -SubId $configValues.azure_subscription_id `
                -TenantId $configValues.azure_tenant_id

    if ($ProvisionBootstrapResources -eq $true)
    {
        New-ResourceGroup -RgName $configValues.tf_state_resource_group_name `
                -Region $configValues.azure_region

        New-StorageAccount -RgName $configValues.tf_state_resource_group_name `
                -StAccName $configValues.tf_state_storage_account_name `
                -ContainerName $configValues.tf_state_storage_account_container_name `
                -Region $configValues.azure_region

        Invoke-TerraformInit -RgName $configVars.tf_state_resource_group_name `
                -StAccName $configVars.tf_state_storage_account_name `
                -ContainerName $configVars.tf_state_storage_account_container_name

        Import-TerraformState -SubId $configVars.azure_subscription_id `
                -RgName $configVars.tf_state_resource_group_name `
                -StAccName $configVars.tf_state_storage_account_name 
    }
    
    Set-EnvVarsAsTfVars -ConfigVars $configVars
    
    Invoke-TerraformInit -RgName $configVars.tf_state_resource_group_name `
                -StAccName $configVars.tf_state_storage_account_name `
                -ContainerName $configVars.tf_state_storage_account_container_name
    
    Invoke-TerraformPlan
    Read-Host -Prompt "Press any key to run terraform apply or CTRL+C to quit" 
    
    Invoke-TerraformApply
}

main
