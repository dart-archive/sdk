#!/bin/bash
# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.
#
# Script for preparing the Raspberry Pi2 image with the fletch agent.
#
# You need
#   $ sudo apt-get qemu qemu-user-static binfmt-support
# to run this.
#
# This must run in the fletch directory.
#
# The fletch-agent package must be build before running this, so to
# create an image do the following:
#
#   $ tools/create_tarball.py
#   $ tools/create_debian_packages.py
#   $ tools/raspberry_pi2/raspberry-pi2/prepare-image.sh <version>
#
# Some errors are printed while running in the chroot, e.g.
#
#   Unsupported setsockopt level=1 optname=34
#   sudo: unable to resolve host <your hostname>
#   Failed to read /proc/cmdline. Ignoring: No such file or directory
#   invoke-rc.d: policy-rc.d denied execution of start.
#
# This should not affect the generated image.
#


set -u
set -e

umask 0027

IMAGE_ROOT_NAME=2015-09-24-raspbian-jessie
IMAGE_SHA_FILE=${IMAGE_ROOT_NAME}.zip.sha1
IMAGE_ZIP_FILE=${IMAGE_ROOT_NAME}.zip
IMAGE_FILE=${IMAGE_ROOT_NAME}.img

PI_USER_ID=1000
PI_GROUP_ID=1000
PI_HOME=/home/pi

function usage {
  USAGE="Usage: $0 version\n
\n
The first mandatory argument speciifies the version of the fletch-agent\n
to install into the image."

  echo -e $USAGE
  exit 1
}

# Expect exactly one argument, the version.
if [ $# -ne 1 ]
then
  usage
fi

VERSION=$1
TARBALL_FILE=fletch-${VERSION}.tar.gz
DEB_FILE=fletch-agent_${VERSION}-1_armhf.deb

MOUNT_DIR=out/raspbian

# Get and unzip the image.
echo "Downloading image ZIP file"
download_from_google_storage.py -c -b dart-dependencies-fletch \
    -o out/${IMAGE_ZIP_FILE} -s tools/raspberry-pi2/${IMAGE_SHA_FILE}
echo "Unzipping image file"
unzip -q -o -d out out/$IMAGE_ZIP_FILE

echo "Preparing for chroot"
# This mounts the second second partition in the image file. This assumes
# that the second partition is starting at sector 122880 and that the
# sector size is 512 bytes. To check this for a Raspbian image run the
# following command:
#
# fdisk -lu out/2015-09-24-raspbian-jessie.img
mkdir -p $MOUNT_DIR
sudo mount out/$IMAGE_FILE -o loop,offset=$((122880*512)),rw $MOUNT_DIR

# Copy the tarball to the pi users home directory.
sudo cp out/$TARBALL_FILE $MOUNT_DIR/$PI_HOME
sudo chown $PI_USER_ID:$PI_GROUP_ID $MOUNT_DIR/$PI_HOME/$TARBALL_FILE

# Copy the QEMU user emulation binary the the chroot.
sudo cp /usr/bin/qemu-arm-static $MOUNT_DIR/usr/bin

# Put /etc/ld.so.preload away. It links in code which does not run
# through qemu-arm-static.
sudo mv $MOUNT_DIR/etc/ld.so.preload $MOUNT_DIR/tmp

# Copy the fletch-agent .deb file to the chroot.
cp out/$DEB_FILE $MOUNT_DIR/tmp
sudo chown $PI_USER_ID:$PI_GROUP_ID $MOUNT_DIR/tmp/$DEB_FILE

# Copy the fletch-configuration service script to the chroot.
cp tools/raspberry-pi2/raspbian-scripts/fletch-configuration $MOUNT_DIR/tmp
sudo chown $PI_USER_ID:$PI_GROUP_ID $MOUNT_DIR/tmp/fletch-configuration

# Create /usr/sbin/policy-rc.d which return 101 to avoid starting the
# fletch-agent when installing it, see:
# https://people.debian.org/~hmh/invokerc.d-policyrc.d-specification.txt
sudo sh -c 'cat << EOF > $0/usr/sbin/policy-rc.d
#!/bin/sh
exit 101
EOF' $MOUNT_DIR
sudo chmod u+x $MOUNT_DIR/usr/sbin/policy-rc.d

# Create trampoline script for running the initialization as user pi.
cat << EOF > $MOUNT_DIR/tmp/init_chroot_trampoline.sh
#!/bin/sh
su -c /tmp/init_chroot.sh pi
EOF

# Create the initialization script which installs the fletch-agent
# package.
cat << EOF > $MOUNT_DIR/tmp/init_chroot.sh
#!/bin/sh

cd /tmp

# Install the fletch-agent Debian package.
sudo dpkg -i $DEB_FILE

# Install the fletch-configuration service script.
sudo cp /tmp/fletch-configuration /etc/init.d
sudo chown root:root /etc/init.d/fletch-configuration
sudo chmod 755 /etc/init.d/fletch-configuration
sudo insserv fletch-configuration
sudo update-rc.d fletch-configuration enable

EOF

chmod u+x $MOUNT_DIR/tmp/init_chroot_trampoline.sh
sudo chown 0:0 $MOUNT_DIR/tmp/init_chroot_trampoline.sh

chmod u+x $MOUNT_DIR/tmp/init_chroot.sh
sudo chown $PI_USER_ID:$PI_GROUP_ID $MOUNT_DIR/tmp/init_chroot.sh

# chroot into the Raspbian image and run the required commands.
echo "Running chroot"
sudo chroot $MOUNT_DIR /bin/sh /tmp/init_chroot_trampoline.sh

echo "Cleanup"

# Restore /etc/ld.so.preload
sudo mv $MOUNT_DIR/tmp/ld.so.preload $MOUNT_DIR/etc

# Clean up temporary files
sudo rm $MOUNT_DIR/usr/bin/qemu-arm-static
sudo rm $MOUNT_DIR//usr/sbin/policy-rc.d
sudo rm $MOUNT_DIR/tmp/*

sudo umount $MOUNT_DIR
rmdir $MOUNT_DIR

# Rename and zip the resulting image file.
RESULT_IMAGE_ROOT=${IMAGE_ROOT_NAME}-fletch-${VERSION}
RESULT_IMAGE_FILE=${RESULT_IMAGE_ROOT}.img
RESULT_IMAGE_ZIP_FILE=${RESULT_IMAGE_ROOT}.zip
mv out/$IMAGE_FILE out/$RESULT_IMAGE_FILE
zip --junk-paths out/$RESULT_IMAGE_ZIP_FILE out/$RESULT_IMAGE_FILE
