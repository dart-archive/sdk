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

$OPENOCDHOME/bin/openocd                                                  \
    -f interface/${STLINK}.cfg                                            \
    -f board/${BOARD}.cfg                                                 \
    --search $OPENOCDHOME/share/openocd/scripts                           \
    -c "init"                                                             \
    -c "reset halt"                                                       \
    -c "flash write_image erase $1 0x8000000"                             \
    -c "reset run"                                                        \
    -c "shutdown"
