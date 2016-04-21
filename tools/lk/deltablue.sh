#!/bin/sh

# Builds a VM for the stm32f746g-disco board that runs DeltaBlue benchmark and
# writes the result on the serial port.

set -e

./out/ReleaseIA32/dartino quit
ninja && ninja -C out/ReleaseIA32

./out/ReleaseIA32/dartino export benchmarks/DeltaBlue.dart to DeltaBlue.snapshot
./out/ReleaseIA32/dartino-flashify DeltaBlue.snapshot DeltaBlue.S
cp DeltaBlue.S third_party/lk/dartino/app/dartino-fixed/dartino_program.S

PROJECT=stm32f746g-disco-fixed-snapshot DEBUG= make -C third_party/lk -j8

./tools/lk/flash-image.sh out/build-stm32f746g-disco-fixed-snapshot/lk.bin
