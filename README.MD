# Sitecore 8.2u3 DevOps Scripts by Christof Claessens <christoc@microsoft.com> and Katrien De Graeve <Katrien.DeGraeve@microsoft.com>

_Disclaimer: the included set of scripts and templates are SAMPLES and do not come with any form of warranty or guarantees.  Please use them at your own risk._ 

> **Configuring DevOps with VSTS** - Please see second section in this document for more details on properly setting up VSTS devops flow.

## Overview

This package comes with a number of scripts and templates which were designed to facilitate the deployment and devops flow for Sitecore 8.2u3.   It's core script components include:
- `deploy.xm1-initial.ps1`
- `package-multiproj-solution-for-webdeploy.ps1`
- `extract-params.ps1`
- `deploy-xm1-continuous.ps1`
- `deploy-xm1-continuous-generic.ps1`

These make use of two custom-made Sitecore addons:
- `templates\xm\addons\keyvault.json`
- `templates\xm\addons\slots.json`

## Setup

The package is structured in a particular way, so that the scripts can rely on a well-known location to find and call into components of:
- Sitecore 8.2u3 ARM templates
- Sitecore 8.2u3 Web Deploy packages
- Sitecore Azure Toolkit

To indicate what this structure looks like (while avoiding having to distribute Sitecore artifacts), a set of empty dummy files, suffixed with ".COPYINTOHERE" are packaged so to clearly indicate the location of these components.

Before you get started:
- copy the Sitecore 8.2u3 Web Deploy packages into the `./packages/xM1/` folder
- copy the Sitecore 8.2u3 ARM templates, as found on GitHub, into the `./templates/` folder
- copy Sitecore Azure Toolkit 1.1 rev 170509 into the `./toolkit 1.1 rev 170509/` folder 

All "*.COPYINTOHERE" files may be safely deleted.

## DevOps Flow

### Deploying Sitecore 8.2u3 for the first time

To deploy Sitecore for the first time, one will need to provision the Azure resources (Web Apps, Databases, Search, Redis, ...) and deploy onto those the files and data which Sitecore needs to run it's plain vanilla out-of-box "hello-world" experience.

In order to facilitate such first deployment, the script `deploy-xm1-initial.ps1` is provided.  This can be used like this:

```powershell
.\deploy-xm1-initial.ps1 -SubscriptionName [SUBSCRIPTION NAME]  -Location [LOCATION] -ResourcePrefix [RESOURCE PREFIX] -SqlServerLogin [SQL LOGIN USER NAME] -PathToSitecoreLicenseFile [LICENSE FILE LOCATION]
```

This will cause the `./templates/xm/azuredeploy.json` template to be executed, instructing it to deploy 2 additional custom addons, called "keyvault" and "slots".  This ensures that in addition to the regular Sitecore ARM template that:
- Azure KeyVault will be provisioned and populated with all usernames and passwords for the deployment
- there are output parameters recorded for the deployment which can be used to deduct deployment parameters from during devops
- two additional site slots are provisioned: one for Content Delivery and one for Content Management

> Note: Both additional addons are expected by the other scripts to have been deployed.

In the script, both modules are deployed by providing the `azuredeploy.json` with a value like the following for its `modules` parameter:

```json
"parameters": {
        ... more params go here ...
        "modules": {
            "value": {
                "items": [
                    {
                        "templateLink": "https://storacctname.blob.core.windows.net/tempsitecore823templates/addons/keyvault.json?sv=..sastoken..",
                        "name": "keyvault",
                        "parameters": {
                            "keyvaultSku": "Standard",
                            "userIdforKeyvault": "37d58ba2-3339-4ed8-baa0-b5843c39ed0b"
                        }
                    },
                    {
                        "templateLink": "https://storacctname.blob.core.windows.net/tempsitecore823templates/addons/slots.json?sv=..sastoken..",
                        "name": "slots",
                        "parameters": {}
                    }
                ]
            }
        }
    }
```

