#!/usr/bin/env bash
# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Update the generated source and template files from STMCubeMX. Right
# not the source file is disco_dartino.tar.gz - a tar of the generated
# project from a Windows machine.

set -e

tar xf disco_dartino.tar.gz

CUBEMX_PROJECT=disco_dartino

for SRC in $CUBEMX_PROJECT/Inc/*
do
  BASENAME=$(basename "$SRC")
  if test "$BASENAME" != "FreeRTOSConfig.h"
  then
    echo "$SRC"
    DEST=generated/$BASENAME
    cp "$SRC" "$DEST"
    dos2unix -q $DEST
    sed -i 's/[ \t]*$//' "$DEST"
  fi
done

for SRC in $CUBEMX_PROJECT/Src/* $SRC_FILES
do
  BASENAME=$(basename "$SRC")
  if test "$BASENAME" != "freertos.c"
  then
    echo "$SRC"
    DEST=generated/$BASENAME
    cp "$SRC" "$DEST"
    dos2unix -q "$DEST"
    sed -i 's/[ \t]*$//' "$DEST"
  fi
done

# Modify generated main.c to expose the MX_ initialization functions
# and not implement main.
sed -i 's/static void MX_/void MX_/' generated/main.c
sed -i 's/int main/int _not_using_this_main/' generated/main.c
mv generated/Src/main.c generated/Src/mx_init.c

SRC="$CUBEMX_PROJECT/SW4STM32/disco_dartino/STM32F746NGHx_FLASH.ld"
echo "$SRC"
cp  "$SRC" STM32F746NGHx_FLASH.ld
dos2unix -q STM32F746NGHx_FLASH.ld

SRC="$CUBEMX_PROJECT/Drivers/CMSIS/Device/ST/STM32F7xx/Source/Templates/gcc/startup_stm32f746xx.s"
echo "$SRC"
cp "$SRC" template/startup_stm32f746xx.s
dos2unix -q template/startup_stm32f746xx.s

# Don't copy the disco_dartino/Drivers/CMSIS/Device/ST/STM32F7xx/Source/
# Templates/system_stm32f7xx.c file, as the one provided by
# STM32CubeMX is the wrong one. It is the one for the EVAL2 board
# and not the Discovery board.

cp "$CUBEMX_PROJECT/disco_dartino.ioc" disco_dartino.ioc
dos2unix -q disco_dartino.ioc

rm -rf disco_dartino
