[CmdletBinding()]
Param(

  [Parameter(Mandatory=$True)]
  [string]$FileFullUri,

  [Parameter(Mandatory=$True)]
  [string]$FileName,

  [Parameter(Mandatory=$True)]
  [string]$TempFolderName

)

$ErrorActionPreference = "Stop"

#create temp folder
if ( ! (Test-Path $TempFolderName -PathType Container)) {
   New-Item -Path $TempFolderName -ItemType "Directory"
   Write-Host "Created folder: $TempFolderName"
}

$localDestination = "$TempFolderName\$FileName"
 
Invoke-WebRequest $FileFullUri -OutFile $localDestination

Write-Host "File from Azure storage to '$localDestination'"

#end



