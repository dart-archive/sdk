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

### TODO(sgjesse): Maybe source this part

# Handle the case where dartino-sdk/bin has been symlinked to.
SCRIPT_DIR="$(cd "${PROG_NAME%/*}" ; pwd -P)"

# Root of the Dartino SDK, that is, $SCRIPT_DIR/../../...
DARTINO_SDK_DIR=$SCRIPT_DIR
DARTINO_SDK_DIR="$(dirname "$DARTINO_SDK_DIR")"
DARTINO_SDK_DIR="$(dirname "$DARTINO_SDK_DIR")"
DARTINO_SDK_DIR="$(dirname "$DARTINO_SDK_DIR")"

# Location of the GCC ARM embedded toolchain in the Dartino SDK.
TOOLCHAIN_DIR="$DARTINO_SDK_DIR/tools/gcc-arm-embedded"

# Location of the Dartino executable.
DARTINO="$DARTINO_SDK_DIR/bin/dartino"

# Location of the static libraries to link with.
LIB_DIR="$DARTINO_SDK_DIR/platforms/stm32f746g-discovery/lib"

# The linker script to use.
CONFIG_DIR="$DARTINO_SDK_DIR/platforms/stm32f746g-discovery/config"
LINKER_SCRIPT="$CONFIG_DIR/stm32f746g-discovery.ld"

# TODO(sgjesse): Figure out the build dir to use.
BUILD_DIR=.

# If we are not in a Dartino SDK, assume a Dartino SDK Github checkout.
if [ ! -d "$TOOLCHAIN_DIR" ]; then
  # Relative locations in Dartino SDK and Dartino SDK Github checkout
  # are the same.
  DARTINO_CHECKOUT_DIR=$DARTINO_SDK_DIR
  # Location of the GCC ARM embedded toolchain in a Dartino SDK Github
  # checkout.
  TOOLCHAIN_DIR="$DARTINO_CHECKOUT_DIR/third_party/gcc-arm-embedded/$OS/gcc-arm-embedded"

  # Use release dartinu command in a Dartino SDK Github checkout.
  DARTINO="$DARTINO_CHECKOUT_DIR/out/ReleaseX64/dartino"

  # Location of the static libraries to link with.
  LIB_DIR="$DARTINO_CHECKOUT_DIR/out/ReleaseSTM"

  # The linker script to use.
  LINKER_SCRIPT="$DARTINO_CHECKOUT_DIR/platforms/stm/disco_dartino/generated/SW4STM32/configuration/STM32F746NGHx_FLASH.ld"

  BUILD_DIR="$DARTINO_CHECKOUT_DIR/out/DebugSTM"
fi

### TODO(sgjesse): End of maybe source this part

# The static libraries to link with.
LIB1="$LIB_DIR/libdartino_vm_library.a"
LIB2="$LIB_DIR/libdartino_shared.a"
LIB3="$LIB_DIR/libdouble_conversion.a"
LIB4="$LIB_DIR/libdisco_dartino.a"

# Paths to to gcc and objcopy.
TOOLCHAIN_PREFIX="$TOOLCHAIN_DIR/bin/arm-none-eabi-"
CC="${TOOLCHAIN_PREFIX}gcc"
OBJCOPY="${TOOLCHAIN_PREFIX}objcopy"
SIZE="${TOOLCHAIN_PREFIX}size"

echo "Compiling snapshot of $DART_FILE"
"$DARTINO" export "$DART_FILE" to file snapshot

echo "Converting snapshot to object file"
"$OBJCOPY" -I binary -O elf32-littlearm -B arm snapshot snapshot.o

BASE_NAME="$(basename "$DART_FILE" .dart)"
echo "Linking application"
"$CC" \
-specs=nano.specs \
-T"$LINKER_SCRIPT" \
-Wl,--whole-archive \
-Wl,--gc-sections \
-mcpu=cortex-m7 \
-mthumb \
-mfloat-abi=hard \
-mfpu=fpv5-sp-d16 \
-Wl,-Map=output.map \
-Wl,--gc-sections \
-Wl,--wrap=__libc_init_array \
-Wl,--wrap=_malloc_r \
-Wl,--wrap=_malloc_r \
-Wl,--wrap=_realloc_r \
-Wl,--wrap=_calloc_r \
-Wl,--wrap=_free_r \
-o "$BUILD_DIR/$BASE_NAME.elf" \
-Wl,--start-group \
"$BUILD_DIR/snapshot.o" \
"$LIB1" \
"$LIB2" \
"$LIB3" \
"$LIB4" \
-Wl,--end-group \
-lstdc++ \
-Wl,--no-whole-archive

"$OBJCOPY" -O binary "$BUILD_DIR/$BASE_NAME.elf" "$BUILD_DIR/$BASE_NAME.bin"
"$SIZE" "$BUILD_DIR/$BASE_NAME.elf"

echo "\nFinishing building flashable image: $BUILD_DIR/$BASE_NAME.bin"
