#!/bin/bash

function ensure_exists {
  if [ ! -f $1 ]; then
    echo "Expected $1 to exist"
    exit
  fi
}

ensure_exists /etc/default/apport
sed -i 's/enabled=1/enabled=0/g' /etc/default/apport

ensure_exists /etc/sysctl.conf
SYSCTL1="kernel.core_pattern = core"
SYSCTL2="kernel.core_uses_pid = 1"
grep "^$SYSCTL1\$" /etc/sysctl.conf || echo $SYSCTL1 >> /etc/sysctl.conf && echo "Ensured $SYSCTL1 sysctl is there"
grep "^$SYSCTL2\$" /etc/sysctl.conf || echo $SYSCTL2 >> /etc/sysctl.conf && echo "Ensured $SYSCTL2 sysctl is there"
echo "Reloading /etc/sysctl.conf"
sysctl -p

echo "Updating apt repository & install ARM software"
dpkg --add-architecture i386 && sudo apt-get update
apt-get install linux-libc-dev:i386 gcc-4.8-arm-linux-gnueabihf g++-4.8-arm-linux-gnueabihf

echo "Installing libfdt"
apt-get install libfdt1


### END manual steps

echo ""
echo "-------------------------------------------------"
echo "Hello Mr. PLEASE FOLLOW THESE MANUAL INSTRUCTIONS"
echo "   a) Manually copy the chrome-bot-boto file to /b/build/site_config/.boto"

