#!/bin/bash

# This script must be run as root
if [ ! $(id -u) -eq 0 ]; then echo "This script must be run as root."; exit; fi

#----------------------------------------------------------------------
# initialize
#----------------------------------------------------------------------

CLEAN=FALSE
RHEL=FALSE

INSTALL_RIAKCS="y"
INSTALL_HAPROXY="n"
INSTALL_STANCHION="y"

CREATE_ADMIN_USER="y"
CREATE_NORMAL_USER="y"

TMP_DIR="/tmp/riak-cs_inst"

ADMIN_NAME="admin"
ADMIN_EMAIL="admin@basho.com"
USER_NAME="user1"
USER_EMAIL="user1@basho.com"

ADMIN_KEY=""
ADMIN_SECRET=""

LOCAL_IP=`ifconfig $(ip route | grep default | awk '{ print $5 }') | sed -n '/inet /{s/.*addr://;s/ .*//;p}'`
RIAK_IP=$LOCAL_IP
STANCHION_IP=$LOCAL_IP
RIAKCS_IP=$LOCAL_IP

if [ -e /etc/redhat-release ]; then RHEL=TRUE; fi


#----------------------------------------------------------------------
# common functions
#----------------------------------------------------------------------

ask_user() {
  local message=$1
  local default=$2
  local received_input=""

  read -p "${message} [${default}]: " received_input
  echo ${received_input:=$default}
}

#----------------------------------------------------------------------
# populate values from command line options
#----------------------------------------------------------------------

while getopts ":c" opt; do
  case $opt in
    c) CLEAN=TRUE;;
  esac
done

#----------------------------------------------------------------------
# read installation options from user 
#----------------------------------------------------------------------

INSTALL_RIAKCS=$(ask_user "Install Riak CS (y/n)" $INSTALL_RIAKCS)
INSTALL_STANCHION=$(ask_user "Install Stanchion (y/n)" $INSTALL_STANCHION)

if [ RHEL == FALSE ]
then
  INSTALL_HAPROXY=$(ask_user "Install HAProxy (y/n)" $INSTALL_HAPROXY)
fi

#----------------------------------------------------------------------
# cleanup or leave old data
#----------------------------------------------------------------------

if [ $CLEAN == TRUE ] 
then
  cp $TMP_DIR/limits.conf /etc/security/limits.conf
  rm -rf $TMP_DIR
  killall -u riak
  
  if [ $RHEL == TRUE ]
  then
    rpm -e --quiet stanchion 2>&1 > /dev/null
    rpm -e --quiet riak-ee 2>&1 > /dev/null
    rpm -e --quiet riak-cs 2>&1 > /dev/null
    rm -rf /var/lib/riak /var/lib/riak-cs
  else
    apt-get -qq purge stanchion > /dev/null
    apt-get -qq purge riak-ee > /dev/null
    apt-get -qq purge riak-cs > /dev/null
    apt-get -qq purge haproxy > /dev/null
  fi
fi

#----------------------------------------------------------------------
# create backups 
#----------------------------------------------------------------------

mkdir -p $TMP_DIR

if [ ! -f $TMP_DIR/limits.conf ]; then cp /etc/security/limits.conf $TMP_DIR/; fi

#----------------------------------------------------------------------
# set system configurations 
#----------------------------------------------------------------------

# Increase ulimit for required users
echo "Setting ulimit to 65536"
ulimit -n 65536

if [ $INSTALL_RIAKCS == "y" ]
then
  echo "
  # ulimit settings for Riak CS
  root soft nofile 65536
  root hard nofile 65536
  riak soft nofile 65536
  riak hard nofile 65536" >> /etc/security/limits.conf
fi

if [ $INSTALL_HAPROXY == "y" ]
then
  echo "
  haproxy soft nofile 65536
  haproxy hard nofile 65536" >> /etc/security/limits.conf
fi

#----------------------------------------------------------------------
# download and install required packages 
#----------------------------------------------------------------------

# We use curl in this script to download binaries and later to test services
if [ ! -x /usr/bin/curl ]
then 
  echo "Installing cURL dependency..."
  if [ $RHEL == TRUE ]
  then
    yum install curl
  else
    apt-get -qq install curl
  fi
