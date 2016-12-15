#!/usr/bin/env bash

# Make sure we are root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

#set variables
instance="osehra"
repoPath="https://github.com/OSEHRA/VistA-M.git"

# Get primary username if using sudo, default to $username if not sudo'd
if [[ -n "$SUDO_USER" ]]; then
    primaryuser=$SUDO_USER
elif [[ -n "$USERNAME" ]]; then
    primaryuser=$USERNAME
else
    echo Cannot find a suitable username to add to VistA group
    exit 1
fi

echo This script will add $primaryuser to the VistA group

# Abort provisioning if it appears that an instance is already installed.
test -d /home/$instance/g &&
{ echo "VistA already Installed. Aborting."; exit 0; }


# control interactivity of debian tools
export DEBIAN_FRONTEND="noninteractive"

# extra utils - used for cmake and dashboards and initial clones
# Note: Amazon EC2 requires two apt-get update commands to get everything
echo "Updating operating system"
apt-get update -qq > /dev/null
apt-get update -qq > /dev/null
apt-get install -qq -y build-essential cmake-curses-gui git dos2unix daemon > /dev/null

# Clone repos
cd /usr/local/src
git clone -q https://github.com/OSEHRA/VistA -b dashboard VistA-Dashboard

#assumes script is using vagrant
if ! [ -d /vagrant ]; then
    echo "This scripts assumes you are utilizing Vagrant. Terminating install."; exit 0;
fi

scriptdir=/vagrant

# Fix line endings
find /vagrant -name \"*.sh\" -type f -print0 | xargs -0 dos2unix > /dev/null 2>&1
dos2unix /vagrant/EWD/etc/init.d/ewdjs > /dev/null 2>&1
dos2unix /vagrant/GTM/etc/init.d/vista > /dev/null 2>&1
dos2unix /vagrant/GTM/etc/xinetd.d/vista-rpcbroker > /dev/null 2>&1
dos2unix /vagrant/GTM/etc/xinetd.d/vista-vistalink > /dev/null 2>&1
dos2unix /vagrant/GTM/gtminstall_SHA1 > /dev/null 2>&1

# bootstrap the system
cd $scriptdir

# Update the server from repositories
apt-get -y -qq update > /dev/null
apt-get -y -qq upgrade > /dev/null

# Install baseline packages
apt-get install -y -qq git xinetd perl wget curl python ssh mysql-server default-jdk maven sshpass > /dev/null

# Ensure scripts know that we are installing for ubuntu
export ubuntu=true;

# Install GTM
cd GTM
./install.sh -v V6.2-000

# Create the VistA instance
./createVistaInstance.sh -i $instance

# Modify the primary user to be able to use the VistA instance
usermod -a -G $instance $primaryuser
chmod g+x /home/$instance

# Setup environment variables so the dashboard can build
# have to assume $basedir since this sourcing of this script will provide it in
# future commands
source /home/$instance/etc/env

# Get running user's home directory
# http://stackoverflow.com/questions/7358611/bash-get-users-home-directory-when-they-run-a-script-as-root
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

# source env script during running user's login
echo "source $basedir/etc/env" >> $USER_HOME/.bashrc

# Build a dashboard and run the tests to verify installation
# These use the Dashboard branch of the VistA repository
# The dashboard will clone VistA and VistA-M repos
# run this as the $instance user

# create random string for build identification
# source: http://ubuntuforums.org/showthread.php?t=1775099&p=10901169#post10901169
export buildid=`tr -dc "[:alpha:]" < /dev/urandom | head -c 8`

# Import VistA and run tests using OSEHRA automated testing framework
su $instance -c "source $basedir/etc/env && ctest -S $scriptdir/test.cmake -V"
# Tell users of their build id
echo "Your build id is: $buildid you will need this to identify your build on the VistA dashboard"

# Enable journaling
su $instance -c "source $basedir/etc/env && $basedir/bin/enableJournal.sh"

# Restart xinetd
service xinetd restart