### Deploying customizations to the Sitecore environment after the first time

Any updates to the environment will be deployed towards the preproduction site slots for both CM and CD.  This means that for both CM and CD two things need to happen:
1) a Sitecore baseline installation will need to be deployed to the preproduction slot (without custom code, just the Sitecore files without deploying the dacpacks and sql scripts as these just need to happen the very first time).  This baseline deployment will wipe away all content from the preproduction slot
2) Sitecore customizations will need to be deployed on top of the preproduction slots, overlaying them on top of the baseline instead of wiping all existing files.  This is purely deploying incremental on top of what was already in the slot from the baseline.

#### Extracting parameters for use with Web Deploy

Before step 1 or 2 can happen, one will need to fetch the parameters required for Web Deploy to be able to deploy to the Web Apps for CM and CD.  The script called `extract-params.ps1` is provided to make this really easy: after all, all information required for a deployment can be found in KeyVault and the output parameters which custom addons took care of.  This means that `extract-params.ps1` doesn't need to know much more than the resource group towards one wants to deploy: 

```powershell
 .\extract-params.ps1 -SubscriptionName [SUBSCRIPTION NAME] -RGName [NAME OF RESOURCE GROUP] -Location [LOCATION] -PathToSitecoreLicenseFile [PATH TO LICENSE XML]
```

This creates two files which can be used for executing Web Deploy: "CM.parameters.xml" and "CD.parameters.xml".

#### Deploying the Sitecore baseline installation on a preproduction slot

Using `deploy-xm1-continuous.ps1` one can now pass in one of the parameter.xml files generated by `extract-params.ps1` to deploy the basineline Sitecore 8.2u3 package onto the production slot for both CM and CD:

```powershell
.\deploy-xm1-continuous.ps1 -SubscriptionName [SUBSCRIPTION NAME] -RGName [NAME OF RESOURCE GROUP] -PackageLocation [LOCATION TO SITECORE 8.2 .SCWDP.ZIP PACKAGE] -ParamsFileLocation [LOCATION OF PARAM FILE FOR CM OR CD] -Role [CM or CD] -SkipDbOperations
```

This will cause the Sitecore baseline installation to wipe the preproduction slot and to deploy onto it all the default out-of-box Sitecore files.

The `-SkipDbOperations` flag makes sure that there's no separate Web Deploy package required for deploying a Sitecore baseline; rather the flag causes any SQL or DACFX Web Deploy operations to be skipped.  So either one uses a custom Sitecore baseline package from which database operations were stripped, or one uses the default Sitecore Web Deploy packages in combination with this flag.

#### Deploying Sitecore customizations onto the baseline in a preproduction slot

Essentially this is the exact same process.  The only difference being that one would point the `deploy-xm1-continuous.ps1` script to a custom Web Deploy package in which just the customizations are packaged.

In order to create such custom Web Deploy package, the `package-multiproj-solution-for-webdeploy.ps1` can be used, which builds and packages a solution in a way which is understood by `deploy-xm1-continuous.ps1`.


# Configuring DevOps with VSTS

### Pre-requisites

- Create a connection (Service Endpoint) to Azure. This will create a Service Principal. Typiclly you can follow the steps to create the Service by adding Azure Powershell tasks to Build or Release flows and clicking 'Manage'.
- The source packages from Sitecore. We chose to add these to Git repo in our case.

## Build pipeline

