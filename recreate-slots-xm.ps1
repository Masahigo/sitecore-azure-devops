#
# deploy Sitecore xM1 webdeploy packages
# Note: Web Deploy 3.6 tooling can be downloaded through Web Platform Installer 5 (if not through Visual Studio itself)
#       after which it can be found in "C:\Program Files\IIS\Microsoft Web Deploy V3"
#

[CmdletBinding()]
Param(
  # Params required for provisioning into the exsiting Resource group:
  [Parameter(Mandatory=$True)]
  [string]$SubscriptionName,
  
  [Parameter(Mandatory=$True)]
  [string]$RGName,

  [Parameter(Mandatory=$False)]
  [string]$ArtifactsRootDir,

  [Parameter(Mandatory=$False)]
  [string]$TempFolderName,

  [Parameter(Mandatory=$false)]
  [switch]$RemoveCurrentSlots = $false,

  [Parameter(Mandatory=$false)]
  [switch]$LeaveTempFilesOnDisk
)

function ConvertPSObjectToHashtable
{
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process
    {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
        {
            $collection = @(
                foreach ($object in $InputObject) { ConvertPSObjectToHashtable $object }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject])
        {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] = ConvertPSObjectToHashtable $property.Value
            }

            $hash
        }
        else
        {
            $InputObject
        }
    }
}

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

$paramsFile = @{
    '$schema' = "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
    contentVersion = "1.0.0.0"
    parameters = @{
      'dummyParam' = @{
        value = "Dummy value"
      }
    }
  }

$paramsFilePath = "$scriptDir\xm-asp-sitecore-webdeploy.parameters.tmp.json"
Write-Host "Temp params file to be written to: $paramsFilePath"
$paramsFile | ConvertTo-Json -Depth 5 | Out-File $paramsFilePath

$outParams = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $RGName -Name "sitecore-keyvault").Outputs
$slotsOutParams = (Get-AzureRmResourceGroupDeployment -ResourceGroupName $RGName -Name "sitecore-slots").Outputs

$sitecoreDeploymentOutputAsJson =  ConvertTo-Json $outParams -Depth 5
$sitecoreDeploymentOutputAsHashTable = ConvertPSObjectToHashtable $(ConvertFrom-Json $sitecoreDeploymentOutputAsJson)

$CmWebAppName = $outParams.cmWebAppNameTidy.Value
$CdWebAppName = $outParams.cdWebAppNameTidy.Value
$CmSlotName = $slotsOutParams.cmSlotName.Value
$CdSlotName = $slotsOutParams.cdSlotName.Value

if($RemoveCurrentSlots -eq $true) {
  Write-Host "Removing current slots..."
  Remove-AzureRmWebAppSlot -ResourceGroupName $RGName -Name $CmWebAppName -Slot $CmSlotName -Force
  Remove-AzureRmWebAppSlot -ResourceGroupName $RGName -Name $CdWebAppName -Slot $CdSlotName -Force
}

Write-Host "Start creating new slots..."
# Deploy ARM template
New-AzureRmResourceGroupDeployment -Verbose -Force -ErrorAction Stop `
   -Name "sitecore-emptyslots" `
   -ResourceGroupName $RGName `
   -TemplateFile "$scriptDir/templates/xm/custom/slots.template.json" `
   -TemplateParameterFile $paramsFilePath `
   -sitecoreProvOutput $sitecoreDeploymentOutputAsHashTable

Write-Host "Stopping slots..."
Stop-AzureRmWebAppSlot -ResourceGroupName $RGName -Name $CmWebAppName -Slot $CmSlotName
Stop-AzureRmWebAppSlot -ResourceGroupName $RGName -Name $CdWebAppName -Slot $CdSlotName

# Clean up temporary params file:
if($LeaveTempFilesOnDisk -eq $false) {
  # Remove-Item -Path $paramsFilePath
}