#
# Extracts webdeploy params file from a sitecore deployment which has been deployed with the keyvault addon 
#

[CmdletBinding()]
Param(
  # Params required for provisioning into the exsiting Resource group:
  [Parameter(Mandatory=$True)]
  [string]$SubscriptionName,
  
  [Parameter(Mandatory=$True)]
  [string]$RGName,
  
  [Parameter(Mandatory=$True)]
  [string]$Location,

  [Parameter(Mandatory=$False)]
  [string]$PathToSitecoreLicenseFile = ".\license.xml",

  [Parameter(Mandatory=$False)]
  [string]$SetParamsCmOutputFilePath = "$(Split-Path $MyInvocation.MyCommand.Path)\CM.parameters.xml",

  [Parameter(Mandatory=$False)]
  [string]$SetParamsCdOutputFilePath = "$(Split-Path $MyInvocation.MyCommand.Path)\CD.parameters.xml",
  
  [Parameter(Mandatory=$False)]
  [string]$ArtifactsRootDir,

  [Parameter(Mandatory=$False)]
  [string]$TempFolderName,

  [Parameter(Mandatory=$False)]
  [string]$CMTargetHostname = "",

  [Parameter(Mandatory=$False)]
  [string]$CDTargetHostname = "",

  [Parameter(Mandatory=$False)]
  [string]$WebsiteRootHostname = ""

)

$ErrorActionPreference = "Stop"

#if Artifacts is supplied, overwrite the path set to local execution folder (for use with VSTS)
if ($ArtifactsRootDir){
  if(!$TempFolderName){
    throw "You have supplied ArtifactsRootDir which works together with TempFolderName, please supply the temp full path"
  }
  if ( ! (Test-Path $TempFolderName -PathType Container)) {
    New-Item -Path $TempFolderName -ItemType "Directory"
    Write-Host "Created folder: $TempFolderName"
  }
  $scriptDir = $ArtifactsRootDir
}else{
  $scriptDir = Split-Path $MyInvocation.MyCommand.Path
}

Select-AzureRmSubscription -SubscriptionName $SubscriptionName
Write-Host "Selected subscription: $SubscriptionName"

# Check if given license file exists
if ( ! (Test-Path $PathToSitecoreLicenseFile -PathType Leaf )) {
  throw "LICENSE FILE DOES NOT EXIST - PLEASE SPECIFY VALID LICENSE FILE"
}

# Find existing Resource Group:
$rg = Get-AzureRmResourceGroup -Location $Location -Name $RGName -ErrorAction Stop

Write-Host "Loaded RG: $RGName"

#============================

# Read and encode license file based on full path in arguments
$licenseFileContent = Get-Content -Raw -Encoding UTF8 -Path $PathToSitecoreLicenseFile | Out-String;
$licenseEncoded = [System.Security.SecurityElement]::Escape($licenseFileContent)
Write-Host "License file encoded"
#============================
# Generate XML parameter files

$outParams = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName -Name "sitecore-keyvault").Outputs
$slotsOutParams = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName -Name "sitecore-slots").Outputs

$keyVaultName = $outParams.keyVaultName.Value
#$keyVault = Get-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $rg.ResourceGroupName


$ResourcePrefix = $outParams.deploymentId.Value
$CmWebAppName = $outParams.cmWebAppNameTidy.Value
$CdWebAppName = $outParams.cdWebAppNameTidy.Value
$CmSlotName = $slotsOutParams.cmSlotName.Value
$CdSlotName = $slotsOutParams.cdSlotName.Value
$SqlServerFqdn = $outParams.sqlServerFqdn.Value
$WebSqlServerFqdn = $outParams.webSqlServerFqdn.Value
$CdWebAppFqdn = $outParams.cdWebAppFqdn.Value
$SqlServerLogin = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name sqlServerLogin).SecretValueText
$SqlServerPwd = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name sqlServerPassword).SecretValueText
$CoreDBName = $outParams.coreDbNameTidy.Value
$MasterDBName = $outParams.masterDbNameTidy.Value
$WebDBName = $outParams.webDbNameTidy.Value
$CmMasterDbLogin = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name cmMasterSqlDatabaseUserName).SecretValueText
$CmMasterDbPwd = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name cmMasterSqlDatabasePassword).SecretValueText
$WebSqlServerLogin = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name webSqlServerLogin).SecretValueText
$WebSqlServerPwd = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name webSqlServerPassword).SecretValueText
$CmWebDbLogin = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name cmWebSqlDatabaseUserName).SecretValueText
$CmWebDbPwd = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name cmWebSqlDatabasePassword).SecretValueText
$SearchServiceName = $outParams.searchServiceNameTidy.Value
$SearchApiKey = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name searchServiceApiKey).SecretValueText
$telerikEncryptionKey = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name telerikEncryptionKey).SecretValueText
$commonWebsiteRootHostname = "azurewebsites.net"

