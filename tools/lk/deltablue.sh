#!/bin/sh

# Builds a VM for the stm32f746g-disco board that runs DeltaBlue benchmark and
# writes the result on the serial port.  There are a lot of things here that
# should be simpler to do!

set -e

./out/ReleaseIA32/dartino quit
ninja && ninja -C out/ReleaseIA32

./out/ReleaseIA32/dartino export benchmarks/DeltaBlue.dart to DeltaBlue.snapshot
./out/ReleaseIA32/dartino-flashify DeltaBlue.snapshot DeltaBlue.S
cp DeltaBlue.S third_party/lk/dartino/app/dartino-fixed/dartino_program.S

(cd third_party/lk/; PROJECT=stm32f746g-disco-fixed-snapshot make)

./tools/lk/flash-image.sh third_party/lk/out/build-stm32f746g-disco-fixed-snapshot/lk.bin