fi

# Riak requires libssl0.9.8 which is not included by default on Ubuntu
# versions later than 11.04
if [ $RHEL == FALSE ]
then
  if [ $(lsb_release -rs | tr -d '.') -gt 1104 ]
  then 
    echo "Installing libssl0.9.8 dependency..."
    apt-get -qq install libssl0.9.8
  fi
fi

cd $TMP_DIR

if [ $INSTALL_RIAKCS == "y" ]
then
  if [ $RHEL == TRUE ]
  then
    echo "Downloading Riak EDS package..."
    curl -s -O http://s3.amazonaws.com/private.downloads.basho.com/riak_ee/5fp9c2/1.1.4/riak-ee-1.1.4-1.el6.x86_64.rpm 
  
    echo "Installing Riak EDS package..."
    rpm -Uvh riak-ee-1.1.4-1.el6.x86_64.rpm

    echo "Downloading Riak CS package..."
    curl -s -O http://s3.amazonaws.com/private.downloads.basho.com/riak-cs/13c531/1.0.2/rhel/6/riak-cs-1.0.2-1.el6.x86_64.rpm 
 
    echo "Installing Riak CS package..."
    rpm -Uvh riak-cs-1.0.2-1.el6.x86_64.rpm
  else
    echo "Downloading Riak EDS package..."
    curl -s -O http://s3.amazonaws.com/private.downloads.basho.com/riak_ee/5fp9c2/1.1.4/riak-ee_1.1.4-1_amd64.deb

    echo "Installing Riak EDS package..."
    dpkg -i riak-ee_1.1.4-1_amd64.deb > /dev/null

    echo "Downloading Riak CS package..."
    curl -s -O http://s3.amazonaws.com/private.downloads.basho.com/riak-cs/13c531/1.0.2/ubuntu/natty/riak-cs_1.0.2-1_amd64.deb 

    echo "Installing Riak CS package..."
    dpkg -i riak-cs_1.0.2-1_amd64.deb > /dev/null
  fi
fi

if [ $INSTALL_STANCHION == "y" ]
then
  if [ $RHEL == TRUE ]
  then
    echo "Downloading Stanchion package..."
    curl -s -O http://s3.amazonaws.com/private.downloads.basho.com/stanchion/5bd9d7/1.0.1/rhel/6/stanchion-1.0.1-1.el6.x86_64.rpm

    echo "Installing Stanchion package..."
    rpm -Uvh stanchion-1.0.1-1.el6.x86_64.rpm > /dev/null 
  else
    echo "Downloading Stanchion package..."
    curl -s -O http://s3.amazonaws.com/private.downloads.basho.com/stanchion/5bd9d7/1.0.1/ubuntu/lucid/stanchion_1.0.1-1_amd64.deb

    echo "Installing Stanchion package..."
    dpkg -i stanchion_1.0.1-1_amd64.deb > /dev/null 
  fi
fi

if [ $INSTALL_HAPROXY == "y" ]
then
  echo "Installing HAProxy package..."

  if [ $RHEL == TRUE ]
  then
    yum install haproxy
  else
    apt-get -qq install haproxy
  fi
fi

#----------------------------------------------------------------------
# set service configurations and start the services  
#----------------------------------------------------------------------

# $RIAK_IP and $STANCHION_IP are set in both the CS and Stanchion configs
# $RIAKCS_IP is only set for CS.
# The IP or hostname set in vm.args MUST contain at least one period (.)

if [ $INSTALL_RIAKCS == "y" ] || [ $INSTALL_STANCHION == "y" ]
then
  RIAK_IP=$(ask_user "Riak IP" $RIAK_IP)
  STANCHION_IP=$(ask_user "Stanchion IP" $STANCHION_IP)
fi