# Declare and then create the XML files on disk
Write-Host "Finished loading from out params"

$CM_IISWebApplicationName = "$ResourcePrefix-cm"
$CD_IISWebApplicationName = "$ResourcePrefix-cd"
$CM_ApplicationPath = "$($CmWebAppName)__$($CmSlotName)"
$SitecorePwd = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name sitecoreAdminPassword).SecretValueText
$CM_CoreDbLogin = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name cmCoreSqlDatabaseUserName).SecretValueText
$CM_CoreDbPwd = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name cmCoreSqlDatabasePassword).SecretValueText
$CoreAdminConnString = "Encrypt=True;TrustServerCertificate=False;Data Source=$SqlServerFqdn,1433;Initial Catalog=$CoreDBName;User Id=$SqlServerLogin;Password=$SqlServerPwd"
$CM_CoreConnString = "Encrypt=True;TrustServerCertificate=False;Data Source=$SqlServerFqdn,1433;Initial Catalog=$CoreDBName;User Id=$CM_CoreDbLogin;Password=$CM_CoreDbPwd"
$MasterAdminConnString = "Encrypt=True;TrustServerCertificate=False;Data Source=$SqlServerFqdn,1433;Initial Catalog=$MasterDBName;User Id=$SqlServerLogin;Password=$SqlServerPwd"
$MasterConnString = "Encrypt=True;TrustServerCertificate=False;Data Source=$SqlServerFqdn,1433;Initial Catalog=$MasterDBName;User Id=$CmMasterDbLogin;Password=$CmMasterDbPwd"
$CM_WebDbLogin = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name cmWebSqlDatabaseUserName).SecretValueText
$CM_WebDbPwd = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name cmWebSqlDatabasePassword).SecretValueText
$WebAdminConnString = "Encrypt=True;TrustServerCertificate=False;Data Source=$WebSqlServerFqdn,1433;Initial Catalog=$WebDBName;User Id=$WebSqlServerLogin;Password=$WebSqlServerPwd"
$WebConnString = "Encrypt=True;TrustServerCertificate=False;Data Source=$WebSqlServerFqdn,1433;Initial Catalog=$WebDBName;User Id=$CmWebDbLogin;Password=$CmWebDbPwd"
$CloudSearchConnString = "serviceUrl=https://$SearchServiceName.search.windows.net;apiVersion=2015-02-28;apiKey=$SearchApiKey"
$AppInsightsInstrumentationKey = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name appInsightsInstrumentationKey).SecretValueText
$CM_KeepAliveUrl = "https://$CmWebAppName.azurewebsites.net/sitecore/service/keepalive.aspx"
$CM_TargetHostName = $CM_IISWebApplicationName + '.$(rootHostName)'
$CD_TargetHostName = $CD_IISWebApplicationName + '.$(rootHostName)'

if($CMTargetHostname){
  Write-Host "CMTargetHostname supplied: $CMTargetHostname"
  $CM_TargetHostName = $CMTargetHostname
}else{
  Write-Host "CMTargetHostname is empty"
}

if($CDTargetHostname){
  Write-Host "CDTargetHostname supplied: $CDTargetHostname"
  $CD_TargetHostName = $CDTargetHostname
}else{
  Write-Host "CDTargetHostname is empty"
}

if($WebsiteRootHostname){
  Write-Host "WebsiteRootHostname supplied: $WebsiteRootHostname"
  $commonWebsiteRootHostname = $WebsiteRootHostname
}else{
  Write-Host "WebsiteRootHostname is empty"
}

$setParamsCM = @"
<parameters>
  <setParameter name="IIS Web Application Name" value="$CM_IISWebApplicationName" />
  <setParameter name="Application Path" value="$CM_ApplicationPath"/>
  <setParameter name="Sitecore Admin New Password" value="$SitecorePwd"/>
  <setParameter name="Core DB User Name" value="$CM_CoreDbLogin"/>
  <setParameter name="Core DB Password" value="$CM_CoreDbPwd"/>
  <setParameter name="Core Admin Connection String" value="$CoreAdminConnString" />
  <setParameter name="Core Connection String" value="$CM_CoreConnString" />
  <setParameter name="Master DB User Name" value="$SqlServerLogin"/>
  <setParameter name="Master DB Password" value="$SqlServerPwd"/>
  <setParameter name="Master Admin Connection String" value="$MasterAdminConnString"/>
  <setParameter name="Master Connection String" value="$MasterConnString"/>
  <setParameter name="Web DB User Name" value="$CM_WebDbLogin"/>
  <setParameter name="Web DB Password" value="$CM_WebDbPwd"/>
  <setParameter name="Web Admin Connection String" value="$WebAdminConnString"/>
  <setParameter name="Web Connection String" value="$WebConnString"/>
  <setParameter name="Cloud Search Connection String" value="$CloudSearchConnString"/>
  <setParameter name="Application Insights Instrumentation Key" value="$AppInsightsInstrumentationKey"/>
  <setParameter name="Application Insights Role" value="CM"/>
  <setParameter name="KeepAlive Url" value="$CM_KeepAliveUrl"/>
  <setParameter name="Social Link Domain" value="$CdWebAppFqdn"/>
  <setParameter name="License Xml" value="$licenseEncoded"/>
  <setParameter name="IP Security Client IP" value="0.0.0.0" />
  <setParameter name="IP Security Client IP Mask" value="0.0.0.0" />
  <setParameter name="Telerik Encryption Key" value="$telerikEncryptionKey"/>
  <setParameter name="habitatWebsiteTargetHostname" value="$CM_TargetHostName" />
  <setParameter name="commonWebsiteRootHostname" value="$commonWebsiteRootHostname" />
