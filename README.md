# Ambarikave-azure: the KAVE on Azure project

In this repo we contain a publishable azure deployment of the AmbariKave. This deployment will be published on the Azure Marketplace. The following will be deployed: 

 - HDP 2.4
 - KaveToolbox 
 - CI stack

This repository contains the source code necessary for the automated deployment of [KAVE](http://kave.io) on [Azure](https://azure.microsoft.com/). The solution is a one-click installable published on the [marketplace](https://azure.microsoft.com/en-us/marketplace/).

If you are looking for more deployable KAVE environments please refer to our [AmbariKave-azure-templates](https://github.com/KaveIO/AmbariKave-azure-templates) repository. There we have a list of various deployable environments which might suit different requirement. 


## For developers

A developer may be interested in starting the process from the command line, for better control and debug. This can be done by using the `azure_setup.ps1` PowerShell script. The [Azure CLI](https://azure.microsoft.com/en-us/documentation/articles/xplat-cli-install/) must be installed first.


### Useful links

 * [Azure REST API specs](https://github.com/Azure/azure-rest-api-specs) - this is very useful to read the definition of the latest API version for an entity and write compliant JSON requests for it
 
 * [Azure specs library](https://msdn.microsoft.com/en-us/library/azure/mt163564.aspx) - find here the detailed documentation of the API together with readymade REST calls by version
 
 * [Azure quickstart templates](https://github.com/Azure/azure-quickstart-templates) - this are very useful to learn how to deploy idiomatic clusters, together with the usage of a particular API version of the components it offers
 
 * [Atlas of the Azure platform](http://azureplatform.azurewebsites.net)
