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
    sed -r s/"<KAVE_ADMIN>"/"$USER"/g "$KAVE_BLUEPRINT" > "${KAVE_BLUEPRINT%.*}"
}

function kave_install {
    $BIN_DIR/kave_install.sh "$VERSION" "$WORKING_DIR"
}

function patch_ipa {
    #Install FreeIPA server and patch it; as this is a regular yum install Ambari will try to reinstall it but it will not be overwritten of course
    yum install -y ipa-server
    
    #Why this? In different parts of the code the common name (CN) is build concatenating the DNS domain name and the string "Certificate Authority", and in our case due to Azure long DNSDN the field ends up to be longer than 64 chars which is the RFC-defined standard maximum. This suffix is added as a naming convention, so we cannot just drop it, rather amend it.

    grep -IlR "Certificate Authority" /usr/lib/python2.6/site-packages/ipa* | xargs sed -i 's/Certificate Authority/CA/g'
    #To be fixed in FreeIPA (ideally, but it won't be the case)
    #To be fixed in KAVE (installation will refuse to continue if the total string "FQDN + "Certificate Authority" is longer than 64 OR it gives the option to apply this patch
}

function wait_for_ambari {
    cp "$BIN_DIR/../.netrc" ~
    until curl --netrc -fs http://localhost:8080/api/v1/clusters; do
	sleep 60
	echo "Waiting until ambari server is up and running..."
    done
}

function blueprint_deploy {
    $BIN_DIR/blueprint_deploy.sh "$VERSION" "${KAVE_BLUEPRINT%.*}" "${KAVE_CLUSTER%.*}" "$WORKING_DIR"

    # The installation will take quite a while. We'll sleep for a bit before we even start checking the installation status. This lets us be certain that the installation is well under way. 
    sleep 600

    while installation_status && [ $INSTALLATION_STATUS = "working" ] ;  do
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

function patch_hue() {
    #We want to be able to login as 'kaveadmin' in a PAM-enabled Hue, then we need to execute the server as root. It appears there is no way to arrange this in the configuration with the Hue version Ambari pulls so we have to amend the init.d script.
    #To be fixed in Kave probably, anyway we have other authentication options. If we want to run hueserver as hue and not root then we need to change the password of the hue user.
    local baseurl="http://localhost:8080/api/v1/clusters/cluster/services/HUE"
    until curl --netrc -fs $baseurl; do
        sleep 60
        echo "Waiting until Hue is up and running..."
    done
    huenode=$(curl --netrc $baseurl/components/HUE_SERVER?fields=host_components/HostRoles/host_name | grep -w \"host_name\" | cut -d ":" -f 2-)
    ssh $huenode "sed -i 's/USER=hue/USER=root/g' /etc/init.d/hue; service hue restart"
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

patch_ipa

wait_for_ambari

blueprint_deploy

patch_hue
