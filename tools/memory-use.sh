#!/bin/sh
# Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Uses binary search to find the smallest heap size that a given snapshot file
# can run.

MODE=Release
ARCH=IA32
VM=out/$MODE$ARCH/dartino-vm

if [ $# != 1 ]
then
  echo Usage: $0 filename.snap
  exit 1
fi

if [ ! -r $1 ]
then
  echo "Can't read $1"
  exit 1
fi

if ! ninja -C out/$MODE$ARCH
then
  echo Build error.
  exit 2
fi

upper=1000000
lower=4

if ! $VM -Xmax-heap-size=$upper $1
then
  echo "Failed even with no memory limit"
  exit 3
fi

while [ $upper != $lower ]
do
  median=$(((($upper + $lower) / 8) * 4))
  echo $lower-$median-$upper
  if $VM -Xmax-heap-size=$median $1
  then
    upper=$median
  else
    if [ $lower == $median ]
    then
      lower=$(($median + 4))
    else
      lower=$median
    fi
  fi
done

echo "Best successful run: -Xmax-heap-size=$upper"
echo $upper

exit 0