if [ $INSTALL_RIAKCS == "y" ]
then
  RIAKCS_IP=$(ask_user "Riak CS IP" $RIAKCS_IP)

  echo "Setting Riak CS custom backend in Riak EDS app.config..."
  perl -pi -e "s/{storage_backend, riak_kv_bitcask_backend},/{add_paths, \[\"\/usr\/lib\/riak-cs\/lib\/riak_moss-1.0.2\/ebin\"\]},\n\t\t{storage_backend, riak_cs_kv_multi_backend},\n\t\t{multi_backend_prefix_list, \[{<<\"0b:\">>, be_blocks}\]},\n\t\t{multi_backend_default, be_default},\n\t\t{multi_backend, \[\n\t\t\t{be_default, riak_kv_eleveldb_backend, \[\n\t\t\t\t{max_open_files, 50},\n\t\t\t\t{data_root, \"\/var\/lib\/riak\/leveldb\"}\n\t\t\t\]},\n\t\t\t{be_blocks, riak_kv_bitcask_backend, \[\n\t\t\t\t{data_root, \"\/var\/lib\/riak\/bitcask\"}\n\t\t\t\]}\n\t\t\]\n\t    },/g" /etc/riak/app.config

  echo "Updating IPs in Riak EDS and Riak CS app.config and vm.args files..."
  perl -pi -e "s/{moss_ip, \"127.0.0.1\"}/{moss_ip, \"${RIAKCS_IP}\"}/g" /etc/riak-cs/app.config
  perl -pi -e "s/{riak_ip, \"127.0.0.1\"}/{riak_ip, \"${RIAK_IP}\"}/g" /etc/riak-cs/app.config
  perl -pi -e "s/{stanchion_ip, \"127.0.0.1\"}/{stanchion_ip, \"${STANCHION_IP}\"}/g" /etc/riak-cs/app.config

  perl -pi -e "s/{http, \[ {\"127.0.0.1\", 8098 } \]}/{http, \[ {\"${RIAK_IP}\", 8098 } \]}/g" /etc/riak/app.config
  perl -pi -e "s/{pb_ip,   \"127.0.0.1\" }/{pb_ip, \"${RIAK_IP}\"}/g" /etc/riak/app.config

  perl -pi -e "s/127.0.0.1/${RIAK_IP}/g" /etc/riak/vm.args
  perl -pi -e "s/127.0.0.1/${RIAKCS_IP}/g" /etc/riak-cs/vm.args
fi

if [ $INSTALL_STANCHION == "y" ]
then
  echo "Updating IPs in Stanchion app.config and vm.args files..."
  perl -pi -e "s/{stanchion_ip, \"127.0.0.1\"}/{stanchion_ip, \"${STANCHION_IP}\"}/g" /etc/stanchion/app.config
  perl -pi -e "s/{riak_ip, \"127.0.0.1\"}/{riak_ip, \"${RIAK_IP}\"}/g" /etc/stanchion/app.config

  perl -pi -e "s/127.0.0.1/${STANCHION_IP}/g" /etc/stanchion/vm.args
fi

# Start the services
if [ $INSTALL_RIAKCS == "y" ]
then
  echo "Starting Riak EDS..."
  riak start

  # Stanchion needs to be running BEFORE RiakCS since it tries to connect
  if [ $INSTALL_STANCHION == "y" ]
  then
    echo "Starting Stanchion..."
    stanchion start
  fi 

  echo "Starting Riak CS..."
  riak-cs start

  # Give the service(s) some time to start up
  sleep 5
elif [ $INSTALL_STANCHION == "y" ]
then
  echo "Starting Stanchion..."
  stanchion start

  # Give the service some time to start up
  sleep 5
fi 

if [ $INSTALL_HAPROXY == "y" ]
then
  echo "Starting HAProxy..."
  /etc/init.d/haproxy start
fi

#----------------------------------------------------------------------
# create the admin user
#----------------------------------------------------------------------

if [ $INSTALL_RIAKCS == "y" ]
then
  CREATE_ADMIN_USER=$(ask_user "Create admin user (y/n)" $CREATE_ADMIN_USER)

  if [ $CREATE_ADMIN_USER == "y" ]
  then
    ADMIN_NAME=$(ask_user "Admin name" $ADMIN_NAME)
    ADMIN_EMAIL=$(ask_user "Admin email address" $ADMIN_EMAIL)

    echo "Creating the admin user..."
    sleep 10
    KEYS=`curl -s http://${LOCAL_IP}:8080/user --data "name=${ADMIN_NAME}&email=${ADMIN_EMAIL}" | tr -s ',' '\n' | grep key_ | cut -f2 -d ':' | tr -d '"'`
    ADMIN_KEY=`echo $KEYS | cut -f1 -d ' '`
    ADMIN_SECRET=`echo $KEYS | cut -f2 -d ' '`

    echo
    echo "!!********************************************************************************!!"
    echo "The following keys must be set in the Riak CS and Stanchion app.config of all nodes:"
    echo "Admin access key: ${ADMIN_KEY}"
    echo "Admin secret key: ${ADMIN_SECRET}"
    echo "!!********************************************************************************!!"
    echo
  fi
