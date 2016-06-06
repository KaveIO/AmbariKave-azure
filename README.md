# Ambarikave-azure: the KAVE on Azure project

In this repo we contain publishable azure deployments of the AmbariKave. These deployments can be run via their *Deploy to Azure* buttons or via the azure-cli.

Supported templates currently are: 

 - Hadoop + CI stack.

## Overview

This repository contains the source code necessary for the automated deployment of [KAVE](http://kave.io) on [Azure](https://azure.microsoft.com/). The solution is a one-click installable published on the [marketplace](https://azure.microsoft.com/en-us/marketplace/).

The environment is provisionable via a provision button; visualization is one click away too: 

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2KaveIO%2AmbariKave-azure%2master%2Artifacts%2MainTemplate.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2KaveIO%2AmbariKave-azure%2master%2Artifacts%2MainTemplate.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

This is the official way for automated developments on Azure.

There are two phases:

 * Azure provisioning
 * KAVE installation

An Azure cluster is created automatically by clicking on the provision button. The installation of KAVE is automated as well, and it is triggered on the cluster thanks to the CustomScript extension.


## For developers

A developer may be interested in starting the process from the command line, for better control and debug. This can be done by using the `azure_setup.ps1` PowerShell script. The [Azure CLI](https://azure.microsoft.com/en-us/documentation/articles/xplat-cli-install/) must be installed first.


## Useful links

 * [Azure REST API specs](https://github.com/Azure/azure-rest-api-specs) - this is very useful to read the definition of the latest API version for an entity and write compliant JSON requests for it
 
 * [Azure specs library](https://msdn.microsoft.com/en-us/library/azure/mt163564.aspx) - find here the detailed documentation of the API together with readymade REST calls by version
 
 * [Azure quickstart templates](https://github.com/Azure/azure-quickstart-templates) - this are very useful to learn how to deploy idiomatic clusters, together with the usage of a particular API version of the components it offers
 
 * [Atlas of the Azure platform](http://azureplatform.azurewebsites.net)
