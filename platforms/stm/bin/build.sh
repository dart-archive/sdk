#!/bin/sh
# Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Script to build a Dart application for the STM32F746G Discovery board.
#
# In the Dartino SDK this is located in platforms/stm32f746g-discovery/bin.

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <dart file>"
  exit 1
fi
DART_FILE=$1
BASE_NAME="$(basename "$DART_FILE" .dart)"

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

echo "Compiling snapshot of $DART_FILE"
"$DARTINO" export "$DART_FILE" to file "$BUILD_DIR/snapshot"

pushd "$BUILD_DIR"

"$SCRIPT_DIR/link.sh" "$BASE_NAME" "$BUILD_DIR"

printf "\nFinishing building flashable image: $BUILD_DIR/$BASE_NAME.bin"
