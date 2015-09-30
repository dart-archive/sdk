#!/bin/bash

if [ "$1" == "-m" ]; then
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
(cd ${DIR}/../../third_party/lk; make -j4 DEBUG=1)
shift
fi

if [ "$1" == "-h" ]; then
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
echo "$0: Expecting a snapshot file as fist argument."
exit 1
fi

SIZE=$(cat $1 | wc -c)
PIPEDIR=$(mktemp -d)

cleanup_file() {
  rm -rf "$PIPEDIR"
}
trap cleanup_file EXIT INT TERM HUP

mkfifo "$PIPEDIR/qemu.in" "$PIPEDIR/qemu.out"

echo "Starting qemu..."
./third_party/bin/linux/qemu/qemu-system-arm -machine virt -cpu cortex-a15 -m 16 -kernel third_party/lk/out/build-qemu-virt-fletch/lk.elf -nographic -serial pipe:$PIPEDIR/qemu &
PID=$!
cleanup() {
  cleanup_file
  echo "Killing $PID"
  kill $PID
}
trap cleanup EXIT INT TERM HUP

echo "Started with PID $PID"

echo "Waiting for qemu to come up..."
grep -qe "entering main console loop" $PIPEDIR/qemu.out

echo "Starting fletch..."
echo "fletch" > $PIPEDIR/qemu.in

echo "Waiting for size..."
grep -qe "STEP1" $PIPEDIR/qemu.out

echo "Sending size ($SIZE)..."
echo $SIZE >$PIPEDIR/qemu.in

echo "Waiting for snapshot request..."
grep -qe "STEP2" $PIPEDIR/qemu.out

echo "Sending snapshot..."
cat $1 >$PIPEDIR/qemu.in

while IFS='' read -r line; do
  echo "$line"
  if [ "$line" = $'TEARING DOWN fletch-vm...\r' ]; then
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
done < $PIPEDIR/qemu.out

read -r line< $PIPEDIR/qemu.out
echo "$line"

exit ${line:11:-1}
