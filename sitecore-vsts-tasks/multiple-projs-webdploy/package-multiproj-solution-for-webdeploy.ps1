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
  [Parameter(Mandatory=$True)]
  [string]$SolutionPath, #path to the solution file

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
$publishProfileFilePath = "$TempDir\publishprofile.pubxml"
mkdir "$TempDir" -ErrorAction SilentlyContinue
$publishProfileText | Out-File "$publishProfileFilePath"
Write-Host "Dynamic publish profile has been created at: $publishProfileFilePath"

# Restore Nuget packages if asked (for local execution)
if($ExecuteNuget -eq $true) {
  Nuget.exe restore "$SolutionPath"
}

# Compile the solution file and publish to file system (temp)
Write-Host "Building the solution from: $SolutionPath and deploying to: $tempWebsitePath"
  $buildExpression = "$msbuild `"$SolutionPath`" /p:DeployOnBuild=true /p:PublishProfile=`"$publishProfileFilePath`" /p:SkipExtraFilesOnServer=True /p:VisualStudioVersion=14.0"
Write-Host "build expression: $buildExpression"
Invoke-Expression $buildExpression
Write-Host "Solution at $SolutionPath has been build and published."

# Package up the directory in which all build output is layered, into a webdeploy package:
$msdeploy = "C:\Program Files (x86)\IIS\Microsoft Web Deploy V3\msdeploy.exe"
$packagename = $PackageOutputDir + "\webdeploy.zip"
mkdir $PackageOutputDir -ErrorAction SilentlyContinue
# Remove-Item $packagename -ErrorAction SilentlyContinue

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

$EscapedTempDir = [Regex]::Escape($TempDir)

$declareIISWebAppName = "-declareParam:name=`"Application Path`",kind=`"ProviderPath`",scope=`"IisApp`",match=`"^$($EscapedTempDir)$`",defaultValue=`"Default Web Site/Contents`",tags=IisApp"

if($PackageForExclusiveUseByVSTSOOBWebAppReleaseTask -eq $True){
  $declareIISWebAppName = "-declareParam:name=`"IIS Web Application Name`",kind=`"ProviderPath`",scope=`"IisApp`",match=`"^$($EscapedTempDir)$`",defaultValue=`"Default Web Site/Contents`",tags=IisApp"
}

$msdeploycommandToCreatePackage = $("-verb:sync -enableRule:DoNotDeleteRule -source:manifest=`"{0}`" -dest:package=`"{1}`" {2} {3}" -f $packageManifestFilePath, $packagename, $declareParamUnicornPath, $declareIISWebAppName)

Write-Output "MS Deploy command about to be executed to create package: " $msdeploycommandToCreatePackage

#cmd.exe /C "`"$msdeploycommandToCreatePackage`"";

Start-Process $msdeploy -NoNewWindow -ArgumentList $msdeploycommandToCreatePackage -PassThru -Wait