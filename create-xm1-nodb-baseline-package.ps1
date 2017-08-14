#
# creates Sitecore xM1 baseline webdeploy packages without database operations
#

[CmdletBinding()]
Param(

  [Parameter(Mandatory=$False)]
  [string]$SATPath = "$(Split-Path $MyInvocation.MyCommand.Path)\toolkit 1.1 rev 170509",
  
  [Parameter(Mandatory=$False)]
  [string]$SCZipPath = "$(Split-Path $MyInvocation.MyCommand.Path)\sitecore zip\Sitecore 8.2 rev. 170407.zip"
)

$scriptDir = Split-Path $MyInvocation.MyCommand.Path

# Import Sitecore Azure Toolkit cmdlets:
Write-Host "Loading modules from Sitecore Azure Toolkit "
Import-Module $SATPath\Tools\Sitecore.Cloud.Cmdlets.psm1 -Verbose
Import-Module $SATPath\Tools\Sitecore.Cloud.CmdLets.dll -Verbose
Write-Host "Modules from Sitecore Azure Toolkit loaded."

# Run Sitecore Azure Toolkit, package into Web Deploy packages: one per role (CM & CD in case of xM1):
Write-Host "Running Sitecore Azure Toolkit.  SATPath is: $SATPath"
Start-SitecoreAzurePackaging -sitecorePath "$SCZipPath" -destinationFolderPath "$scriptDir" -cargoPayloadFolderPath "$SATPath\resources\8.2.3\CargoPayloads\" -commonConfigPath "$SATPath\resources\8.2.3\Configs\common.packaging.config.json" -skuConfigPath "$SATPath\resources\8.2.3\Configs\xm1.packaging.config.json" -parameterXmlPath "$SATPath\resources\8.2.3\MsDeployXmls"  -fileVersion 1.0 -Verbose
Write-Host "Finished running Sitecore Azure Toolkit"

Write-Host "Removing SC Database Operations from packages"
Remove-SCDatabaseOperations -Path "$(Split-Path $MyInvocation.MyCommand.Path)\Sitecore 8.2 rev. 170407_cd.scwdp.zip"  -Destination "$(Split-Path $MyInvocation.MyCommand.Path)"
Remove-SCDatabaseOperations -Path "$(Split-Path $MyInvocation.MyCommand.Path)\Sitecore 8.2 rev. 170407_cm.scwdp.zip"  -Destination "$(Split-Path $MyInvocation.MyCommand.Path)"
Write-Host "Removed Sitecore Database Operations from packages"

