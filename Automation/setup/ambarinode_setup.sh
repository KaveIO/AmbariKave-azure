#!/bin/bash

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
SERVICES_URL="http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/services"

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
    
    wget -O "$WORKING_DIR/$blueprint_filename" "$KAVE_BLUEPRINT_URL"

    wget -O "$WORKING_DIR/$cluster_filename" "$KAVE_CLUSTER_URL"

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

function wait_for_ambari {
    cp "$BIN_DIR/../.netrc" ~
    until curl --netrc -fs http://localhost:8080/api/v1/clusters; do
	sleep 60
	echo "Waiting until ambari server is up and running..."
    done
}

function patch_ambari {
    #The installation may just take too long on some nodes, the ci especially, therefore let's try to be even more generous on timeouts
    sed -i -e 's/agent.package.install.task.timeout=1800/agent.package.install.task.timeout=3600/' -e 's/agent.task.timeout=900/agent.task.timeout=3600/' /etc/ambari-server/conf/ambari.properties
    service ambari-server restart
}

function blueprint_deploy {
    $BIN_DIR/blueprint_deploy.sh "$VERSION" "${KAVE_BLUEPRINT%.*}" "${KAVE_CLUSTER%.*}" "$WORKING_DIR"
}

function installation_status {
    local installation_status_message=$(curl --netrc "http://localhost:8080/api/v1/clusters/cluster/?fields=alerts_summary/*" 2> /dev/null)
    local exit_status=$?

    if [ $exit_status -ne 0 ]; then
        return $exit_status
    else
        if [[ "$installation_status_message" =~ "\"CRITICAL\" : 0" ]]; then
            INSTALLATION_STATUS="done"
        else
            INSTALLATION_STATUS="working"
        fi
        return 0
    fi
}

function enable_kaveadmin {
    sleep 60
    cat /root/admin-password | su admin -c kinit admin
    su admin -c "
        ipa user-mod kaveadmin --password<<EOF
        $PASS
        $PASS
EOF" 
    #Let the changes sink into the whole ipa cluster...
    sleep 180
}

function check_installation {
    # The installation will take quite a while. We'll sleep for a bit before we even start checking the installation status. This lets us be certain that the installation is well under way.
    while installation_status && [ $INSTALLATION_STATUS = "working" ] ; do
	echo $INSTALLATION_STATUS
	sleep 5
    done

    if [ "$INSTALLATION_STATUS" = "done" ]; then
	echo "No Criticals detected. The installation appears to be successful!"
    else
	echo "Installation loop broken, installation possibly failed. Exiting."
	exit 255
    fi
}

function fix_freeipa_installation {
    #The FreeIPA client installation may fail, among other things, because of TGT negotiation failure (https://fedorahosted.org/freeipa/ticket/4808). On the version we are now if this happens the installation is not retried. The idea is to check on all the nodes whether FreeIPA clients are good or not with a simple smoke test, then proceed to retry the installation. A lot of noise is involved, mainly because of Ambari's not-so-shiny API and Kave technicalities.
    #Should be fixed by upgrading the version of FreeIPA, but unfortunately this is far in the future.
    #It is important anyway that we start to check after the installation has been tried at least once on all the nodes, so let's check for the locks and sleep for a while anyway.
    sleep 500
    count=50
    local kinit_pass_file=/root/admin-password
    until (pdsh -S -w "$CSV_HOSTS" "ls /root/ipa_client_install_lock_file" && ls $kinit_pass_file 2>&-) || test $count -eq 0; do
	sleep 10
	((count--))
    done
    sleep 500
    local kinit_pass=$(cat $kinit_pass_file)
    local pipe_hosts=$(echo "$CSV_HOSTS" | sed 's/localhost,\?//' | tr , '|')
    until local failed_hosts=$(pdsh -w "$CSV_HOSTS" "echo $kinit_pass | kinit admin" 2>&1 >/dev/null | sed -nr "s/($pipe_hosts): kinit:.*/\1.`hostname -d`/p" | tr '\n' , | head -c -1); test -z $failed_hosts; do
	local command="$CURL_AUTH_COMMAND"
	local url="http://localhost:8080/api/v1/clusters/$CLUSTER_NAME/hosts/<HOST>/host_components/FREEIPA_CLIENT"
	pdsh -w "$failed_hosts" "rm -f /root/ipa_client_install_lock_file; echo no | ipa-client-install --uninstall"
	pdcp -w "$failed_hosts" /root/robot-admin-password /root
	local target_hosts=($(echo $failed_hosts | tr , ' '))
	local install_request='{"RequestInfo":{"context":"Install"},"Body":{"HostRoles":{"state":"INSTALLED"}}}'
	local start_request=$(echo "$install_request" | sed -e "s/Install/Start/g" -e "s/INSTALLED/STARTED/g")
	for host in ${target_hosts[@]}; do
	    local host_url=$(echo $url | sed "s/<HOST>/$host/g")
	    $command DELETE $host_url
	    sleep 10
	    $command POST $host_url
	    sleep 10
	    $command PUT -d "$install_request" "$host_url"
	    sleep 10
	    $command PUT -d "$start_request" "$host_url"
	done
	sleep 150
    done
}

function lock_root {
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

check_installation

fix_freeipa_installation

enable_kaveadmin

lock_root