fi

# If the user has elected to install CS or Stanchion, but didn't create an admin user
# then we have to ask for an existing set of keys
if [ $INSTALL_RIAKCS == "y" -o $INSTALL_STANCHION == "y" ] && [ -z $ADMIN_KEY ]
then
    ADMIN_KEY=$(ask_user "Enter admin access key" $ADMIN_KEY)
    ADMIN_SECRET=$(ask_user "Enter admin secret key" $ADMIN_SECRET)
fi

if [ $INSTALL_RIAKCS == "y" ]
then
  echo "Setting the admin user keys in the Riak CS app.config..."
  perl -pi -e "s/admin-key/${ADMIN_KEY}/g" /etc/riak-cs/app.config
  perl -pi -e "s/admin-secret/${ADMIN_SECRET}/g" /etc/riak-cs/app.config
  echo "Restarting Riak CS..."
  riak-cs restart
  sleep 5
fi

if [ $INSTALL_STANCHION == "y" ]
then
  echo "Setting the admin user keys in the Stanchion app.config..."
  perl -pi -e "s/admin-key/${ADMIN_KEY}/g" /etc/stanchion/app.config
  perl -pi -e "s/admin-secret/${ADMIN_SECRET}/g" /etc/stanchion/app.config
  echo "Restarting Stanchion..."
  stanchion restart
  sleep 5
fi

#----------------------------------------------------------------------
# create a normal user
#----------------------------------------------------------------------

if [ $INSTALL_RIAKCS == "y" ]
then
  CREATE_NORMAL_USER=$(ask_user "Create normal user (y/n)" $CREATE_NORMAL_USER)

  if [ $CREATE_NORMAL_USER = "y" ]
  then
    USER_NAME=$(ask_user "Normal user name" $USER_NAME)
    USER_EMAIL=$(ask_user "Normal user email address" $USER_EMAIL)

    echo "Creating the normal user..."
    KEYS=`curl -s http://${LOCAL_IP}:8080/user --data "name=${USER_NAME}&email=${USER_EMAIL}" | tr -s ',' '\n' | grep key_ | cut -f2 -d ':' | tr -d '"'`
    USER_KEY=`echo $KEYS | cut -f1 -d ' '`
    USER_SECRET=`echo $KEYS | cut -f2 -d ' '`

    echo
    echo "User access key: ${USER_KEY}"
    echo "User secret key: ${USER_SECRET}"
    echo
  fi
fi


#----------------------------------------------------------------------
# post-install instructions for the user
#----------------------------------------------------------------------

echo "

Post-Install Instructions:

1). Make sure all Riak CS and Stanchion nodes have the admin access key and
    secret key set.  You will need to restart the services after setting them. 

2). To join this node to a cluster, type:

    $ riak-admin join riak@<other cluster node's name> 

3). If you are using HAProxy as a load balancer, you can add all Riak CS 
    nodes to the HAProxy configuration like this:
      listen riak 10.0.0.1:8087
        server riak1 riak1:8087 weight 1 maxconn 1000
        server riak2 riak2:8087 weight 1 maxconn 1000
        server riak3 riak3:8087 weight 1 maxconn 1000

4). The easiest way to test your new Riak CS installation is with s3cmd. 
    Once s3cmd is installed, you can configure it by typing:

    $ s3cmd --configure

    There are 4 important configuration options:
      1. Access Key - output by this setup script
      2. Secret Key - output by this setup script
      3. Proxy Server - either your load balancer or the local server's IP
      4. Proxy Port - either your load balancer's port or 8080 for local testing 

    After configuring s3cmd, you can test bucket creation by typing:

    $ s3cmd mb s3://test_bucket

"

