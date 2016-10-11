#!/bin/bash

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

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

REPOSITORY=$1
USER=$2
PASS=$3
HOSTS="localhost $4"
VERSION=$5
KAVE_BLUEPRINT_URL=$6
KAVE_CLUSTER_URL=$7
DESTDIR=${8:-contents}
SWAP_SIZE=${9:-10g}
WORKING_DIR=${10:-/root/kavesetup}
CLUSTER_NAME=${11:-cluster}

CURL_AUTH_COMMAND='curl --netrc -H X-Requested-By:KoASetup -X'
CLUSTERS_URL="http://localhost:8080/api/v1/clusters"
COMPONENTS_URL="$CLUSTERS_URL/$CLUSTER_NAME/hosts/<HOST>/host_components"

BLUEPRINT_TRIALS=5

function anynode_setup {
    chmod +x "$DIR/anynode_setup.sh"

    "$DIR/anynode_setup.sh" "$REPOSITORY" "$USER" "$PASS" "$DESTDIR" "$SWAP_SIZE" "$WORKING_DIR"
}

function csv_hosts {
    CSV_HOSTS=$(echo "$HOSTS" | tr ' ' ,)
}

function download_blueprint {
    local extension=.json.template
    local blueprint_filename=blueprint$extension
    local cluster_filename="$CLUSTER_NAME"$extension
    
    wget --tries=10 --read-timeout=60 -O "$WORKING_DIR/$blueprint_filename" "$KAVE_BLUEPRINT_URL"

    wget --tries=10 --read-timeout=60 -O "$WORKING_DIR/$cluster_filename" "$KAVE_CLUSTER_URL"

    KAVE_BLUEPRINT=$(readlink -e "$WORKING_DIR/$blueprint_filename")

    KAVE_CLUSTER=$(readlink -e "$WORKING_DIR/$cluster_filename")
}

function define_bindir {
    BIN_DIR=$WORKING_DIR/$DESTDIR/Automation/setup/bin
}

function distribute_keys {
    $BIN_DIR/distribute_keys.sh "$USER" "$PASS" "$HOSTS"
}

function customize_hosts {
    $BIN_DIR/create_hostsfile.sh "$WORKING_DIR" "$HOSTS"

    pdcp -w "$CSV_HOSTS" "$WORKING_DIR/hosts" /etc/hosts
}

function localize_cluster_file {
    $BIN_DIR/localize_cluster_file.sh "$KAVE_CLUSTER"
}

function initialize_blueprint {
    sed -e s/"<KAVE_ADMIN>"/"$USER"/g -e s/"<KAVE_ADMIN_PASS>"/"$PASS"/g "$KAVE_BLUEPRINT" > "${KAVE_BLUEPRINT%.*}"
}

function kave_install {
    $BIN_DIR/kave_install.sh "$VERSION" "$WORKING_DIR"
}

clean() {
	echo "y" | "$WORKING_DIR/AmbariKave-$VERSION/dev/clean.sh" 
}

function wait_for_ambari {
    cp "$BIN_DIR/../.netrc" ~
    local count=5
    while ! (curl --netrc -fs $CLUSTERS_URL) && test $count -ne 0; do
    		((count--))
		sleep 60
		echo "Waiting until ambari server is up and running..."
    done
    if [ $count -eq 0 ]; then 
		clean
    		kave_install
    		wait_for_ambari
    	fi
}

function patch_ambari {
    #The installation may just take too long on some nodes, the ci especially, therefore let's try to be even more generous on timeouts
    sed -i -e 's/agent.package.install.task.timeout=1800/agent.package.install.task.timeout=3600/' -e 's/agent.task.timeout=900/agent.task.timeout=3600/' /etc/ambari-server/conf/ambari.properties
    service ambari-server restart
}

