#!/bin/bash
# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

if [ -z "$1" ]; then
  echo "Usage: $0 [options] <image file>"
  exit 1
fi

EXPECTED_ARGS=1

source $(dirname $(readlink -f $0))/openocd-helpers.shlib

if [ ! -e $1 ]; then
  echo "Image file does not exist: $1."
  exit 1
fi

# We need to start openocd in its own processgroup, as otherwise it would
# see the SIGINT commonly used in gdb to interrupt program execution.
# openocd terminates on SIGINT :(
sh -ic "$OPENOCDHOME/bin/openocd                               \
    -f interface/${STLINK}.cfg                                 \
    -f board/${BOARD}.cfg                                      \
    --search $OPENOCDHOME/share/openocd/scripts                \
    -l /tmp/openocd.log                                        \
    -d" < /dev/null &
PID=$!

until netstat -lnt | grep -q ':3333'; do
  sleep 0.1
done

arm-none-eabi-gdb $1 --eval-command="tar remote :3333" \
    --eval-command="mon reset halt"

kill $PID
