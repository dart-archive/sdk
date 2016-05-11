#!/bin/bash
# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

if [ "$1" = "-m" ]; then
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
(cd ${DIR}/../../third_party/lk; make -j4 DEBUG=1)
shift
fi

FLASHTOOL=out/build-qemu-virt-dartino-host/flashtool
if [ ! -f "$FLASHTOOL" ]; then
  echo "flashtool was not built. Please fix the LK makefile."
  exit 1
fi

if [ "$1" = "-h" ]; then
echo "Usage: $0 <options> <snapshotfile>"
echo
echo "Options:"
echo
echo "-m   trigger built of lk first"
echo "-h   print this message"
echo
exit 0
fi

if [ -z "$1" -o ! -s "$1" ]; then
echo "$0: Expecting a snapshot file as first argument."
exit 1
fi

PIPEDIR=$(mktemp -d)

cleanup_file() {
  echo "Removing '$PIPEDIR'"
  rm -rf "$PIPEDIR"
}
trap cleanup_file EXIT

mkfifo "$PIPEDIR/qemu.in" "$PIPEDIR/qemu.out"

echo "Starting qemu..."
./third_party/qemu/linux/qemu/bin/qemu-system-arm -machine virt -cpu cortex-a15 -m 128 -kernel out/build-qemu-virt-dartino/lk.elf -nographic -serial pipe:$PIPEDIR/qemu &
PID=$!
cleanup() {
  echo "Killing $PID"
  kill $PID
  cleanup_file
}
trap cleanup EXIT

echo "Started with PID $PID"

echo "Waiting for qemu to come up..."
grep -qe "entering main console loop" $PIPEDIR/qemu.out

echo "Requesting flashtool options..."
echo "dartino getinfo" > $PIPEDIR/qemu.in

echo "Waiting for response..."
while IFS='' read -r line; do
  echo $line
  if [ "$line" = $'COMMANDARGS\r' ]; then
    break;
  fi
done < $PIPEDIR/qemu.out
read -r ARGS < $PIPEDIR/qemu.out
read -r BASEADDR < $PIPEDIR/qemu.out

ARGS=$(echo $ARGS | tr -d '\n\r')
BASEADDR=$(echo $BASEADDR | tr -d '\n\r')

echo
echo "Repsonse was $ARGS"
echo "and $BASEADDR..."
echo

echo "Building program heap..."
echo
"$FLASHTOOL" $ARGS $1 $BASEADDR $PIPEDIR/heap.blob
if [ $? != 0 ]; then
  echo "Building heap blob failed..."
  echo $(pwd)/"$FLASHTOOL" $ARGS $1 $BASEADDR $PIPEDIR/heap.blob
  exit 1
fi

SIZE=$(cat $PIPEDIR/heap.blob | wc -c)

echo "Requesting run of program heap..."
echo "dartino heap" > $PIPEDIR/qemu.in

echo "Waiting for size..."
grep -qe "STEP1" $PIPEDIR/qemu.out

echo "Sending size ($SIZE)..."
echo $SIZE >$PIPEDIR/qemu.in

echo "Waiting for blob request..."
grep -qe "STEP2" $PIPEDIR/qemu.out

echo "Sending blob..."
cat $PIPEDIR/heap.blob >$PIPEDIR/qemu.in

while IFS='' read -r line; do
  echo "$line"
  if [ "$line" = $'TEARING DOWN dartino-vm...\r' ]; then
    break;
  fi
  if [ "$line" = $'Aborted (immediate)\r' ]; then
    exit 253;
  fi
  if [ "$line" = $'Aborted (scheduled)\r' ]; then
    exit 253;
  fi
  if [[ "$line" =~ "HALT: spinning forever..."* ]]; then
    exit 253;
  fi
  if [[ "$line" =~ "CRASH: starting debug shell..."* ]]; then
    exit 253;
  fi
done < $PIPEDIR/qemu.out

read -r line< $PIPEDIR/qemu.out
echo "$line"

exit ${line:11:-1}