function blueprint_deploy {
    #REST connection in deploy_from_blueprint.py can fail, so keep trying till success is reached
    local command="$BIN_DIR/blueprint_deploy.sh $VERSION ${KAVE_BLUEPRINT%.*} ${KAVE_CLUSTER%.*} $WORKING_DIR"
    # try for a while(), then backup plan
    local count=5

    while ! ($command) && test $count -ne 0; do 
		((count--))
		echo "Blueprint installation failed, retrying..."
		echo "DEBUG: count="$count
		sleep 15
    done
    # try to re-install ambari in case deployment was not successful
    if [ $count -eq 0 ] && [ $BLUEPRINT_TRIALS -ne 0 ]; then
		((BLUEPRINT_TRIALS--))
		echo "Blueprint deployment unsucessful. Reinstalling ambari server and retrying the deployment..."
		echo $BLUEPRINT_TRIALS" deployment trials remaining"
		#clean.sh is meant for the server, let's just run the two client commands separately 
		pdsh -w "$CSV_HOSTS" "service ambari-agent stop; yum -y erase ambari-agent"
		clean
		kave_install
		blueprint_deploy
	else
	    if [ $BLUEPRINT_TRIALS -ne 0 ]; then
		    echo "Blueprint deployment successful!"
		    return 0
		else
		    	(>&2 echo "It was not possible to deploy requested blueprint on your cluster. Please check if all machines in your cluster are running normally...")
		    	return 3
		fi
	fi
}

function wait_on_deploy {
	until wait_on_deploy_impl; do
		echo "Ambari tasks taking too long, restarting the Ambari cluster..."
		service ambari-server restart
		sleep 120
		pdsh -w "$CSV_HOSTS" "service ambari-agent restart"
		sleep 120
	done
}

wait_on_deploy_impl() {
#We proceed as soon as FreeIPA is installed, waiting for all tasks takes too much time, which means timeouts in Azure. FreeIPA only because that is the component we possibly fix manually in the code
#below. For the rest of the services, we do retry to install them if their installation status requires so, which is not the case when it is INSTALLING.
#We consider the cluster to be ready for connections when KaveLanding, so VNC, is installed too, but that is waited on by the gateway setup.	
    sleep 300
    local command="$CURL_AUTH_COMMAND"
    local count=150
    while ($command GET "$CLUSTERS_URL/$CLUSTER_NAME/requests?fields=Requests" 2> /dev/null | grep -10 FREEIPA | egrep "IN_PROGRESS|PENDING|QUEUED") && test $count -ne 0; do
    		((count--))
		sleep 15
		echo "Waiting for background tasks in Ambari to complete..."
    done
    test $count -ne 0
}

enable_kaveadmin() {
    sleep 60
    cat /root/admin-password | su admin -c kinit admin
    su admin -c "
        ipa user-mod $USER --password<<EOF
        $PASS
        $PASS
EOF" 
    #Let the changes sink into the whole ipa cluster...
    sleep 120
}

fix_freeipa_installation() {
	local retries=5
	local failed=false
    #The FreeIPA client installation may fail, among other things, because of TGT negotiation failure (https://fedorahosted.org/freeipa/ticket/4808). On the version we are now if this happens the installation is not retried. The idea is to check on all the nodes whether FreeIPA clients are good or not with a simple smoke test, then proceed to retry the installation. A lot of noise is involved, mainly because of Ambari's not-so-shiny API and Kave technicalities.
    #Should be fixed by upgrading the version of FreeIPA, but unfortunately this is far in the future.
    #It is important anyway that we start to check after the installation has been tried at least once on all the nodes, so let's check for the locks and sleep for a while anyway.
	#This approach sacrifices control in the name of failure rates, but Azure could definitely expose a customizable CSE timeout, or at least offer a way for us to say Don't terminate me, I'm still working hard.
    sleep 120
    count=5
    local kinit_pass_file=/root/admin-password
    local ipainst_lock_file=/root/ipa_client_install_lock_file
    while ! (pdsh -S -w "$CSV_HOSTS" "ls $ipainst_lock_file" && ls $kinit_pass_file 2>&-) && test $count -ne 0; do
		sleep 5
		((count--))
    done
    local kinit_pass=$(cat $kinit_pass_file)
    local pipe_hosts=$(echo "$CSV_HOSTS" | sed 's/localhost,\?//' | tr , '|')
    until local failed_hosts=$(pdsh -w "$CSV_HOSTS" "echo $kinit_pass | kinit admin" 2>&1 >/dev/null | sed -nr "s/($pipe_hosts): kinit:.*/\1.`hostname -d`/p" | tr '\n' , | head -c -1); test -z $failed_hosts; do
		if [ $retries -eq 0 ]; then
			(>&2 echo "FreeIPA reinstall retries exceeded, you will have to install the IPA client yourself on the following nodes: '$failed_hosts'. Skipping...")
			failed=true
			break
		fi
		((retries--))
		local command="$CURL_AUTH_COMMAND"
		local url="$COMPONENTS_URL/FREEIPA_CLIENT"
		pdsh -w "$failed_hosts" "rm -f $ipainst_lock_file; echo no | ipa-client-install --uninstall"
		pdcp -w "$failed_hosts" /root/robot-admin-password /root
		local target_hosts=($(echo $failed_hosts | tr , ' '))
		local install_request='{"RequestInfo":{"context":"Install"},"Body":{"HostRoles":{"state":"INSTALLED"}}}'
		local start_request=$(echo "$install_request" | sed -e "s/Install/Start/g" -e "s/INSTALLED/STARTED/g")
		for host in ${target_hosts[@]}; do
		    local host_url=$(echo $url | sed "s/<HOST>/$host/g")
		    $command DELETE $host_url
		    sleep 5
		    $command POST $host_url
		    sleep 5
		    $command PUT -d "$install_request" "$host_url"
		    sleep 5
		    $command PUT -d "$start_request" "$host_url"
		done
		sleep 50
    done
    if $failed; then return 3; fi
	return 0
}

