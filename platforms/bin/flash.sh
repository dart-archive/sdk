#!/bin/bash
# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Script to flash a binary using OpenOCD.

set -e
set -x

IMAGE_FILE=
BOARD=

SCRIPT_NAME="$0"

function usage() {
  echo "Usage: $SCRIPT_NAME -b <board> <image file>"
  exit 1;
}

while [ $# -gt 0 ]; do
  case $1 in
    --board | -b)
      BOARD="$2"
      shift 2
      ;;
    *)
      IMAGE_FILE="$1"
      shift
      if [ ! -z "$1" ]; then
        echo "Additional arguments after image file not supported."
        usage
      fi
      ;;
  esac
done

# Check for image file on command line.
if [ -z "$IMAGE_FILE" ]; then
  echo "Image file not specified."
  usage
fi

# Check for image file on command line.
if [ ! -e "$IMAGE_FILE" ]; then
  echo "Image file does not exist: $IMAGE_FILE."
  usage
fi

# Check for "-b <board>" on command line.
if [ -z "$BOARD" ]; then
  echo "Board for OpenOCD not specified."
  usage
fi

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