#### Part 1 - Store artifacts for provisioning Azure resources
This build pipeline simply copies all PS1 and ARM template files to an Artifacts folder.
* Step 1 - Create a new Build definition linked to your repo with all JSON templates and PS1 (this repo).
* Step 2 - Get Sources task.
* Step 3 - Copy Files task. Take source folder 'sitecore-oob/Sitecore 8.2.3', filter on the contents you want in the artifacts (typically packages, templates/**, etc)
* Step 4 - Publish Artifacts Task. Publish into the '$(Build.ArtifactStagingDirectory)' destination and give your artifacts a name (you'll need this in your Release pipeline).


#### Part 2 - Build the custom project (incremental)
To build the custom project, our build pipeline leverages a custom VSTS Task. Please see /sitecore-vsts-tasks/ readme file in order to install the Task on your VSTS account.
* Step 1 - Pre-requisite VSTS task: Please see /sitecore-vsts-tasks/ readme.
* Step 2 - Create a new build pipeline in VSTS, based on the repo with your custom code (incremental deploy to Sitecore).
* Step 3 - Add VSTS task 'Get sources' from your custom Sitecore solution.
* Step 4 - Add VSTS Task NuGet restore.
* Step 5 - Add VSTS custom task VstsSitecoreSingleWebDeploy (see step 1)
  * Parameter Solution Path: select your sln file
  * Parameter Temp path: by default '$(Agent.BuildDirectory)\Temp'
  * Parameter Packages Output Dir: $(Build.ArtifactStagingDirectory)
  * Parameter Name for resulting Build Artifact: typically output or another name you choose
* Make sure to schedule a build and verify the artifact is indeed a webdeploy.zip package.

## Release pipeline

#### Part 1 - One-time base provision of Azure resources and Sitecore base

* Step 1 - Create a new Release definition, based on the Build definition from part 1.
* Step 2 - Create a Variables group that you'll need to pass on to the arguments in the tasks. Link this group in the Artifacts pane.
* Step 3 - Azure Powershell Task. Select the PS 'vsts/downloadUrl.ps1' via the selector. Add the arguments as needed, leverage the variables to pass on their values.
Note: for the Azure Powershell task you need to select your Subscription and create a service principal if not yet done so. Do this through the Manage button in the task.
* Step 4 - Add Azure Powershell Task. Link to the PS 'deploy-xm1-initial.ps1'. Note this script requires a lot of arguments that you'll use from your variable set. 
* Step 5 - Add 'Delete Files' task. Refer to the temp directory where the license file (in step 3) was saved to. You'll want to clean this directory on the agent using this task.



#### Part 2 - Incremental deploy of custom project(s) 

This Release pipeline will be run every time you are publishin a new version of custom code and Unicorn/serialized content to Sitecore. This guide is very simple and only addresses a single 'dev' environment continuous deployment. Optimally you'd extend this with multiple environments, approvers, extra steps to automate Unicorn, Site swaps, database backups and more. 

* Step 1 - Create a new Release definition.
* Step 2 - Link both the Build artifacts from above (both the custom code project, and the templates/PS file).
* Step 3 - Link the variables collection used in the previous release.
* Step 4 - Add VSTS Task Azure Powershell to run 'vsts/downloadUrl.ps1'. This will download the license.xml file from a Sas blob URI onto a temp folder.
* Step 5 - Add VSTS Task Azure Powershell to run 'extract-params.ps1'. This will create temporary XML parameter files.
* Step 6 - CM Baseline re-deploy -  Add VSTS Task Azure Powershell to run 'deploy-xm1-continuous.ps1'.
  * Important for the arguments to pass these:  -Role "CM" -SkipDbOperations (and others that are required).
* Step 7 - CM Incremental deploy -  Add VSTS Task Azure Powershell to run 'deploy-xm1-continuous.ps1'.
  * Important for the arguments to pass these:  - -Role "CM" -DoNotDeleteExistingFiles (and others that are required).
* Step 8 - CD Baseline re-deploy -  Add VSTS Task Azure Powershell to run 'deploy-xm1-continuous.ps1'.
  * Important for the arguments to pass these:  -Role "CD" -SkipDbOperations (and others that are required).
* Step 9 - CD Incremental deploy -  Add VSTS Task Azure Powershell to run 'deploy-xm1-continuous.ps1'.
  * Important for the arguments to pass these:  - -Role "CD" -DoNotDeleteExistingFiles (and others that are required).
* Step 10 - Add VSTS Task Delete Files and refer to the temp directory to be cleaned. 


