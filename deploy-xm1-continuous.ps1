#
# Deploys a Sitecore ms deploy (web deploy) package to Sitecore 8.2u3 CD and CM slots
# Makes assumptions that both the keyvault and slots addon where configured and deployed
# Most information is inferred automatically from keyvault and deployment output params
# These should have been provisioned by "./deploy-xm-initial.ps1"
# Eventually this script calls into the more generic version "deploy-xm1-continuous-generic.ps1"
#

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
  [string]$SubscriptionName,
  
  [Parameter(Mandatory=$True)]
  [string]$RGName,
  
  [Parameter(Mandatory=$True)]
  [string]$PackageLocation,

  [Parameter(Mandatory=$True)]
  [string]$ParamsFileLocation,

  [Parameter(Mandatory=$False)]
  [string]$ArtifactsRootDir,

  [Parameter(Mandatory=$False)]
  [string]$TempFolderName, #needed in the generic script to save the publish profile to 

  [Parameter(Mandatory=$True)]
  [ValidateSet('CM','CD')]
  [string]$Role,

  [Parameter(Mandatory=$false)]
  [switch]$DoNotDeleteExistingFiles = $false,

  [Parameter(Mandatory=$false)]
  [switch]$SkipDbOperations = $false
)

$ErrorActionPreference = "Stop"

#when running local code, use relative path to script, if on VSTS, the artifacts dir is different
if ($ArtifactsRootDir){
  $scriptDir = $ArtifactsRootDir
}else{
  $scriptDir = Split-Path $MyInvocation.MyCommand.Path
}
 
# Select Subscription:
Get-AzureRmSubscription -SubscriptionName "$SubscriptionName" | Select-AzureRmSubscription
Write-Output "Selected Azure Subscription"

# Find existing Resource Group:
$rg = Get-AzureRmResourceGroup -Name $RGName -ErrorAction Stop

# Get output params from both addons: keyvault and slots:
$keyvaultOutParams = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName -Name "sitecore-keyvault").Outputs
$slotsOutParams = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName -Name "sitecore-slots").Outputs

$WebAppName = $null
$SlotName = $null

# Fetch web site and slot
if($Role -eq "CM") {
  $WebAppName = $keyvaultOutParams.cmWebAppNameTidy.Value
  $SlotName = $slotsOutParams.cmSlotName.Value
}
if($Role -eq "CD") { 
  $WebAppName = $keyvaultOutParams.cdWebAppNameTidy.Value
  $SlotName = $slotsOutParams.cdSlotName.Value
}

# Select Subscription:
Get-AzureRmSubscription -SubscriptionName "$SubscriptionName" | Select-AzureRmSubscription
Write-Output "Selected Azure Subscription"

if($DoNotDeleteExistingFiles){
    & "$scriptDir\deploy-xm1-continuous-generic.ps1" -SubscriptionName $SubscriptionName -RGName $RGName -PackageLocation $PackageLocation -ParamsFileLocation $ParamsFileLocation -WebAppName $WebAppName -SlotName $SlotName -TempFolderName "$TempFolderName"  -DoNotDeleteExistingFiles -SkipDbOperations:$SkipDbOperations
}
else{
    & "$scriptDir\deploy-xm1-continuous-generic.ps1" -SubscriptionName $SubscriptionName -RGName $RGName -PackageLocation $PackageLocation -ParamsFileLocation $ParamsFileLocation -WebAppName $WebAppName -SlotName $SlotName -TempFolderName "$TempFolderName" -SkipDbOperations:$SkipDbOperations
}
