# Ambarikave-azure
In this repo we contain publishable azure deployments of the AmbariKave. These deployments can be run via their *Deploy to Azure* buttons or via the azure-cli.

Supported templates currently are: 

 - Hadoop + CI stack.

## Getting the azure-cli 
There are many ways to get the azure-cli. Just google it.. Options We've seen: 

 - windows powershell
 - windows command prompt
 - linux apt installation 

However docker is a great way to go as well. Install docker and go for: 

```bash
sudo docker run -it microsoft/azure-cli
```

If you don't use the docker image be sure to set the azure-cli mode to __arm__. This will make the cli communicate with the new API (which supports the templates). You can do this by doing: 

```bash
azure config mode arm 
```

## Deploying a template

```bash 
azure login 

azure group create -n Kave-Test -l "westeurope"

azure group deployment create -f <PathToTemplate> -e <PathToProperties> -g Kave-Test -n KaveTestDeployment
```

## Useful links WIP

https://github.com/Azure/azure-rest-api-specs
https://msdn.microsoft.com/en-us/library/azure/mt163564.aspx
https://github.com/Azure/azure-quickstart-templates
http://azureplatform.azurewebsites.net/