# Add p and s directories to gtmroutines environment variable
su $instance -c "mkdir $basedir/{p,p/$gtmver,s,s/$gtmver}"
if [[ $gtmver == *"6.2"* ]]; then
    echo "Adding Development directories for GT.M 6.2"
    perl -pi -e 's#export gtmroutines=\"#export gtmroutines=\"\$basedir/p/\$gtmver\*(\$basedir/p\) \$basedir/s/\$gtmver\*(\$basedir/s\) #' $basedir/etc/env
else
    echo "Adding Development directories for GT.M <6.2"
    perl -pi -e 's#export gtmroutines=\"#export gtmroutines=\"\$basedir/p/\$gtmver\(\$basedir/p\) \$basedir/s/\$gtmver\(\$basedir/s\) #' $basedir/etc/env
fi

# Install node.js via NVM (node version manager)

#install node 4.7.0 (nodem supports up to 4.7.0)
nodever="4.7.0"

# Set the node version
shortnodever=$(echo $nodever | cut -d'.' -f 2)

# set the arch
arch=$(uname -m | tr -d _)

# This should be ran as the instance owner to keep all of VistA together
if [[ -z $basedir ]]; then
    echo "The required variable \$instance is not set"
fi

echo "Installing node.js via NVM (node version manager)"

# Copy init.d scripts to VistA etc directory
su $instance -c "cp -R etc $basedir"

# Download installer in tmp directory
cd $basedir/tmp

# Install node.js using NVM (node version manager)
echo "Downloading NVM installer"
curl -s -k --remote-name -L  https://raw.githubusercontent.com/creationix/nvm/master/install.sh
echo "Done downloading NVM installer"

# Execute it
chmod +x install.sh
su $instance -c "./install.sh"

# Remove it
rm -f ./install.sh

# move to $basedir
cd $basedir

# Install node
su $instance -c "source $basedir/.nvm/nvm.sh && nvm install $nodever && nvm alias default $nodever && nvm use default"

# Tell $basedir/etc/env our nodever
echo "export nodever=$nodever" >> $basedir/etc/env

# Tell nvm to use the node version in .profile or .bash_profile
if [ -s $basedir/.profile ]; then
    echo "source \$HOME/.nvm/nvm.sh" >> $basedir/.profile
    echo "nvm use $nodever" >> $basedir/.profile
fi

if [ -s $basedir/.bash_profile ]; then
    echo "source \$HOME/.nvm/nvm.sh" >> $basedir/.bash_profile
    echo "nvm use $nodever" >> $basedir/.bash_profile
fi

# Create directories for node
su $instance -c "source $basedir/etc/env"

# Install required node modules
cd $basedir
su $instance -c "source $basedir/.nvm/nvm.sh && source $basedir/etc/env && nvm use $nodever && npm install --quiet nodem >> $basedir/log/nodemInstall.log"

# Copy the right mumps$shortnodever.node_$arch
su $instance -c "cp $basedir/node_modules/nodem/lib/mumps"$nodever".node_$arch $basedir/ewdjs/mumps.node"
su $instance -c "mv $basedir/node_modules/nodem/lib/mumps"$nodever".node_$arch $basedir/ewdjs/node_modules/nodem/lib/mumps.node"

