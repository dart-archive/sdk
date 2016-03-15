#!/bin/bash
# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.


if [ -z "$1" ]; then
  echo "Usage: $0 <image file>"
  exit 1
fi
IMAGE_FILE=$1

OS="`uname`"
case $OS in
  'Linux')
    OS='linux'
    ;;
  'Darwin')
    OS='mac'
    ;;
  *)
    echo "Unsupported OS $OS"
    exit 1
    ;;
esac

function follow_links() {
  file="$1"
  while [ -h "$file" ]; do
    # On Mac OS, readlink -f doesn't work.
    file="$(readlink "$file")"
  done
  echo "$file"
}

# Unlike $0, $BASH_SOURCE points to the absolute path of this file.
PROG_NAME="$(follow_links "$BASH_SOURCE")"

# Handle the case where dartino-sdk/bin has been symlinked to.
SCRIPT_DIR="$(cd "${PROG_NAME%/*}" ; pwd -P)"

source "$SCRIPT_DIR/setup-paths.shlib"

if [ ! -e $1 ]; then
  echo "Image file does not exist: $1."
  exit 1
fi

BOARD="stm32f7discovery"
STLINK="stlink-v2-1"

$OPENOCDHOME/bin/openocd                                                  \
    -f interface/${STLINK}.cfg                                            \
    -f board/${BOARD}.cfg                                                 \
    --search $OPENOCDHOME/share/openocd/scripts                           \
    -c "init"                                                             \
    -c "reset halt"                                                       \
    -c "flash write_image erase $IMAGE_FILE 0x8000000"                    \
    -c "reset run"                                                        \
    -c "shutdown"
