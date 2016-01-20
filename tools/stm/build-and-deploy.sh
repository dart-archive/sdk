#!/bin/bash
# Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Temporary script to build and flash a Dart application on the
# discovery board.

# To run on Linux first build
# $ ninja -C out/ReleaseX64
# $ ninja -C out/DebugSTM

# To run on Mac first build
# $ ninja -C out/ReleaseX64
# Then copy a DebugSTM directory from a Linux machine, as that part does not
# build on Mac

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

TOOLCHAIN_PREFIX=third_party/gcc-arm-embedded/$OS/gcc-arm-embedded/bin/arm-none-eabi-
CC=${TOOLCHAIN_PREFIX}gcc
OBJCOPY=${TOOLCHAIN_PREFIX}objcopy

BUILDDIR=out/DebugSTM

echo "Generating snapshot"
out/ReleaseX64/fletch export $1 to file snapshot

# Get the dart file relative to out/DebugSTM.
OUT_RELATIVE_DART_FILE=$DART_FILE
if [[ "$OUT_RELATIVE_DART_FILE" != /* ]]; then
  OUT_RELATIVE_DART_FILE=../../$DART_FILE
fi

cd out/DebugSTM

../../out/ReleaseX64/fletch export $OUT_RELATIVE_DART_FILE to file snapshot
../../$OBJCOPY -I binary -O elf32-littlearm -B arm snapshot snapshot.o
cd ../..

echo "Converting snapshot to object file"
$OBJCOPY -I binary -O elf32-littlearm -B arm snapshot snapshot.o

echo "Linking application"
# Linker options required with https://codereview.chromium.org/1607793003/.
#-Wl,--wrap=__libc_init_array \
#-Wl,--wrap=_malloc_r \
#-Wl,--wrap=_malloc_r \
#-Wl,--wrap=_realloc_r \
#-Wl,--wrap=_calloc_r \
#-Wl,--wrap=_free_r \
$CC \
-specs=nano.specs \
-Tplatforms/stm/disco_fletch/generated/SW4STM32/configuration/STM32F746NGHx_FLASH.ld \
-Wl,--whole-archive \
-Wl,--gc-sections \
-mcpu=cortex-m7 \
-mthumb \
-mfloat-abi=hard \
-mfpu=fpv5-sp-d16 \
-Wl,-Map=output.map \
-Wl,--gc-sections \
-o disco_fletch.elf \
-Wl,--start-group \
snapshot.o \
$BUILDDIR/obj/platforms/stm/disco_fletch/libdisco_fletch.a \
$BUILDDIR/libfletch_vm_library.a \
$BUILDDIR/libfletch_shared.a \
$BUILDDIR/libdouble_conversion.a \
-Wl,--end-group \
-lstdc++ \
-Wl,--no-whole-archive

echo "Generating flashable image"
$OBJCOPY -O binary disco_fletch.elf disco_fletch.bin

echo "Flashing image"
tools/lk/flash-image.sh --disco disco_fletch.bin
