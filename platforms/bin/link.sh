#!/bin/bash
# Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Script to link a Dart snapshot with the FreeRTOS Dartino embedding.

set -e
set -x

BASE_NAME=
CFLAGS=
LIBS=
LINKER_SCRIPT=
FLOATING_POINT_SIZE=64

SCRIPT_NAME="$0"
while [ $# -gt 0 ]; do
  case $1 in
    --cflags | -f)
      CFLAGS="$CFLAGS $2"
      shift 2
      ;;
    --library | -l)
      LIBS="$LIBS $2"
      shift 2
      ;;
    --linker_script | -t)
      LINKER_SCRIPT="$2"
      shift 2
      ;;
    --floating_point_size)
      FLOATING_POINT_SIZE="$2"
      shift 2
      ;;
    *)
      BASE_NAME="$1"
      shift
      if [ ! -z "$1" ]; then
        _BUILD_DIR="$1"
        shift
      fi
      if [ ! -z "$1" ]; then
        echo "Usage: $SCRIPT_NAME -f <cflags> -l <library> -t <linker_script> [--single_precision] <base name> [<build dir>]"
        exit 1
      fi
      ;;
  esac
done

SNAPSHOT_FILE=snapshot

EMBEDDER_OPTIONS_FILE=embedder_options.c
EMBEDDER_OPTIONS_OBJ=embedder_options.o


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

# Check for <build dir> on command line. As the script
# setup-paths.shlib will set a default BUILD_DIR.
if [ ! -z "$_BUILD_DIR" ]; then
  BUILD_DIR="$_BUILD_DIR"
fi

# Paths to to gcc and objcopy.
TOOLCHAIN_PREFIX="$TOOLCHAIN_DIR/bin/arm-none-eabi-"
CC="${TOOLCHAIN_PREFIX}gcc"
OBJCOPY="${TOOLCHAIN_PREFIX}objcopy"
SIZE="${TOOLCHAIN_PREFIX}size"

ASM_FILE="$BUILD_DIR/$BASE_NAME.S"
OBJ_FILE="$BUILD_DIR/$BASE_NAME.o"
ELF_FILE="$BUILD_DIR/$BASE_NAME.elf"
BIN_FILE="$BUILD_DIR/$BASE_NAME.bin"
HEX_FILE="$BUILD_DIR/$BASE_NAME.hex"
MAP_FILE="$BUILD_DIR/$BASE_NAME.map"

echo "Compiling embedder-options"
"$CC" \
$CFLAGS \
-o "$EMBEDDER_OPTIONS_OBJ" \
-c "$EMBEDDER_OPTIONS_FILE"

echo "Converting snapshot to object file"
"$DARTINO_FLASHIFY" "--floating-point-size=$FLOATING_POINT_SIZE" "$SNAPSHOT_FILE" "$ASM_FILE"
"$CC" \
$CFLAGS \
-o "$OBJ_FILE" \
-c "$ASM_FILE"

echo "Linking application"
"$CC" \
-specs=nano.specs \
-specs=nosys.specs \
$CFLAGS \
-T"$LINKER_SCRIPT" \
-Wl,--fatal-warnings \
-Wl,--whole-archive \
-Wl,--gc-sections \
-Wl,-Map="$MAP_FILE" \
-Wl,--wrap=__libc_init_array \
-Wl,--wrap=_malloc_r \
-Wl,--wrap=_malloc_r \
-Wl,--wrap=_realloc_r \
-Wl,--wrap=_calloc_r \
-Wl,--wrap=_free_r \
-o "$ELF_FILE" \
-Wl,--start-group \
"$OBJ_FILE" \
$LIBS \
"$EMBEDDER_OPTIONS_OBJ" \
-Wl,--end-group \
-lstdc++ \
-Wl,--no-whole-archive

"$OBJCOPY" -O binary "$ELF_FILE" "$BIN_FILE"
"$OBJCOPY" -O ihex "$ELF_FILE" "$HEX_FILE"
"$SIZE" "$ELF_FILE"
