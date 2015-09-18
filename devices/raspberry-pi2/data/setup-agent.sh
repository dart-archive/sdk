#!/bin/sh
echo "Setting up Fletch agent"
sudo /usr/sbin/update-rc.d fletch-agent defaults
sudo service fletch-agent start
