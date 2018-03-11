# This script builds and packages a multi-project Visual Studio .sln file into a single web deploy package
# It uses the web deploy manifest provider so that the resulting
# package can be deployed using the -dest:auto flag, which works nice with the rest of the deploy-xm1-* scripts
# ========== IMPORTANT NOTE ==========
# There is a flag which can be set and creates the package in a way it natively can be deployed from within VSTS
# (which expects an "IIS Web Application Name" parameter) as opposed to being deployed from 
# the deploy-xm1-continuous script (which expects an "Application Path" parameter instead.)
# Compatibility with deploy-xm1-continuous is the default, when no flag is given

[CmdletBinding()]
Param(
  #[Parameter(Mandatory=$True)]
  #[string]$SolutionPath, #path to the solution file

  [Parameter(Mandatory=$True)]
  [string]$SourceWebsitePath,  #path to the msbuild output path (prebuilt using Gulp) for CM role

  #[Parameter(Mandatory=$True)]
  #[string]$SourceWebsiteCDPath,  #path to the msbuild output path (prebuilt using Gulp) for CD role

  [Parameter(Mandatory=$True)]
  [string]$PackageName,

  [Parameter(Mandatory=$False)]
  [string]$TempDir = "$(Split-Path $MyInvocation.MyCommand.Path)\temp",

  [Parameter(Mandatory=$False)]
  [string]$PackageOutputDir = "$($TempDir)\webdeploy",

  [Parameter(Mandatory=$false)]
  [switch]$ExecuteNuget,

  # this param BREAKS compatibility with the deploy-xm1-contious script and emulates the default vs web deploy
  # packaging behavior, adding a "IIS Web Application Name" param instead of the "Application Path" param.
  # enabling this flag allows the resulting package to be used by VSTS native Web App deployment release task
  [Parameter(Mandatory=$false)]
  [switch]$PackageForExclusiveUseByVSTSOOBWebAppReleaseTask
)

$scriptDir = Split-Path $MyInvocation.MyCommand.Path
$msbuild = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\msbuild.exe"

# Create publish profile on the fly:
$publishProfileText = @"
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <WebPublishMethod>FileSystem</WebPublishMethod>
    <LastUsedBuildConfiguration>Debug</LastUsedBuildConfiguration>
    <LastUsedPlatform>Any CPU</LastUsedPlatform>
    <SiteUrlToLaunchAfterPublish />
    <ExcludeApp_Data>False</ExcludeApp_Data>
    <publishUrl>$($TempDir)</publishUrl>
    <DeleteExistingFiles>False</DeleteExistingFiles>
  </PropertyGroup>
</Project>
"@

# Clean TempDir directory:
Write-Host "Cleaning TempDir: $PackagTempDiresPath"
Remove-Item $TempDir -Recurse -Force

$publishProfileFilePath = "$TempDir\publishprofile.pubxml"
mkdir "$TempDir" -ErrorAction SilentlyContinue
$publishProfileText | Out-File "$publishProfileFilePath"
Write-Host "Dynamic publish profile has been created at: $publishProfileFilePath"

$msdeploy = "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe"

#Instead of building the solution here copy the entire content from build output done via Gulp
Write-Host "Copying the source from: $SourceWebsitePath and to: $TempDir with DoNotDeleteRule"
$msDeployExpression = "& '$msdeploy' --% -verb:sync -enableRule:DoNotDeleteRule -source:dirPath=`"$SourceWebsitePath`" -dest:dirPath=`"$TempDir`""
Invoke-Expression $msDeployExpression
Write-Host "Website from $SourceWebsitePath has been copied."

# Package up the directory in which all build output is layered, into a webdeploy package:
$packagename = $PackageOutputDir + "\" + $PackageName
mkdir $PackageOutputDir -ErrorAction SilentlyContinue

# Create package manifest on the fly:
$packageManifestText = @"
<sitemanifest>
  <IisApp path="$($TempDir)"/>
</sitemanifest>
"@

$packageManifestFilePath = "$TempDir\packagemanifest.xml"
$packageManifestText | Out-File "$packageManifestFilePath"
Write-Host "Dynamic package manifest has been created at: $packageManifestFilePath"

$declareParamUnicornPath = "-declareParam:name=unicornPath,kind=XmlFile,scope=`".*\.config`$`",match=`"//sitecore/unicorn/configurations/configuration/targetDataStore/@physicalRootPath`",defaultValue=`"D:\home\site\wwwroot\App_Data\unicorn`""
$declareHabitatWebsiteTargetHostName = "-declareParam:name=habitatWebsiteTargetHostname,kind=XmlFile,scope=`".*\.config`$`",match=`"//sitecore/sites/site[@name='habitat']/@targetHostName`""
$declareCommonWebsiteTargetHostName = "-declareParam:name=commonWebsiteRootHostname,kind=XmlFile,scope=`".*\.config`$`",match=`"//sitecore/sc.variable[@name='rootHostName']/@value`",defaultValue=`"azurewebsites.net`""

$EscapedTempDir = [Regex]::Escape($TempDir)

$declareIISWebAppName = "-declareParam:name=`"Application Path`",kind=`"ProviderPath`",scope=`"IisApp`",match=`"^$($EscapedTempDir)$`",defaultValue=`"Default Web Site/Contents`",tags=IisApp"

if($PackageForExclusiveUseByVSTSOOBWebAppReleaseTask -eq $True){
  $declareIISWebAppName = "-declareParam:name=`"IIS Web Application Name`",kind=`"ProviderPath`",scope=`"IisApp`",match=`"^$($EscapedTempDir)$`",defaultValue=`"Default Web Site/Contents`",tags=IisApp"
}

$msdeploycommandToCreatePackage = $("-verb:sync -enableRule:DoNotDeleteRule -source:manifest=`"{0}`" -dest:package=`"{1}`" {2} {3} {4} {5}" -f $packageManifestFilePath, $packagename, $declareParamUnicornPath, $declareIISWebAppName, $declareHabitatWebsiteTargetHostName, $declareCommonWebsiteTargetHostName)

Write-Output "MS Deploy command about to be executed to create package: " $msdeploycommandToCreatePackage

#cmd.exe /C "`"$msdeploycommandToCreatePackage`"";

Start-Process $msdeploy -NoNewWindow -ArgumentList $msdeploycommandToCreatePackage -PassThru -Wait