#!/bin/sh
# Script for setting a static IP address on the Raspberry Pi2 image

PATH=/bin:/usr/bin:/sbin:/usr/sbin

# The caller must be provide the directory path to the mounted SD card.
MOUNT_DIR=$1
DEFAULT_IP="192.168.1.42"

function check_success() {
  errcode=$1
  msg=$2
  if [ $errcode -ne 0 ]; then
    echo $msg
    exit 1
  fi
}

# Check the user provided a mount directory.
if [ -z $MOUNT_DIR ]; then
  echo "Please specify the boot partition path of the Raspberry Pi2 SD card."
  exit 1
fi

# Check that we have the cmdline.txt file
if [ ! -w $MOUNT_DIR/cmdline.txt ]; then
  echo "Could not find $MOUNT_DIR/cmdline.txt. Please specify a valid boot "\
       "partition path of the Raspberry Pi2 SD card."
  exit 1
fi

# Check if the ip address is already set.
grep -q "ip=" $MOUNT_DIR/cmdline.txt
if [ $? -eq 0 ]; then
  echo "IP address already set in cmdline.txt file.\n"
  # Check if we have a backup file to use for rewriting with new IP.
  if [ ! -r $MOUNT_DIR/cmdline.orig ]; then
    exit 0
  fi
  echo -n "Do you want to overwrite existing configuration using the"\
          "\"cmdline.orig\" backup file [Y/n]?"
  read overwrite
  if [ ! -z $overwrite ] && [ ${overwrite,,} == "n" ]; then
    exit 0
  fi
fi

# Make a backup if one does not already exist.
if [ ! -r $MOUNT_DIR/cmdline.orig ]; then
  cp $MOUNT_DIR/cmdline.txt $MOUNT_DIR/cmdline.orig
  check_success $? \ "Failed to backup original cmdline.txt file"
fi

# Ask for the IP address.
echo -n "Please type your Raspberry IP address [Default: $DEFAULT_IP]: "
read ip

# Set default if no value was provided.
[ -z $ip ] && ip=$DEFAULT_IP

# Rudimentary IP address validation
if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  echo "$ip is not a valid ip address."
  exit 1
fi

# Use cat and printf to ensure the ip= part is on the same line as the rest
# of the cmdline.txt parameters.
printf "%s ip=%s\n" "$(cat $MOUNT_DIR/cmdline.orig)" $ip > \
  $MOUNT_DIR/cmdline.txt
echo "Succesfully set IP address to $ip"
exit 0
