#!/bin/sh

# install-unifi.sh
# Installs the Uni-Fi controller software on a FreeBSD machine (presumably running pfSense).

# The latest version of UniFi:
UNIFI_SOFTWARE_URL="https://dl.ui.com/unifi/6.2.25/UniFi.unix.zip" #Main Branch

# The rc script associated with this branch or fork:
RC_SCRIPT_URL="https://raw.githubusercontent.com/gozoinks/unifi-pfsense/master/rc.d/unifi.sh"

# If pkg-ng is not yet installed, bootstrap it:
if ! /usr/sbin/pkg -N 2> /dev/null; then
  echo "FreeBSD pkgng not installed. Installing..."
  env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg bootstrap
  echo " done."
fi

# If installation failed, exit:
if ! /usr/sbin/pkg -N 2> /dev/null; then
  echo "ERROR: pkgng installation failed. Exiting."
  exit 1
fi

# Determine this installation's Application Binary Interface
ABI=`/usr/sbin/pkg config abi`

# FreeBSD package source:
FREEBSD_PACKAGE_URL="https://pkg.freebsd.org/${ABI}/latest/All/"

# FreeBSD package list:
FREEBSD_PACKAGE_LIST_URL="https://pkg.freebsd.org/${ABI}/latest/packagesite.txz"

# Stop the controller if it's already running...
# First let's try the rc script if it exists:
if [ -f /usr/local/etc/rc.d/unifi.sh ]; then
  echo -n "Stopping the unifi service..."
  /usr/sbin/service unifi.sh stop
  echo " done."
fi

# Then to be doubly sure, let's make sure ace.jar isn't running for some other reason:
if [ $(ps ax | grep -c "/usr/local/UniFi/lib/[a]ce.jar start") -ne 0 ]; then
  echo -n "Killing ace.jar process..."
  /bin/kill -15 `ps ax | grep "/usr/local/UniFi/lib/[a]ce.jar start" | awk '{ print $1 }'`
  echo " done."
fi

# And then make sure mongodb doesn't have the db file open:
if [ $(ps ax | grep -c "/usr/local/UniFi/data/[d]b") -ne 0 ]; then
  echo -n "Killing mongod process..."
  /bin/kill -15 `ps ax | grep "/usr/local/UniFi/data/[d]b" | awk '{ print $1 }'`
  echo " done."
fi

# Repairs Mongodb database in case of corruption
mongod --dbpath /usr/local/UniFi/data/db --repair

# If an installation exists, we'll need to back up configuration:
if [ -d /usr/local/UniFi/data ]; then
  echo "Backing up UniFi data..."
  BACKUPFILE=/var/backups/unifi-`date +"%Y%m%d_%H%M%S"`.tgz
  /usr/bin/tar -vczf ${BACKUPFILE} /usr/local/UniFi/data
fi

# Add the fstab entries apparently required for OpenJDKse:
if [ $(grep -c fdesc /etc/fstab) -eq 0 ]; then
  echo -n "Adding fdesc filesystem to /etc/fstab..."
  echo -e "fdesc\t\t\t/dev/fd\t\tfdescfs\trw\t\t0\t0" >> /etc/fstab
  echo " done."
fi

if [ $(grep -c proc /etc/fstab) -eq 0 ]; then
  echo -n "Adding procfs filesystem to /etc/fstab..."
  echo -e "proc\t\t\t/proc\t\tprocfs\trw\t\t0\t0" >> /etc/fstab
  echo " done."
fi

# Run mount to mount the two new filesystems:
echo -n "Mounting new filesystems..."
/sbin/mount -a
echo " done."


#remove mongodb34 - discontinued
echo "Removing packages discontinued..."
if [ `pkg info | grep -c mongodb-` -eq 1 ]; then
         pkg unlock -yq mongodb
	 env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete mongodb
fi

if [ `pkg info | grep -c mongodb34-` -eq 1 ]; then
         pkg unlock -yq mongodb34 
	 env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete mongodb34
fi

if [ `pkg info | grep -c mongodb36-` -eq 1 ]; then
        pkg unlock -yq mongodb36
	env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete mongodb36
fi

if [ `pkg info | grep -c mongodb42-` -eq 1 ]; then
        pkg unlock -yq mongodb42
	env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg delete mongodb42
fi
echo " done."
