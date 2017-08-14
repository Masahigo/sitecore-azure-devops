# Custom VSTS Build Task

## Package multiple projects into single WebDeploy package

### Install Cross-platform CLI for Team Foundation Server and Visual Studio Team Services

See: https://www.npmjs.com/package/tfx-cli
and for more examples: https://github.com/Microsoft/vsts-tasks

```
  npm install -g tfx-cli
```

### Login to your VSTS repository

```
  # Login to VSTS first 
  tfx login
  # Provide the Service URL (https://something.visualstudio.com/DefaultCollection)
  # Then provide your personal access token (be sure to generate one first, see https://www.visualstudio.com/en-us/docs/setup-admin/team-services/use-personal-access-tokens-to-authenticate)
```

### Upload the custom build task to VSTS

```
# From within the right directory:
tfx build tasks upload --task-path .
```

### To delete the custom build Task

```
tfx build tasks delete --task.id 801a3d7b-7182-4286-8b27-a13e3286551c
```