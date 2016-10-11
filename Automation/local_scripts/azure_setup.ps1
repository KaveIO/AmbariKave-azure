##############################################################################
#
# Copyright 2016 KPMG N.V. (unless otherwise stated)
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
##############################################################################

param(
	$template = "..\azure_template\KAVEAzure.azure.json",
	$parameters = "..\azure_template\KAVEAzure.azure.parameters.json",
	$region = "westeurope",
	$resource_group = "Kave-Test",
	$alias =  "KaveTest",
	$gateway = "gate"
)

azure config mode arm 

azure login

azure group create -n $resource_group -l $region

azure group deployment create -f $template -e $parameters -g $resource_group -n $alias

echo ---

echo "Gateway node info:"

azure vm show $resource_group $gate

echo ---

azure login

echo ---

echo "You can login onto the gateway using ssh; check the user in the JSON parameters file (eg KAVEAdminUserName/KAVEAdminPassword), that will log you in the rest of the boxes too"
