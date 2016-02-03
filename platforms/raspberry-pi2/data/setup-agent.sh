#!/bin/sh
echo "Setting up Dartino agent"
sudo /usr/sbin/update-rc.d dartino-agent defaults
sudo service dartino-agent start
