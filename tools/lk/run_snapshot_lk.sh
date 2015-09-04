#!/bin/bash

if [ -z "$1" -o ! -s "$1" ]; then
echo "$0: Expecting a snapshot file as fist argument."
exit 1
fi
PORT=${2-/dev/ttyUSB0}

if [ ! -c "$PORT" ]; then
echo "$0: $PORT is not a valid character device."
exit 2
fi

SIZE=`cat $1 | wc -c`

echo "fletch" >$PORT
sleep 1
echo $SIZE >$PORT
sleep 1
cat $1 >$PORT
