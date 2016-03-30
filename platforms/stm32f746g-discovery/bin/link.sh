#!/bin/bash
# Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Script to link a Dart snapshot with the FreeRTOS Dartino embedding.
#
# In the Dartino SDK this is located in platforms/stm32f746g-discovery/bin.

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <base name> [<build dir>]"
  exit 1
fi
BASE_NAME=$1

# Snapshot file most be called snapshot for objcopy to work for us.
# The symbols in the output from objcopy are generated from the actual
# file name passed (including directory components and extension).
# I the C-code we have the following declarations to find the snapshot
# in the image:
#
#   extern unsigned char _binary_snapshot_start;
#   extern unsigned char _binary_snapshot_end;
#   extern unsigned char _binary_snapshot_size;
#
SNAPSHOT_FILE=snapshot

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

if [ ! -z "$2" ]; then
  BUILD_DIR=$2
fi

# The static libraries to link with.
LIB1="$LIB_DIR/libdartino.a"
LIB2="$LIB_DIR/libdisco_dartino.a"
LIB3="$LIB_DIR/libstm32f746g-discovery.a"

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

echo "Converting snapshot to object file"
"$DARTINO_FLASHIFY" "$SNAPSHOT_FILE" "$ASM_FILE"
"$CC" \
-mcpu=cortex-m7 \
-mthumb \
-o "$OBJ_FILE" \
-c "$ASM_FILE"

echo "Linking application"
"$CC" \
-specs=nano.specs \
-specs=nosys.specs \
-mcpu=cortex-m7 \
-mthumb \
-mfloat-abi=hard \
-mfpu=fpv5-sp-d16 \
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
"$LIB1" \
"$LIB2" \
"$LIB3" \
-Wl,--end-group \
-lstdc++ \
-Wl,--no-whole-archive

"$OBJCOPY" -O binary "$ELF_FILE" "$BIN_FILE"
"$OBJCOPY" -O ihex "$ELF_FILE" "$HEX_FILE"
"$SIZE" "$ELF_FILE"
