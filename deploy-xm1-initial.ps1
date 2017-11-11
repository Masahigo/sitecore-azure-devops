#
# Deploy Sitecore 8.2u5 xM1 infrastructure components on ASP - leverage original ARM as shared on
# https://github.com/Sitecore/Sitecore-Azure-Quickstart-Templates/tree/master/Sitecore%208.2.3
#

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
  [string]$SubscriptionName,
  
  [Parameter(Mandatory=$True)]
  [string]$RGName,
  
  [Parameter(Mandatory=$True)]
  [string]$Location,

  [Parameter(Mandatory=$True)]
  [string]$ResourcePrefix,

  [Parameter(Mandatory=$True)]
  [string]$SitecorePwd,

  [Parameter(Mandatory=$True)]
  [string]$SqlServerLogin,

  [Parameter(Mandatory=$True)]
  [string]$SqlServerPwd,

  [Parameter(Mandatory=$True)]
  [string]$StorageAccountNameDeploy,

  [Parameter(Mandatory=$False)]
  [string]$KeyVaultAdminMailAddressOrObjectId, #if e-mail address supplied we assume get by ADUser, use ID supplied

  [Parameter(Mandatory=$False)]
  [string]$PathToSitecoreLicenseFile = "$(Split-Path $MyInvocation.MyCommand.Path)\license.xml",

  [Parameter(Mandatory=$False)]
  [string]$ArtifactsRootDir, #optional for running locally, required for used by VSTS to pass current artifacts root dir

  [Parameter(Mandatory=$false)]
  [switch]$LeaveTempFilesOnDisk
)

$ErrorActionPreference = "Stop"

# Check if given license file exists
if ( ! (test-path -pathtype leaf $PathToSitecoreLicenseFile)) {
  throw "LICENSE FILE DOES NOT EXIST - PLEASE SPECIFY VALID LICENSE FILE"
}

# If the KeyVaultAdminMailAddressOrObjectId is an e-mailaddress

if($KeyVaultAdminMailAddressOrObjectId)
{
  if ($KeyVaultAdminMailAddressOrObjectId -match ".+\@.+\..+"){
    $KeyVaultUserId = (Get-AzureRmADUser -Mail "$KeyVaultAdminMailAddressOrObjectId" | Select -Expand Id).ToString()
    Write-Host "Keyvault Admin User ID selected via e-mail: $KeyVaultUserId"
  }else{
    #we assume it's an ServicePrincipal ObjectId or a User ObjectId - Application ID will not work
    Write-Host "KeyVaultAdminMailAddressOrObjectId passed in argument as ID"
    $KeyVaultUserId = $KeyVaultAdminMailAddressOrObjectId
  }
}
else{
   $account = $(Get-AzureRmContext).Account
   Write-Host "Account type: $account"
   if($account.AccountType -eq "User"){
      $KeyVaultUserId = $(Get-AzureRmADUser -UserPrincipalName $account.Id).Id
      Write-Host "Using the Keyvault ObjectId gotten via current user context: $KeyVaultUserId"
   }else{
      throw "Current context is probably a Service Principal. Are you running this in VSTS? Please supply the VSTS Service principal ObjectId through argument -KeyVaultAdminMailAddressOrObjectId"
   }
}


#when running local code, use relative path to script, if on VSTS, the artifacts dir is different
if ($ArtifactsRootDir){
  $scriptDir = $ArtifactsRootDir
}else{
  $scriptDir = Split-Path $MyInvocation.MyCommand.Path
}
 


Select-AzureRmSubscription -SubscriptionName $SubscriptionName
Write-Host "Selected subscription: $SubscriptionName"

# Find existing or deploy new Resource Group:
$rg = Get-AzureRmResourceGroup -Name $RGName -ErrorAction SilentlyContinue
if (-not $rg)
{
    New-AzureRmResourceGroup -Name "$RGName" -Location "$Location"
    Write-Host "New resource group deployed: $RGName"   
}
else{ Write-Host "Resource group found: $RGName"}



#============================
# Create a new container, upload the Webdeploy Sitecore packages and save the new URLs to variables

# Create Storage Account if not exists yet
$storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $RGName -Name $StorageAccountNameDeploy -ErrorAction SilentlyContinue
if(!$storageAccount)
{
  $storageAccount = New-AzureRmStorageAccount -ResourceGroupName $RGName -Name $StorageAccountNameDeploy -Location $Location -SkuName "Standard_LRS"
  Write-Host "New storage account created: $StorageAccountNameDeploy"
}
else{ Write-Host "Storage account found: $StorageAccountNameDeploy"}

$ctx = $storageAccount.Context

# Create container to upload packages towards
$packagesContainerName = "tempsitecore825packages"
$packagesContainer = New-AzureStorageContainer -Name $packagesContainerName -Permission Off -Context $ctx -ErrorAction SilentlyContinue

# Upload XM1 package to container, so it is available for ARM deployment
$cmBlobName = "Sitecore 8.2 rev. 170728_cm.scwdp.zip"
$localFile = "$scriptDir\packages\xM1\" + $cmBlobName
Set-AzureStorageBlobContent -Container $packagesContainerName -File $localFile -Blob $cmBlobName -Context $ctx -Force

