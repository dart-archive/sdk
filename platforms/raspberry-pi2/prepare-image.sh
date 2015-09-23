#!/bin/sh
# Script for preparing the Raspberry Pi2 image with the fletch agent and vm.

PATH=/bin:/usr/bin:/sbin:/usr/sbin

# Determine the absolute path to the directory where the script is located and
# use that to find other files.
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
DATA_DIR=$SCRIPT_DIR/data

# The caller must be provide the directory path to the mounted SD card.
MOUNT_DIR=$1

function check_success() {
  errcode=$1
  msg=$2
  if [ $errcode -ne 0 ]; then
    echo $msg
    exit 1
  fi
}

function setup_link() {
  link_name=$1
  runlevel="rc$2.d"
  sudo -E rm -f $MOUNT_DIR/etc/$runlevel/$link_name 
  sudo -E ln -s -r -f \
      $MOUNT_DIR/etc/init.d/fletch-agent $MOUNT_DIR/etc/$runlevel/$link_name
  check_success $? \
      "Failed to create symbolic link to fletch-agent in runlevel $level"
}

function update_service_dependencies {
  # If the dependency files are already setup with the fletch-agent just return
  sudo -E grep -q fletch-agent $MOUNT_DIR/etc/init.d/.depend.start
  if [ $? -eq 0 ]; then
    sudo -E grep -q fletch-agent $MOUNT_DIR/etc/init.d/.depend.stop
    if [ $? -eq 0 ]; then
      # Already setup with fletch
      return 0
    fi
  fi
  # Check if we can update them (aka. overwrite them).
  sudo -E diff -q $DATA_DIR/depend.start.orig \
                  $MOUNT_DIR/etc/init.d/.depend.start \
        | grep -q "differ"
  if [ $? -eq 0 ]; then
    # Cannot overwrite them
    return 1
  fi
  sudo -E diff -q $DATA_DIR/depend.stop.orig \
                  $MOUNT_DIR/etc/init.d/.depend.stop \
        | grep "differ"
  if [ $? -eq 0 ]; then
    return 1
  fi

  # The dependency files matched what we expected. Overwrite with updated
  # copies.
  sudo -E cp $DATA_DIR/depend.start.fletch \
             $MOUNT_DIR/etc/init.d/.depend.start
  sudo -E cp $DATA_DIR/depend.stop.fletch \
             $MOUNT_DIR/etc/init.d/.depend.stop
  return 0
}

function manual_agent_setup() {
  # grep found the differ word in the output, so ask user to run script.
  echo "Cannot setup agent automatically."
  echo "Please run the command: /opt/fletch/bin/setup-agent.sh" \
       "once booted into the Raspberry Pi2."
  echo "Succesfully setup fletch on mounted SD card $MOUNT_DIR"
  exit 0
}

# The caller must be provide the directory path to the mounted SD card.
if [ -z $MOUNT_DIR ]; then
  echo "Please specify the root partition path of the Raspberry Pi2 SD card"
  exit 1
fi

# Check that we can see the mount dir
if [ ! -d $MOUNT_DIR/etc/init.d/ ]; then
  echo "Could not access /etc/init.d on mounted directory: $MOUNT_DIR"
  exit 1
fi
if [ ! -d $MOUNT_DIR/etc/default/ ]; then
  echo "Could not access /etc/default on mounted directory: $MOUNT_DIR"
  exit 1
fi

# Check that we have the fletch-vm and the fletch-agent.snapshot files
if [ ! -r $DATA_DIR/fletch-vm ]; then
  echo "Could not find fletch-vm binary in directory $DATA_DIR"
  exit 1
fi
if [ ! -r $DATA_DIR/fletch-agent.snapshot ]; then
  echo "Could not find fletch-agent.snapshot binary in directory $DATA_DIR"
  exit 1
fi

# Create the destination directories on the mounted partition.
sudo -E mkdir -p $MOUNT_DIR/opt/fletch/bin
check_success $? "Failed to create /opt/fletch/bin directory on $MOUNT_DIR"
sudo -E mkdir -p $MOUNT_DIR/var/log/fletch
check_success $? "Failed to create /var/log/fletch directory on $MOUNT_DIR"
sudo -E mkdir -p $MOUNT_DIR/var/run/fletch
check_success $? "Failed to create /var/run/fletch directory on $MOUNT_DIR"

# Copy the files into the right places, we must run with sudo as the partition
# has root as the owner.
sudo -E cp $DATA_DIR/fletch-agent $MOUNT_DIR/etc/init.d/
check_success $? "Failed to copy fletch-agent to /etc/init.d on $MOUNT_DIR"
sudo -E cp $DATA_DIR/fletch-agent.env $MOUNT_DIR/etc/default/fletch-agent
check_success $? "Failed to copy fletch-agent environment file to /etc/default"\
  "on $MOUNT_DIR"
sudo -E cp $DATA_DIR/fletch-vm $MOUNT_DIR/opt/fletch/bin/
check_success $? "Failed to copy fletch-vm to /opt/fletch/bin on $MOUNT_DIR"
sudo -E cp $DATA_DIR/fletch-agent.snapshot $MOUNT_DIR/opt/fletch/bin/
check_success $? \
  "Failed to copy fletch-agent.snapshot to /opt/fletch/bin on $MOUNT_DIR"
sudo -E cp $DATA_DIR/setup-agent.sh $MOUNT_DIR/opt/fletch/bin/
check_success $? \
  "Failed to copy setup-agent.sh script to /opt/fletch/bin on $MOUNT_DIR"

# Set file permissions to allow all to read or execute.
sudo -E chmod 755 $MOUNT_DIR/etc/init.d/fletch-agent
check_success $? "Failed to make fletch-agent executable for all"
sudo -E chmod 644 $MOUNT_DIR/etc/default/fletch-agent
check_success $? "Failed to make fletch-agent environment readable for all"
sudo -E chmod 755 $MOUNT_DIR/opt/fletch/bin/fletch-vm
check_success $? "Failed to make fletch-vm executable for all"
sudo -E chmod 644 $MOUNT_DIR/opt/fletch/bin/fletch-agent.snapshot
check_success $? "Failed to make fletch-agent.snapshot readable for all"
sudo -E chmod 755 $MOUNT_DIR/opt/fletch/bin/setup-agent.sh
check_success $? "Failed to make setup-agent.sh script executable for all"

# Update the service dependency files if needed. This is only done if the files
# have not been modified from the original installation. If they have been 
# modified we ask the user to run the /usr/sbin/update-rc.d script for the
# fletch-agent once booted into the Raspberry Pi2 and reboot.
update_service_dependencies
if [ $? -eq 0 ]; then
  # Setup runlevel links, start in level 2, 3, 4, 5. Stop in 0, 1, 6.
  setup_link K01fletch-agent 0
  setup_link K01fletch-agent 1
  setup_link S02fletch-agent 2
  setup_link S02fletch-agent 3
  setup_link S02fletch-agent 4
  setup_link S02fletch-agent 5
  setup_link K01fletch-agent 6
else
  manual_agent_setup
fi

echo "Succesfully setup fletch on mounted SD card $MOUNT_DIR"
exit 0
