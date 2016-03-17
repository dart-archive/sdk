#!/bin/bash
# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

source $(dirname $(readlink -f $0))/devdiscovery.shlib

if [ -z "$1" -o ! -s "$1" ]; then
echo "$0: Expecting a snapshot file as first argument."
exit 1
fi

if [ -z "$PORT" ]; then
  discover_devices
  PORT=${STLINKPORT}
fi

if [ ! -c "$PORT" ]; then
echo "$0: $PORT is not a valid character device."
exit 2
fi

# Configure the port to LK's default tty speed.
stty -F $PORT 115200

SIZE=`cat $1 | wc -c`

echo "dartino" >$PORT
sleep 1
echo $SIZE >$PORT
sleep 1
cat $1 >$PORT
