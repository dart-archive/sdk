#!/bin/bash
# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.
#
# Script for preparing the Raspberry Pi2 image for easy installation of the
# fletch agent. All this script does is basically to comment out a few lines
# in /etc/fstab and /etc/ld.so.preload.
#
# It is expected that the script producing the actual release image will remove
# the comment characters to reenable the full system for running on the pi.
#
# TODO(ricow): you can't currently startup the raspbian jessie image with
# init=/bin/bash if the ld.so.preload file has not been commented out. Since
# other people is also experiencing issues with this we should revisit in the
# future.
#
# We push the output of this run to a bundle on google cloud storage and use
# that to create the actual bundles with specific fletch vm/agents on them.
#
# PLEASE NOTE THAT THIS SCRIPT WILL DO IN PLACE UPDATING

set -u
set -e

umask 0027

function usage {
  USAGE="Usage: $0 image_file
\n
The first mandatory argument specifies the image to update"

  echo -e $USAGE
  exit 1
}

# Expect exactly one argument, the image.
if [ $# -ne 1 ]
then
  usage
fi

MOUNT_DIR=out/raspbian

echo "Mounting image"
# This mounts the second second partition in the image file. This assumes
# that the second partition is starting at sector 122880 and that the
# sector size is 512 bytes. To check this for a Raspbian image run the
# following command:
#
# fdisk -lu out/2015-09-24-raspbian-jessie.img
mkdir -p $MOUNT_DIR
sudo mount $1 -o loop,offset=$((122880*512)),rw $MOUNT_DIR

echo "Fixing ld.so.preload"
sudo sed -i 's/^/#/' $MOUNT_DIR/etc/ld.so.preload

echo "Fixing fstab"
sudo sed -i '/mmcblk/s/^/#/g'  $MOUNT_DIR/etc/fstab

echo "Umounting"
sudo umount $MOUNT_DIR
