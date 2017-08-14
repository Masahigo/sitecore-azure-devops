#
# Deploys a Sitecore ms deploy (web deploy) package using an msdeploy params file
#

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
  [string]$SubscriptionName,
  
  [Parameter(Mandatory=$True)]
  [string]$RGName,

  [Parameter(Mandatory=$True)]
  [string]$WebAppName,

  [Parameter(Mandatory=$True)]
  [string]$SlotName,
  
  [Parameter(Mandatory=$True)]
  [string]$PackageLocation,

  [Parameter(Mandatory=$True)]
  [string]$ParamsFileLocation,

  [Parameter(Mandatory=$False)]
  [string]$TempFolderName, #location to store publish profile

  [Parameter(Mandatory=$false)]
  [switch]$DoNotDeleteExistingFiles = $false,

  [Parameter(Mandatory=$false)]
  [switch]$SkipDbOperations = $false
)

$ErrorActionPreference = "Stop"

# If TempFolderName is not empty then use this, else use script dir. 
if($TempFolderName){
  Write-Host "TempFolderName supplied - creating directory if it does not exist - for storing publish profile"
  if ( ! (Test-Path $TempFolderName -PathType Container)) {
    New-Item -Path $TempFolderName -ItemType "Directory"
    Write-Host "Created folder: $TempFolderName"
  }
  $directorypath = $TempFolderName
}else{
  # Determine current working directory:
  Write-Host "TempFolderName not supplied - using local script execution path to store publish profile"
  $invocation = (Get-Variable MyInvocation).Value
  $directorypath = Split-Path $invocation.MyCommand.Path
}

# Constants:
$webAppPublishingProfileFileName = $directorypath + "\website.publishsettings"
Write-Output "web publishing profile will be stored to: $webAppPublishingProfileFileName"

# Select Subscription:
Get-AzureRmSubscription -SubscriptionName "$SubscriptionName" | Select-AzureRmSubscription
Write-Output "Selected Azure Subscription"

# Fetch publishing profile for web app:
Get-AzureRmWebAppSlotPublishingProfile -Name $WebAppName -OutputFile $webAppPublishingProfileFileName -ResourceGroupName $RGName -Slot $SlotName
Write-Output "Fetched Azure Web App Publishing Profile: website.publishsettings"

# Parse values from .publishsettings file:
[Xml]$publishsettingsxml = Get-Content $webAppPublishingProfileFileName
$websiteName = $publishsettingsxml.publishData.publishProfile[0].msdeploySite
Write-Output "web site name: $websiteName"

$username = $publishsettingsxml.publishData.publishProfile[0].userName
Write-Output "user name: $username"

$password = $publishsettingsxml.publishData.publishProfile[0].userPWD
Write-Output "password: $password"

$computername = $publishsettingsxml.publishData.publishProfile[0].publishUrl
Write-Output "computer name: $computername"

# Deploy the web app, deleting existing files on the target
$msdeploy = "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe"

# Flag determines if to overlay new content on top instead of deleting existing content
$DoNotDeleteRuleClause = ""
if($DoNotDeleteExistingFiles -eq $true) {
  $DoNotDeleteRuleClause = "-enableRule:DoNotDeleteRule"
}

$SkipDbOperationsClause = ""
if($SkipDbOperations -eq $true) {
  $SkipDbOperationsClause = "-skip:objectName=dbFullSql -skip:objectName=dbDacFx"
}

$msdeploycommandToDeployPackage = $("-verb:sync {0} {1} -source:package=`"{2}`" -dest:auto,computerName=https://{3}/msdeploy.axd?site={4},userName={5},password={6},authType=Basic -setParamFile:`"{7}`"" -f $DoNotDeleteRuleClause, $SkipDbOperationsClause, $PackageLocation, $computername, $websiteName, $username, $password, $ParamsFileLocation)

Write-Output "MS Deploy command about to be executed to deploy package: " $msdeploycommandToDeployPackage

Start-Process $msdeploy -NoNewWindow -ArgumentList $msdeploycommandToDeployPackage -PassThru -Wait

#remove publish profile from disk
Remove-Item -Path  $webAppPublishingProfileFileName
