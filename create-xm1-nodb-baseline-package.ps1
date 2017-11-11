#
# creates Sitecore xM1 baseline webdeploy packages without database operations
#

[CmdletBinding()]
Param(

  [Parameter(Mandatory=$False)]
  [string]$PackagesPath = "$(Split-Path $MyInvocation.MyCommand.Path)\packages\custom\xm",

  [Parameter(Mandatory=$False)]
  [string]$SATPath = "$(Split-Path $MyInvocation.MyCommand.Path)\toolkit 1.1 rev 170804",
  
  [Parameter(Mandatory=$False)]
  [string]$SCZipPath = "$(Split-Path $MyInvocation.MyCommand.Path)\sitecore zip\Sitecore 8.2 rev. 170728.zip"
)

#$scriptDir = Split-Path $MyInvocation.MyCommand.Path

# Import Sitecore Azure Toolkit cmdlets:
Write-Host "Loading modules from Sitecore Azure Toolkit "
Import-Module $SATPath\Tools\Sitecore.Cloud.Cmdlets.psm1 -Verbose
Import-Module $SATPath\Tools\Sitecore.Cloud.CmdLets.dll -Verbose
Write-Host "Modules from Sitecore Azure Toolkit loaded."

# Clean PackagesPath directory:
Write-Host "Cleaning PackagesPath: $PackagesPath"
Remove-Item $PackagesPath -Recurse -Force
mkdir $PackagesPath

# Run Sitecore Azure Toolkit, package into Web Deploy packages: one per role (CM & CD in case of xM):
Write-Host "Running Sitecore Azure Toolkit.  SATPath is: $SATPath"
Start-SitecoreAzurePackaging -sitecorePath "$SCZipPath" -destinationFolderPath "$PackagesPath" -cargoPayloadFolderPath "$SATPath\resources\8.2.5\CargoPayloads\" -commonConfigPath "$SATPath\resources\8.2.5\Configs\common.packaging.config.json" -skuConfigPath "$SATPath\resources\8.2.5\Configs\xm1.packaging.config.json" -parameterXmlPath "$SATPath\resources\8.2.5\MsDeployXmls"  -fileVersion 1.0 -Verbose
Write-Host "Finished running Sitecore Azure Toolkit"

Write-Host "Removing SC Database Operations from packages"
Remove-SCDatabaseOperations -Path "$PackagesPath\Sitecore 8.2 rev. 170407_cd.scwdp.zip"  -Destination "$PackagesPath"
Remove-SCDatabaseOperations -Path "$PackagesPath\Sitecore 8.2 rev. 170407_cm.scwdp.zip"  -Destination "$PackagesPath"
Write-Host "Removed Sitecore Database Operations from packages"

