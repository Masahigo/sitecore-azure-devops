#
# Deploy Sitecore 8.2u5 xM1 infrastructure components on regular ASP - leverage original ARM as shared on
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

  [Parameter(Mandatory=$True)]
  [string]$KeyVaultAdminMailAddress, 

  [Parameter(Mandatory=$True)]
  [string]$PathToSolutionFile,

  [Parameter(Mandatory=$False)]
  [string]$PathToSitecoreLicenseFile = "$(Split-Path $MyInvocation.MyCommand.Path)\license.xml",

  [Parameter(Mandatory=$False)]
  [string]$TempDir = "C:\Temp"
)

$ErrorActionPreference = "Stop"

# 8.2u5 packages
$CMPackageLocation = "$(Split-Path $MyInvocation.MyCommand.Path)\packages\xM1\Sitecore 8.2 rev. 170407_cm.scwdp.zip"
$CDPackageLocation = "$(Split-Path $MyInvocation.MyCommand.Path)\packages\xM1\Sitecore 8.2 rev. 170407_cd.scwdp.zip"

# Warning about erasing contents of temp dir:
Write-Host "!! WARNING: this script will erase all contents from the following temp directory: $TempDir !!"
Write-Host " ... Press any key to approve and continue ..."
Read-Host

# Check if given license file exists
if ( ! (test-path -pathtype leaf $PathToSitecoreLicenseFile)) {
  throw "LICENSE FILE DOES NOT EXIST - PLEASE SPECIFY VALID LICENSE FILE"
}

Write-Host "Starting Deployment"

# First deploy sc82u3 infrastructure + OOB binaries
.\deploy-xm1-initial.ps1 -SubscriptionName $SubscriptionName -RGName $RGName -Location $Location -ResourcePrefix $ResourcePrefix -SitecorePwd $SitecorePwd -SqlServerLogin $SqlServerLogin -SqlServerPwd $SqlServerPwd -StorageAccountNameDeploy $StorageAccountNameDeploy -KeyVaultAdminMailAddress $KeyVaultAdminMailAddress -PathToSitecoreLicenseFile $PathToSitecoreLicenseFile

Write-Host "Extracting WebDeploy Parameters"

# Extract web deploy params from this deployment
Remove-Item -Path "$TempDir\*.*" -Recurse -Force -ErrorAction SilentlyContinue
mkdir -Path "$TempDir" -ErrorAction SilentlyContinue 

.\extract-params.ps1 -SubscriptionName $SubscriptionName -RGName $RGName -Location $Location -PathToSitecoreLicenseFile $PathToSitecoreLicenseFile -SetParamsCmOutputFilePath "$TempDir\CM.parameters.xml" -SetParamsCdOutputFilePath "$TempDir\CD.parameters.xml" 

Write-Host "Compiling and Packaging Solution"

# Compile the solution and package into web deploy package
.\package-multiproj-solution-for-webdeploy.ps1 -SolutionPath $PathToSolutionFile -TempDir "$TempDir\Solution" -PackageOutputDir "$TempDir\Packages" -ExecuteNuget

Write-Host "Deploying Baseline Package onto CM"

# Deploy baseline package onto preprod slot for CM
.\deploy-xm1-continuous.ps1 -SubscriptionName $SubscriptionName -RGName $RGName -PackageLocation "$CMPackageLocation" -ParamsFileLocation "$TempDir\CM.parameters.xml" -Role CM -SkipDbOperations

Write-Host "Deploying Customization Package overlaying onto CM"

# Deploy overlay customization package onto preprod slot for CM
.\deploy-xm1-continuous.ps1 -SubscriptionName $SubscriptionName -RGName $RGName -PackageLocation "$TempDir\Packages\webdeploy.zip" -ParamsFileLocation "$TempDir\CM.parameters.xml" -Role CM -DoNotDeleteExistingFiles

Write-Host "Deploying Baseline Package onto CD"

# Deploy baseline package onto preprod slot for CD
.\deploy-xm1-continuous.ps1 -SubscriptionName $SubscriptionName -RGName $RGName -PackageLocation "$CDPackageLocation" -ParamsFileLocation "$TempDir\CD.parameters.xml"  -Role CD -SkipDbOperations

Write-Host "Deploying Customization Package overlaying onto CD"

# Deploy overlay customization package onto preprod slot for CD
.\deploy-xm1-continuous.ps1 -SubscriptionName $SubscriptionName -RGName $RGName -PackageLocation "$TempDir\Packages\webdeploy.zip" -ParamsFileLocation "$TempDir\CD.parameters.xml" -Role CD -DoNotDeleteExistingFiles

Write-Host "Deployment Finished"