function post_installation {
	fix_freeipa_installation
	enable_kaveadmin
	activate_all_services
	lock_root
}

activate_all_services() {
    for _ in `seq 1 15`; do
    		echo "Making sure all the services are active..."
		activate_all_services_impl
		sleep 45
    done
}

activate_all_services_impl() {
    #Sometimes Ambari just fails starting some services, mostly on the ci. Let's install and start as needed.
    local command=$CURL_AUTH_COMMAND
    for host in ${HOSTS[@]}; do
		if [ $host = localhost ]; then continue; fi
		local host=$host.`hostname -d`
		local host_url=$(echo $COMPONENTS_URL | sed "s/<HOST>/$host/g")
		local request="$command GET $host_url"
		local components=($($request | grep "component_name" | awk -F '"' '{print $4}'))
		for component in ${components[@]}; do
		    local check_response=$($request/$component)
	        local state=$(echo "$check_response" | grep "\"state\" :" | awk -F '"' '{print $4}')
		    if [ $state = INSTALLED -o $state = INSTALL_FAILED ]; then
				local service=$(echo "$check_response" | grep -m 1 "\"service_name\" :" | awk -F '"' '{print $4}')
				local operation_request_template='{"RequestInfo":{"context":"Start <SERVICE>","operation_level":{"level":"HOST_COMPONENT","cluster_name":"<CLUSTER_NAME>","host_name":"<HOST>","service_name":"<SERVICE>"}},"Body":{"HostRoles":{"state":"<STATE>"}}}'
				local operation_request=$(echo $operation_request_template | sed -e "s/<SERVICE>/$service/g" -e "s/<CLUSTER_NAME>/$CLUSTER_NAME/" -e "s/<HOST>/$host/")
				local operation_url="$host_url/$component/?"
				if [ $state = INSTALL_FAILED ]; then
					#Fixed in KAVE 2.1
					if [[ $service = *ARCHIVA* ]]; then pdsh -w "$CSV_HOSTS" "rm -rf /opt/archiva; rm -rf /etc/init.d/archiva"; fi
			    		local install_request=$(echo "$operation_request" | sed 's/<STATE>/INSTALLED/')
			    		$command PUT -d "$install_request" "$operation_url"
				fi
				sleep 5
				#Not sure about this, probably a bug in Archiva/Ambari
				if [[ $service = *ARCHIVA* ]]; then pdsh -w "$CSV_HOSTS" "mkdir -p /opt/archiva/conf"; fi
				local start_request=$(echo "$operation_request" | sed 's/<STATE>/STARTED/')
				$command PUT -d "$start_request" "$operation_url"
		    fi
		done
    done
}

lock_root() {
    pdsh -w "$CSV_HOSTS" "chsh -s /sbin/nologin"
}

anynode_setup

csv_hosts

download_blueprint

define_bindir

distribute_keys

customize_hosts

localize_cluster_file

initialize_blueprint

kave_install

wait_for_ambari

patch_ambari

blueprint_deploy

wait_on_deploy

post_installation &