$cdBlobName = "Sitecore 8.2 rev. 170728_cd.scwdp.zip"
$localCdFile = "$scriptDir\packages\xM1\" + $cdBlobName
Set-AzureStorageBlobContent -Container $packagesContainerName -File $localCdFile -Blob $cdBlobName -Context $ctx -Force

# Create SAS token for the packages container
$packagesContainerSas = New-AzureStorageContainerSASToken -Context $ctx -Name $packagesContainerName -Permission r -ExpiryTime (Get-Date).AddHours(4)

Write-Host "Sas for packages: $packagesContainerSas"

$cmWebdeployPackageUri = (Get-AzureStorageBlob -Blob $cmBlobName -Container $packagesContainerName -Context $ctx).ICloudBlob.Uri.AbsoluteUri + $packagesContainerSas
$cdWebdeployPackageUri = (Get-AzureStorageBlob -Blob $cdBlobName -Container $packagesContainerName -Context $ctx).ICloudBlob.Uri.AbsoluteUri + $packagesContainerSas

Write-Output "Blob URL and SAS - $cdWebdeployPackageUri"

# Create container to upload templates towards
$templatesContainerName = "tempsitecore825templates"
$templatesContainerUri = "https://$StorageAccountNameDeploy.blob.core.windows.net/$templatesContainerName/"

# Upload main template:
& "$scriptDir\copyFilesToAzureStorageContainer.ps1" -LocalPath "$scriptDir\templates\xm\" `
                                   -StorageContainer $templatesContainerName -StorageContext $ctx -CreateStorageContainer  -Recurse -Force

# Create SAS token for the packages container
$templatesContainerSas = New-AzureStorageContainerSASToken -Context $ctx -Name $templatesContainerName -Permission r -ExpiryTime (Get-Date).AddHours(4)

Write-Host "Sas for templates: $templatesContainerSas"

$rootTemplateUri = (Get-AzureStorageBlob -Blob "azuredeploy.json" -Container $templatesContainerName -Context $ctx).ICloudBlob.Uri.AbsoluteUri

Write-Output "Root template SAS - $rootTemplateUri"

# Get content from license file:
$licenseFileContent = Get-Content -Raw -Encoding UTF8 -Path "$PathToSitecoreLicenseFile" | Out-String;

# Set locations to two custom Sitecore addons: keyvault and slots
$keyvaultModuleUriWithSas = (Get-AzureStorageBlob -Blob "addons/keyvault.json" -Container $templatesContainerName -Context $ctx).ICloudBlob.Uri.AbsoluteUri + $templatesContainerSas

$slotsModuleUriWithSas = (Get-AzureStorageBlob -Blob "addons/slots.json" -Container $templatesContainerName -Context $ctx).ICloudBlob.Uri.AbsoluteUri + $templatesContainerSas

# Generate the parameters Json file dynamically, on the fly
$paramsFile = @{
    '$schema' = "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
        deploymentId = @{
           value = "$ResourcePrefix"
        }
        'sitecoreAdminPassword' =  @{
            value = "$SitecorePwd"
            }
       'sqlServerLogin' =  @{
            value = "$SqlServerLogin"
        }
        'sqlServerPassword' =  @{
          value ="$SqlServerPwd"
        }
        'cmMsDeployPackageUrl' =  @{
          value = "$cmWebdeployPackageUri"
        }
        'cdMsDeployPackageUrl' =  @{
          value = "$cdWebdeployPackageUri"
        }
        'applicationInsightsLocation' = @{
          value = "West Europe"
        }    
        'templateLinkBase' = @{
          value = $templatesContainerUri
        }
        'templateLinkAccessToken' = @{
          value = $templatesContainerSas
        }   
        'licenseXml' =  @{
          value = "$licenseFileContent"
        } 
        modules = @{
          value = @{
            items = @(
              @{
                name = "keyvault"
                templateLink = $keyvaultModuleUriWithSas
                parameters = @{
                              userIdforKeyvault = "$KeyVaultUserId"
                              keyvaultSku = "Standard"
                              }
                }
              @{
                name = "slots"
                templateLink = $slotsModuleUriWithSas
                parameters = @{}
              }
            )
          }
        }
    }       
}
  
$paramsFilePath = "$scriptDir\xm-asp-sitecore.parameters.tmp.json"
Write-Host "Temp params file to be written to: $paramsFilePath"
$paramsFile | ConvertTo-Json -Depth 10 | Out-File $paramsFilePath

#============================
# Deploy ARM template
New-AzureRmResourceGroupDeployment -Verbose -Force -ErrorAction Stop `
   -Name "sitecore" `
   -ResourceGroupName $RGName `
   -TemplateFile "$scriptDir/templates/xm/azuredeploy.json" `
   -TemplateParameterFile $paramsFilePath 

# Clean up temporary params file:
if($LeaveTempFilesOnDisk -eq $false) {
  Remove-Item -Path $paramsFilePath
}
