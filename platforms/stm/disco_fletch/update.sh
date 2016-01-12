#!/usr/bin/env bash
# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Update the generated source and template files from STMCubeMX. Right
# not the source file is disco_fletch.tar.gz - a tar of the generated
# project from a Windows machine.

set -e

tar xf disco_fletch.tar.gz

for SRC in disco_fletch/Inc/*
do
  BASENAME=$(basename "$SRC")
  if test "$BASENAME" != "FreeRTOSConfig.h"
  then
    echo "$SRC"
    DEST=generated/Inc/$BASENAME
    cp "$SRC" "$DEST"
    dos2unix -q $DEST
    sed -i 's/[ \t]*$//' "$DEST"
  fi
done

for SRC in disco_fletch/Src/* $SRC_FILES
do
  BASENAME=$(basename "$SRC")
  if test "$BASENAME" != "freertos.c"
  then
    echo "$SRC"
    DEST=generated/Src/$BASENAME
    cp "$SRC" "$DEST"
    dos2unix -q "$DEST"
    sed -i 's/[ \t]*$//' "$DEST"
  fi
done

# Modify generated main.c to expose the MX_ initialization functions
# and not implement main.
sed -i 's/static void MX_/void MX_/' generated/Src/main.c
sed -i 's/int main/int _not_using_this_main/' generated/Src/main.c
mv generated/Src/main.c generated/Src/mx_init.c

SRC="disco_fletch/SW4STM32/disco_fletch Configuration/STM32F746NGHx_FLASH.ld"
echo "$SRC"
cp  "$SRC" generated/SW4STM32/configuration/STM32F746NGHx_FLASH.ld
dos2unix -q generated/SW4STM32/configuration/STM32F746NGHx_FLASH.ld

SRC="disco_fletch/Drivers/CMSIS/Device/ST/STM32F7xx/Source/Templates/gcc/startup_stm32f746xx.s"
echo "$SRC"
cp "$SRC" template/startup_stm32f746xx.s
dos2unix -q template/startup_stm32f746xx.s

# Don't copy the disco_fletch/Drivers/CMSIS/Device/ST/STM32F7xx/Source/
# Templates/system_stm32f7xx.c file, as the one provided by
# STM32CubeMX is the wrong one. It is the one for the EVAL2 board
# and not the Discovery board.

cp disco_fletch/disco_fletch.ioc disco_fletch.ioc
dos2unix -q disco_fletch.ioc

rm -rf disco_fletch
