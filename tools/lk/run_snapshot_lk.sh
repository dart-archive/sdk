#!/bin/bash
# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

if [ -z "$1" -o ! -s "$1" ]; then
echo "$0: Expecting a snapshot file as fist argument."
exit 1
fi
PORT=${2-/dev/ttyUSB0}

if [ ! -c "$PORT" ]; then
echo "$0: $PORT is not a valid character device."
exit 2
fi

SIZE=`cat $1 | wc -c`

echo "fletch" >$PORT
sleep 1
echo $SIZE >$PORT
sleep 1
cat $1 >$PORT
