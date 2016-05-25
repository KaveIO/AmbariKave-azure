#!/bin/bash

echo "Check out:"
echo "/var/log/azure/Microsoft.OSTCExtensions.CustomScriptForLinux/1.4.1.0"
echo "for the logs."

echo "Test *without* redeploying, eg (as root):"
echo "cd /var/lib/waagent/Microsoft.OSTCExtensions.CustomScriptForLinux-1.4.1.0/download/0"
echo "/bin/bash ambarinode_setup.sh https://github.com/DataAnalyticsOrganization/AmbariKave-azure/archive/automate.zip KaveAdmin KavePassword01 'localhost ambari gate ci nno-0 nno-1 data-0 data-1 data-2' 2.0-Beta https://raw.githubusercontent.com/DataAnalyticsOrganization/AmbariKave-azure/automate/kave_blueprint/KAVEAzure.blueprint.json https://raw.githubusercontent.com/DataAnalyticsOrganization/AmbariKave-azure/automate/kave_blueprint/KAVEAzure.cluster.json"

echo "For Hadoop services Ambari provides a Run Service Check functionality. For the rest read on:"
echo "FreeIPA. The proper way would be http://www.freeipa.org/page/Testing but it does not work - a number of dependencies is not found."
echo "Archiva. Connect to the webapp on port 5050 and create the admin user. A simple smoke test is trying to get an arbitrary artifact like: http://localhost:5050/repository/internal/junit/junit/3.8.1/junit-3.8.1.jar."
echo "WIP...WIP"