# Setup GTM C Callin
# with nodem 0.3.3 the name of the ci has changed. Determine using ls -1
calltab=$(ls -1 $basedir/node_modules/nodem/resources/*.ci)
echo "export GTMCI=$calltab" >> $basedir/etc/env

# Ensure nodem routines are in gtmroutines search path
echo "export gtmroutines=\"\${gtmroutines}\"\" \"\$basedir/node_modules/nodem/src" >> $basedir/etc/env

echo "Done installing node.js"

#install vdp
vdpid=vdp
test -d /home/$vdpid &&
{ echo "VISTA Data Project user $vdpid already Installed. Aborting."; exit 0; }
echo "Creating VISTA Data Project user, $vdpid"
vdphome=/home/$vdpid
osehrahome=/home/osehra

echo "Mimicing the .profile and .bashrc of user osehra"

# Create $vdpid user - make sure it is in the osehra group
sudo useradd -c "VDP User" -m -U "$vdpid" -s /bin/bash -G sudo,osehra
echo $vdpid:vdp | sudo chpasswd

# Copy unique end of .bashrc of /home/osehra and add an extra
echo "" >> $vdphome/.bashrc
echo "source $osehrahome/etc/env" >> $vdphome/.bashrc
# osehra uses Node Version Manager (EWD sets it up)
echo "export NVM_DIR=\"$osehrahome/.nvm\"" >> $vdphome/.bashrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> $vdphome/.bashrc
# VDP Extra: override 'gtm_tmp' to /tmp to avoid write/link errors"
echo "export gtm_tmp=/tmp" >> $vdphome/.bashrc
# Copy unique end of .profile of osehra
echo "source $osehrahome/.nvm/nvm.sh" >> $vdphome/.profile
# Set nodever ala EWD/ewd.js. Otherwise $nodever .profile won't exist and npm install below will fail
nodever="4.7.0"
echo "nvm use $nodever" >> $vdphome/.profile

cd $vdphome

# install nodem in node_modules in $HOME
echo "Installing 'nodem' for $vdpid - slowest piece"
su $vdpid -c "mkdir logs"
su $vdpid -c "source $osehrahome/.nvm/nvm.sh && source $osehrahome/etc/env && nvm use $nodever && npm install --quiet nodem >> $vdphome/nodemInstall.log"

echo "Cloning nodeVISTA and VDM for use by $vdpid"
git clone -q https://github.com/vistadataproject/nodeVISTA.git
git clone -q https://github.com/vistadataproject/VDM.git

# Add FMQL x 2
echo "Cloning FMQL MUMPS and One Page Clients for use by $vdpid"
git clone -q https://github.com/caregraf/FMQL.git

#change ownership of git clones to vdp
chown -R vdp:vdp nodeVISTA
chown -R vdp:vdp VDM
chown -R vdp:vdp FMQL

#install jasmine
echo "Installing Jasmine"
su $vdpid -c "source $osehrahome/.nvm/nvm.sh && source $osehrahome/etc/env && nvm use $nodever && npm install --quiet jasmine -g >> $vdphome/nodemInstall.log"

#install bower
echo "Installing Bower"
su $vdpid -c "source $osehrahome/.nvm/nvm.sh && source $osehrahome/etc/env && nvm use $nodever && npm install --quiet bower -g >> $vdphome/nodemInstall.log"

#copy over /vagrant/utils
cd $vdphome
cp -r /vagrant/utils .
chown -R vdp:vdp utils

#overwrite osehra cipher with VA cipher
echo "Replacing osehra cipher with va by overwriting XUSRB1.m (w/backup XUSRB1.m.bak)"
sudo mv /home/osehra/r/XUSRB1.m /home/osehra/r/XUSRB1.m.bak
sudo cp utils/XUSRB1.m /home/osehra/r/.

#run VDM/prototypes/sysSetup npm install
echo "Running npm install on /vagrant/utils"
su $vdpid -c "source $osehrahome/.nvm/nvm.sh && source $osehrahome/etc/env && cd $vdphome/utils && nvm use $nodever && npm install --quiet >> $vdphome/logs/sysSetupInstall.log"

#apply problem data dictionary fix
echo "Applying problem data dictionary fix (fixDD.js)"
su $vdpid -c "source $osehrahome/.nvm/nvm.sh && source $osehrahome/etc/env && cd $vdphome/utils && nvm use $nodever && node fixDD.js >> $vdphome/logs/fixDD.log"

#apply fix that allows users to input vital data
echo "Applying fix that allow users to input vital data (setupVitalsForUsers.js)"
su $vdpid -c "source $osehrahome/.nvm/nvm.sh && source $osehrahome/etc/env && cd $vdphome/utils && nvm use $nodever && node setupVitalsForUsers.js >> $vdphome/logs/setupVitalsForUsers.log"

#apply fix that setups CAPRI which is controlled in parameter XU522
echo "Applying fix setups CAPRI which is controlled in parameter XU522 (setupCapri.js)"
su $vdpid -c "source $osehrahome/.nvm/nvm.sh && source $osehrahome/etc/env && cd $vdphome/utils && nvm use $nodever && node setupCapri.js >> $vdphome/logs/setupVitalsForUsers.log"

# Ensure group permissions are correct
chmod -R g+rw /home/$vdpid

echo "User $vdpid created"
