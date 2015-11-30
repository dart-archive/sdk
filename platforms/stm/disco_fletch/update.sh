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
  DEST=generated/Inc/$(basename "$SRC")
  cp $SRC $DEST
  dos2unix -q $DEST
  sed -i 's/[ \t]*$//' $DEST
done

for SRC in disco_fletch/Src/* $SRC_FILES
do
  DEST=generated/Src/$(basename "$SRC")
  cp $SRC $DEST
  dos2unix -q $DEST
  sed -i 's/[ \t]*$//' $DEST
done

cp "disco_fletch/SW4STM32/disco_fletch Configuration/STM32F746NGHx_FLASH.ld" \
  generated/SW4STM32/configuration/STM32F746NGHx_FLASH.ld
dos2unix -q generated/SW4STM32/configuration/STM32F746NGHx_FLASH.ld

cp disco_fletch/Drivers/CMSIS/Device/ST/STM32F7xx/Source/Templates/gcc/startup_stm32f746xx.s \
  template/startup_stm32f746xx.s
dos2unix -q template/startup_stm32f746xx.s

cp disco_fletch/Drivers/CMSIS/Device/ST/STM32F7xx/Source/Templates/system_stm32f7xx.c \
  template/system_stm32f7xx.c
dos2unix -q template/system_stm32f7xx.c

cp disco_fletch/disco_fletch.ioc disco_fletch.ioc
dos2unix -q disco_fletch.ioc

rm -rf disco_fletch