</parameters>
"@

Write-Host "CM params XML created in memory"

$CD_IISWebApplicationName = "$ResourcePrefix-cd"
$CD_ApplicationPath = "$($CdWebAppName)__$($CdSlotName)"
$CD_CoreDbLogin = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name cdCoreSqlDatabaseUserName).SecretValueText
$CD_CoreDbPwd = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name cdCoreSqlDatabasePassword).SecretValueText
# $CoreAdminConnString = "Encrypt=True;TrustServerCertificate=False;Data Source=$SqlServerFqdn,1433;Initial Catalog=$CoreDBName;User Id=$SqlServerLogin;Password=$SqlServerPwd" => is the same for CD and CM
$CD_CoreConnString = "Encrypt=True;TrustServerCertificate=False;Data Source=$SqlServerFqdn,1433;Initial Catalog=$CoreDBName;User Id=$CD_CoreDbLogin;Password=$CD_CoreDbPwd"
$CD_WebDbLogin = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name cdWebSqlDatabaseUserName).SecretValueText
$CD_WebDbPwd = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name cdWebSqlDatabasePassword).SecretValueText
# $WebAdminConnString = "Encrypt=True;TrustServerCertificate=False;Data Source=$WebSqlServerFqdn,1433;Initial Catalog=$WebDBName;User Id=$WebSqlServerLogin;Password=$WebSqlServerPwd" => is the same for CD and CM
$CD_WebConnString = "Encrypt=True;TrustServerCertificate=False;Data Source=$WebSqlServerFqdn,1433;Initial Catalog=$WebDBName;User Id=$CD_WebDbLogin;Password=$CD_WebDbPwd"
$CD_KeepAliveUrl = "https://$CdWebAppName.azurewebsites.net/sitecore/service/keepalive.aspx"

$RedisName = $outParams.redisCacheNameTidy.Value
$RedisHostName = $outParams.redisCacheHostName.Value
$RedisSSLPort = $outParams.redisCacheSSLPort.Value
$RedisPassword = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name redisPassword).SecretValueText
$RedisConnString = "$($RedisHostName):$RedisSSLPort,password=$RedisPassword,ssl=True,abortConnect=False"
 
$setParamsCD = @"
<parameters>
  <setParameter name="IIS Web Application Name" value="$CD_IISWebApplicationName" />
  <setParameter name="Application Path" value="$CD_ApplicationPath"/>
  <setParameter name="Sitecore Admin New Password" value="$SitecorePwd"/>
  <setParameter name="Core DB User Name" value="$CD_CoreDbLogin"/>
  <setParameter name="Core DB Password" value="$CD_CoreDbPwd"/>
  <setParameter name="Core Admin Connection String" value="$CoreAdminConnString"/>
  <setParameter name="Core Connection String" value="$CD_CoreConnString"/>
  <setParameter name="Web DB User Name" value="$CD_WebDbLogin"/>
  <setParameter name="Web DB Password" value="$CD_WebDbPwd"/>
  <setParameter name="Web Admin Connection String" value="$WebAdminConnString"/>
  <setParameter name="Web Connection String" value="$CD_WebConnString"/>
  <setParameter name="Cloud Search Connection String" value="$CloudSearchConnString"/>
  <setParameter name="Application Insights Instrumentation Key" value="$AppInsightsInstrumentationKey"/>
  <setParameter name="Application Insights Role" value="CD"/>
  <setParameter name="KeepAlive Url" value="$CD_KeepAliveUrl"/>
  <setParameter name="Redis Connection String" value="$RedisConnString"/>
  <setParameter name="License Xml" value="$licenseEncoded"/>
  <setParameter name="habitatWebsiteTargetHostname" value="$CM_TargetHostName" />
  <setParameter name="commonWebsiteRootHostname" value="$commonWebsiteRootHostname" />
</parameters>
"@

Write-Host "CD params XML created in memory"

$setParamsCM | Out-File $SetParamsCmOutputFilePath
$setParamsCD | Out-File $SetParamsCdOutputFilePath

Write-Host "parameter files created"