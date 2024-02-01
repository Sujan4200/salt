Reference : https://medium.com/@mickeyschwarz789/the-basics-of-salt-822a12909892
Once connected, first you will need to install a package called apt-transport-https which will enable you to then grab the public key for the Salt repository using wget. If using wget doesn’t work (have had issues with downloading this specific key on multiple occasions) you can download the key file using curl. This key is required as it authenticates the apt package download from the repository. Additionally, the repository will need to be added to apt by creating a new .list file located at /etc/apt/sources.list.d/saltstack.list. Update apt and install the salt-master package. Note: the italicized code blocks for following steps are what changes will be made to each file using the vim command.

# apt install apt-transport-https -y
# wget -O - https://repo.saltstack.com/py3/ubuntu/20.04/amd64/3002/SALTSTACK-GPG-KEY.pub | sudo apt-key add -
(in case wget does not work)
# curl -o SALTSTACK-GPG-KEY.pub https://repo.saltstack.com/py3/ubuntu/20.04/amd64/3002/SALTSTACK-GPG-KEY.pub
# apt-key add SALTSTACK-GPG-KEY.pub
# vim /etc/apt/sources.list.d/saltstack.list
deb http://repo.saltstack.com/py3/ubuntu/20.04/amd64/latest focal main
# apt update
# apt install salt-master -y
7Now that the master server has been created, lets go back to Linode and create the two minion servers. Follow Steps 2–6 to spin up both minion servers (we’ll name these saltminion-dev and saltminion-prod), ssh into each minion, and grab the latest Salt repo. Instead of installing salt-master, we will want to install the salt-minion package to each of our minion servers. I find it easiest to either use different Terminal tabs or windows for each server . It makes for accessing all servers quickly.

# apt install salt-minion -y
8Modify the minion file located at /etc/salt/minion on each minion to configure where the master server is located. This line should be near the top of the minion file.

# vim /etc/salt/minion
master: <your.saltmaster.ip.address>
minion-server-configuration
Initial minion setup updating master config setting to your saltmaster IP address
Restart the salt-minion service on each minion server to allow master to locate the minions in the next step.

# service salt-minion restart
9Switch back to the master server to authenticate the public keys for each minion. Run both salt-key -L (to list the keys on master) and salt-key -A '*' (to authenticate both minion public keys). After both minion keys have been authenticated run salt '*' test.ping to determine if master can connect to both minions. You should see both minion IP’s with the word true output underneath each one if the public keys have been properly authenticated. Additionally running salt-key -L again will show the minion IP’s under Accepted Keys.

# salt-key -L
Accepted Keys:
Denied Keys:
Unaccepted Keys:
123.456.789.012
123.456.789.321
Rejected Keys:
# salt-key -A '*'
# salt '*' test.ping
123.456.789.012:
    True
123.456.789.321:
    True
# salt-key -L
Accepted Keys:
123.456.789.012
123.456.789.321
Denied Keys:
Unaccepted Keys:
Rejected Keys:
10Once the master has been configured to talk to the minions, the next step is to setup our configuration file paths on master. The default settings exist in a file called master within the /etc/salt/ directory. Setting overrides exist within the /etc/salt/master.d/ directory. Instead of using these default settings we will create a file_roots.conf file in the /etc/salt/master.d/ directory. Within this file we will want to include the following lines (first creating the file):

# vim /etc/salt/master.d/file_roots.conf

file_roots:
  base:
    - /home/saltmaster/base
  services:
    - /home/saltmaster/services
After adding the file_roots we will need to restart the salt-master service.

# service salt-master restart
11Now that the saltmaster configuration file paths have been set, we will need to create those new directories we configured above. Navigate to the /home/ directory. Create a new directory called saltmaster, cd into it and create directories for base and services.

# cd /home/
# mkdir saltmaster
# cd saltmaster/
# mkdir base
# mkdir services
12The base directory will be where all base functionality Salt State files will live, the functionality that should be included on all minion servers. Chiefly among these sls files will be top.sls. This file contains directories for all base level state files and maps application and service directories to variables that can be called by grains files. Let’s cd into the base directory we just created and create the top.sls file. Our top file will be fairly basic for this tutorial. All it will contain is a declaration of where common package sls files for all servers as well as service sls files for specific services.

# cd base/
# vim top.sls
base:
  "*":
    - common.packages
services:
  "services:postgres":
    - match: grain
    - postgres
  "services:mongodb":
    - match: grain
    - mongodb
