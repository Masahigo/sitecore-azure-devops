[CmdletBinding()]
param()

# For more information on the VSTS Task SDK:
# https://github.com/Microsoft/vsts-task-lib
# http://blog.majcica.com/2015/11/14/available-modules-for-tfs-2015-build-tasks/
# https://github.com/Microsoft/vsts-tasks/blob/6b049dab46f49f0ed29534f5b3c7557afe96f041/Tasks/CopyPublishBuildArtifacts/CopyPublishBuildArtifacts.ps1

Trace-VstsEnteringInvocation $MyInvocation
try {
    # Set the solution path:
    $solutionPath = Get-VstsInput -Name solutionPath -Require
    Write-Verbose "Sitecore solution path is set to '$solutionPath'."

    # Set temp path:
    $tempPath = Get-VstsInput -Name tempDir

    # Set packages output directory path:
    $packagesOutputPath = Get-VstsInput -Name packagesOutputDirPath -Require

    # Get artifact name to publish towards:
    $artifactName = Get-VstsInput -Name artifactName -Require
    
    # Make sure temp path exists:
    if (Test-Path -LiteralPath $tempPath -PathType Container){
        Write-Host "Temp path is set to: '$tempPath'."
    }
    else{
        mkdir $tempPath
        Write-Host "Temp path is created at: '$tempPath'."
    }

    # Make sure the packages output path exists:
     if (Test-Path -LiteralPath $packagesOutputPath -PathType Container){
        Write-Host "Packages output path is set to: '$packagesOutputPath'."
    }
    else{
        mkdir $packagesOutputPath
        Write-Host "Packages output path is created at: '$packagesOutputPath'."
    }

    # Import the Task.Internal dll that has all the cmdlets we need for Build:
    # import-module "Microsoft.TeamFoundation.DistributedTask.Task.Common"

    # Run:
    & ".\package-multiproj-solution-for-webdeploy.ps1" -SolutionPath $solutionPath -TempDir $tempPath -PackageOutputDir $packagesOutputPath

    # Publish the resulting Web Deploy packages as build artifact:
    Write-VstsUploadArtifact -ContainerFolder "SitecoreWebDeployPackage" -Name $artifactName -Path $packagesOutputPath

} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
