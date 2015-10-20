#!/bin/bash
# Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

BOARD="stm32756g_eval"
STLINK="stlink-v2-1"

while [ $# -gt 1 ]; do
  case $1 in
    --disco | -d)
      BOARD="stm32756g_eval"
      STLINK="stlink-v2-1"
      shift
      ;;
    --nucleo | -n)
      BOARD="st_nucleo_f4"
      STLINK="stlink-v2-1"
      shift
      ;;
    --board | -b)
      BOARD="$2"
      shift 2
      ;;
    --link | -l)
      STLINK="$2"
      shift 2
      ;;
    --openocd | -o)
      OPENOCDHOME=$2
      shift 2
      ;;
    --help | -h)
      echo "Options: --disco or -d    Use discovery f7 board configuration"
      echo "         --nucleo or -n   Use nucleo F4 board configuration"
      echo "         --board or -b    Manually set board name"
      echo "         --link or -l     Manually set debug link type"
      echo "         --openocd or -o  Set openocd home directory"
      echo "         --help or -h     Print this message"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

if [ -z "$OPENOCDHOME" ]; then
  echo "Set \$OPENOCDHOME to the path where your openocd lives..."
  exit 1
fi

if [ ! -e $1 ]; then
  echo "Image file does not exist: $1."
  exit 1
fi

$OPENOCDHOME/src/openocd -f interface/${STLINK}.cfg -f board/${BOARD}.cfg --search $OPENOCDHOME/tcl -c "init" -c "reset halt" -c "flash write_image erase $1 0x8000000" -c "reset run" -c "shutdown"