As you can see from the code snippet above, we declare the location for common packages on the master server to be installed on all minion servers: /home/saltmaster/base/common/packages.sls and the location for our postgres and mongodb services: /home/saltmaster/services/postgres & /home/saltmaster/services/mongodb. For the services we will be matching a term specified in the grains file on either minion server. We will get to that however in a little bit. For now, let’s move onto creating the packages.sls file within base/common/.

13From the base directory create a new directory called common. Go into that new directory and make a new file called packages.sls. This packages file contains all common packages that you would want to install on each minion server. For this tutorial all we will be including in here will be a call to install htop as an example of how highstating will install this onto each minion.

# cd base/
# mkdir common
# cd common/
# vim packages.sls
base-packages:
  pkg.installed:
    - pkgs:
      - htop
14With the base directory sorted for what we will be covering in this tutorial, lets move onto the two services we will be installing on the minions. Navigate to the services directory we created in Step 11 /home/saltmaster/services/. Now we will want to create a new directory called mongodb. This directory needs to match what we configured in the base/top.sls file for the mongodb service in Step 12. Go into the new mongodb/ directory and create a new file called init.sls. This file adds an apt repository and then installs the package from said repository.

# cd /home/saltmaster/services/
# mkdir mongodb
# cd mongodb/
# vim init.sls
mongodb:
  pkgrepo.managed:
    - name: deb [trusted=yes] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse
    - file: /etc/apt/sources.list.d/mongodb-4.4.list
    - key_url: https://www.mongodb.org/static/pgp/server-4.4.asc
    - require_in:
      - pkg: mongodb
  pkg.installed:
    - name: mongodb
    - refresh: True
From the init.sls code snippet above (italicized) we can see that the ID Declaration is mongodb followed by a combined inline State/Function Declaration of pkgrepo.managed. This State/Function declaration signifies that we are using the pkgrepo State and the managed Function within the State and will specify the new apt repository we will be adding for mongodb. Underneath the pkgrepo.managed State/Function declaration we give our new repository a name and file path. This name needs to be the exact line that needs to be in a .list file for apt to add that repository. The file declaration will be where that new .list file will exist on the minion server this service will be installed to, in this case being /etc/apt/sources.list.d/mongodb-4.4.list. Following that is the key_url declaration which is a link to a Public Signing Key that authenticates the package within the repository we will be installing. Lastly we have the require_in declaration which specifies what package requires this repository for installation.

There is a second State/Function declaration within this init.sls file called pkg.installed. This declaration specifies we are using the pkg State with the installed Function to install the mongodb package within the repository we configured above. And finally we have a refresh declaration which tells Ubuntu to run the apt update command before installing the package to make sure that apt does indeed have the new repository that we need.

15Now that we have the mongodb service installation configured let’s move onto the postgres service. Navigate to the services directory, /home/saltmaster/services/, and create a new directory called postgres. Go into this new directory and create a new file called init.sls. We will be following a very similar process to the mongodb init.sls file we configured in Step 14.

# cd /home/saltmaster/services/
# mkdir postgres
# cd postgres
# vim init.sls
postgresql:
  pkgrepo.managed:
    - name: deb http://apt.postgresql.org/pub/repos/apt focal-pgdg 12
    - file: /etc/apt/sources.list.d/pgdg.list
    - key_url: https://www.postgresql.org/media/keys/ACCC4CF8.asc
    - require_in:
      - pkg: postgresql-12
  pkg.installed:
    - name: postgresql-12
    - refresh: True
16Once we have created both mongodb and postgres directories and init.sls files we will need to add grains files to each minion server so that the master knows what packages to install on each. Switch to the saltminion-dev server and navigate to the /etc/salt/ directory. Create a new file called grains and add the mongodb service to it. This will tell the saltmaster that we want to install the mongodb package to this minion server. Switch to the saltminion-prod server and repeat but instead add the postgres service.

(saltminion-dev server)
# cd /etc/salt/
# vim grains
services:
- mongodb
(saltminion-prod server)
# cd /etc/salt/
# vim grains
services:
- postgres
17Switch back to the saltmaster server. The time has come to highstate so these services and base packages will be installed on their respective minion servers. With highstating you first declare that it is a salt command, followed by which servers you want to highstate to (in our case we want all of them "*"), and finally which state this salt command will run (state.highstate).

(saltmaster server)
# salt "*" state.highstate
Running the highstate command will take some time, largely dependent on how many packages are installed or how many changes need to be pushed to each server. In our case it’s a matter of seconds. Once complete you should see a similar screen to the image below:

salt-highstate-result
Example of a successful highstate, adding the postgres repository and installing postgresql-12 package from it.
Congratulations! You’ve now successfully finished your first bare-bones Salt configuration.
