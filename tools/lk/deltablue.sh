#!/bin/sh

# Builds a VM for the stm32f746g-disco board that runs DeltaBlue benchmark and
# writes the result on the serial port.  There are a lot of things here that
# should be simpler to do!

set -e

./out/ReleaseIA32/dartino quit
ninja && ninja -C out/ReleaseX64 && ninja -C out/ReleaseIA32

./out/ReleaseIA32/dartino export benchmarks/DeltaBlue.dart to lines.snapshot

(cd third_party/lk/; PROJECT=stm32f746g-disco-fixed-snapshot make -j8)

./tools/lk/embed_program_in_binary.sh --dartino out/ReleaseIA32 third_party/lk/out/build-stm32f746g-disco-fixed-snapshot/lk.elf lines.snapshot lines

cp lines.o third_party/lk/dartino/app/dartino-fixed/lines.o

(cd third_party/lk/; PROJECT=stm32f746g-disco-fixed-snapshot make -j8)

./tools/lk/flash-image.sh third_party/lk/out/build-stm32f746g-disco-fixed-snapshot/lk.bin
