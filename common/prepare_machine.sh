###################################################
# Azure prepare machine script. 
#
# Currently the installation of the nodes in the 
# cluster is not automized. We need to run this 
# snippet on every node in the cluster.
###################################################

NODE=`hostname -s`
DOMAIN=`hostname -d`
PUB_KEY=" ____ PLACE KEY HERE ___ "

mkdir ~/.ssh
chmod 700 ~/.ssh
echo "$PUB_KEY" > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
restorecon -R -v ~/.ssh

echo "127.0.0.1   $NODE.$DOMAIN $NODE localhost localhost.localdomain localhost4 localhost4.localdomain4" > /etc/hosts
echo "::1   $NODE.$DOMAIN $NODE localhost localhost.localdomain localhost6 localhost6.localdomain6" >> /etc/hosts
