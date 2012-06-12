Riak CS Quick Install
=====================

Below are instructions on how to install a test cluster for Riak CS.  This guide does not cover system/service tuning,
nor does it attempt to optimize your installation given your particular architecture.

The steps listed in this guide are automated in the install-cs.sh script.

Installing your first node
--------------------------

**Step 1: Raise your ulimit**

Riak can consume a large number of open file handles during normal operation. [http://wiki.basho.com/Open-Files-Limit.html]

If you are the root user, you can increase the ulimit in the current session by typing:

    $ ulimit -n 65536

We also need to save this setting for the root and riak users in `/etc/security/limits.conf`

    # ulimit settings for Riak CS
    root soft nofile 65536
    root hard nofile 65536
    riak soft nofile 65536
    riak hard nofile 65536


**Step 2: Download and install packages**

This guide uses `curl` for downloading packages and interacting with the Riak CS API so let's make sure it's installed:

    $ sudo apt-get install -y curl
    
If you are running Ubuntu 11.10 or later, you will also need the `libssl0.9.8` package [http://wiki.basho.com/Installing-on-Debian-and-Ubuntu.html]

    $ sudo apt-get install -y libssl0.9.8
    
Now let's grab the Riak and Riak CS packages.  Since this is our first node, we'll also be installing Stanchion.

First we download and install Riak:

RHEL6:

    $ curl -s -O http://s3.amazonaws.com/private.downloads.basho.com/riak_ee/5fp9c2/1.1.2/riak-ee-1.1.2-1.el6.x86_64.rpm
    $ rpm -Uvh riak-ee-1.1.2-1.el6.x86_64.rpm
    
Ubuntu Lucid:

    $ curl -s -O http://s3.amazonaws.com/private.downloads.basho.com/riak_ee/5fp9c2/1.1.2/riak-ee_1.1.2-1_amd64.deb
    $ sudo dpkg -i riak-ee_1.1.2-1_amd64.deb
    
Next is Riak CS:

RHEL6:

    $ curl -s -O http://s3.amazonaws.com/private.downloads.basho.com/riak-cs/13c531/1.0.1/rhel/6/riak-cs-1.0.1-1.el6.x86_64.rpm
    $ rpm -Uvh riak-cs-1.0.1-1.el6.x86_64.rpm
    
Ubuntu Lucid:

    $ curl -s -O http://s3.amazonaws.com/private.downloads.basho.com/riak-cs/13c531/1.0.1/ubuntu/lucid/riak-cs_1.0.1-1_amd64.deb
    $ sudo dpkg -i riak-cs_1.0.1-1_amd64.deb 
    
And finally Stanchion:

RHEL 6:

    $ curl -s -O http://s3.amazonaws.com/private.downloads.basho.com/stanchion/5bd9d7/1.0.1/rhel/6/stanchion-1.0.1-1.el6.x86_64.rpm
    $ sudo rpm -Uvh stanchion-1.0.1-1.el6.x86_64.rpm
    
Ubuntu Lucid:

    $ curl -s -O http://s3.amazonaws.com/private.downloads.basho.com/stanchion/5bd9d7/1.0.1/ubuntu/lucid/stanchion_1.0.1-1_amd64.deb
    $ sudo dpkg -i stanchion_1.0.1-1_amd64.deb


**Step 3: Set service configurations and start the services**
 
First, Riak ships with Bitcask as the default backend.  We need to change this to the Riak CS custom backend.

Change the following line in `/etc/riak/app.config`

    {storage_backend, riak_kv_bitcask_backend}

to

    {add_paths, ["/usr/lib64/riak-cs/lib/riak_moss-1.0.1/ebin"]},
    {storage_backend, riak_cs_kv_multi_backend},
    {multi_backend_prefix_list, [{<<"0b:">>, be_blocks}]},
    {multi_backend_default, be_default},
    {multi_backend, [
        {be_default, riak_kv_eleveldb_backend, [
            {max_open_files, 50},
            {data_root, "/var/lib/riak/leveldb"}
        ]},
        {be_blocks, riak_kv_bitcask_backend, [
            {data_root, "/var/lib/riak/bitcask"}
        ]}
    ]},


Next, we set our interface IPs in the app.config files.  In a production environment, you will likely have multiple
NICs, but for this test cluster, we are going to assume one NIC with an example IP of 10.0.2.10

Change the following lines in `/etc/riak/app.config`

    {http, [ {"127.0.0.1", 8098 } ]}
    {pb_ip,   "127.0.0.1" }
    
to

    {http, [ {"10.0.2.10", 8098 } ]}
    {pb_ip,   "10.0.2.10" }


Change the following lines in `/etc/riak-cs/app.config`

    {moss_ip, "127.0.0.1"}
    {riak_ip, "127.0.0.1"}
    {stanchion_ip, "127.0.0.1"}
    
to

    {moss_ip, "10.0.2.10"}
    {riak_ip, "10.0.2.10"}
    {stanchion_ip, "10.0.2.10"}


The moss_ip could also be set to 0.0.0.0 if you prefer Riak CS to listen on all interfaces.


Change the following lines in `/etc/stanchion/app.config`

    {stanchion_ip, "127.0.0.1"}
    {riak_ip, "127.0.0.1"}
    
to 

    {stanchion_ip, "10.0.2.10"}
    {riak_ip, "10.0.2.10"}


Next, we set our service names.  You can either use the local IP for this or set hostnames.  If you choose to set 
hostnames, you will need to register that hostname in DNS or set it in `/etc/hosts` on all nodes.

**Note:** Service names require at least one period in the name.

Change the following line in `/etc/riak/vm.args`

    -name riak@127.0.0.1
    
to

    -name riak@10.0.2.10
    
  
Change the following line in `/etc/riak-cs/vm.args`

    -name riak-cs@127.0.0.1
    
to

    -name riak-cs@10.0.2.10
    
  
Change the following line in `/etc/stanchion/vm.args`

    -name stanchion@127.0.0.1
    
to

    -name stanchion@10.0.2.10

    
That is the minimum amount of service configuration required to start a complete node.  To start the services, type:

    $ sudo riak start
    $ sudo stanchion start
    $ sudo riak-cs start
    
The order in which you start the services is important as each is a dependency for the next.

  
**Step 4: Create the admin user**

Creating the admin user is an optional step, but it's a good test of our new services.  Creating a Riak CS user requires
two inputs:
1.  Name - a URL encoded string.  Example: "admin%20user"
2.  Email - a unique email address.  Example: "admin@admin.com"
         
We can create the admin user with the following `curl` command:

    curl -s http://10.0.2.10:8080/user --data "name=admin%20user&email=admin@admin.com"
    
The output of this command will be a JSON object that looks like this:

    {"email":"admin@admin.com","display_name":"admin","name":"admin user","key_id":"5N2STDSXNV-US8BWF1TH","key_secret":"RF7WD0b3RjfMK2cTaPfLkpZGbPDaeALDtqHeMw==","id":"4b823566a2db0b7f50f59ad5e43119054fecf3ea47a5052d3c575ac8f990eda7"}
        
The user's access key and secret key are returned in the `key_id` and `key_secret` fields respectively.
In this case, those keys are:

    Access key: 5N2STDSXNV-US8BWF1TH
    Secret key: RF7WD0b3RjfMK2cTaPfLkpZGbPDaeALDtqHeMw==
    
You can use this same process to create additional Riak CS users.  To make this user the admin user, we set these 
keys in the Riak CS and Stanchion `app.config` files.  

**Note:** The same admin keys will need to be set on all nodes of the cluster.

Change the following lines in `/etc/riak-cs/app.config`

    {admin_key, "admin-key"}
    {admin_secret, "admin-secret"}
    
to

    {admin_key, "5N2STDSXNV-US8BWF1TH"}
    {admin_secret, "RF7WD0b3RjfMK2cTaPfLkpZGbPDaeALDtqHeMw=="}
    
  
Change the following lines in `/etc/stanchion/app.config`

    {admin_key, "admin-key"}
    {admin_secret, "admin-secret"}
    
to

    {admin_key, "5N2STDSXNV-US8BWF1TH"}
    {admin_secret, "RF7WD0b3RjfMK2cTaPfLkpZGbPDaeALDtqHeMw=="}


Now we have to restart the services for the change to take effect:

    $ sudo stanchion restart
    $ sudo riak-cs restart
    
**Step 5: Testing the installation**

The simplest way to test the installation is using the `s3cmd` script.  We can install it by typing:

    $ sudo apt-get -y install s3cmd

We need to configure `s3cmd` to use our Riak CS server rather than S3 as well as our user keys.  To do that interactively,
type:

    $ s3cmd --configure
    
There are only 4 options you need to change from the defaults:

* Access Key - use the Riak CS user access key you generated above.
* Secret Key - use the Riak CS user secret key you generated above.
* Proxy Server - use your Riak CS IP.  Example: 10.0.2.10
* Proxy Port - the default Riak CS port is 8080

Once `s3cmd` is configured, we can use it to create a test bucket:

    $ s3cmd mb s3://test_bucket

We can see if it was created by typing:

    $ s3cmd ls
    
We can now upload a test file to that bucket:

    $ dd if=/dev/zero of=test_file bs=1M count=2 # Create a test file
    $ s3cmd put test_file s3://test_bucket
    
We can see if it was uploaded by typing:

    $ s3cmd ls s3://test_bucket
    
We can now download the test file:

    $ rm test_file # remove the local test file
    $ s3cmd get s3://test_bucket/test_file

  
Installing additional nodes
---------------------------

The process for installing additional nodes is identical to your first node with two exceptions:

1.  Stanchion only needs to live on your first node, so no need to install it again.  The `stanchion_ip` setting in your
    Riak CS `app.config` files should be set to the `stanchion_ip` from your first node.
2.  To add additional nodes to the Riak cluster, use the following command:

        $ sudo riak-admin join riak@10.0.2.10
    
    Where `riak@10.0.2.10` is the Riak node name set in your first node's `/etc/riak/vm.args` file
