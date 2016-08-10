#!/bin/sh

# Builds a VM for the stm32f746g-disco board that runs disco-dartino project
# (from third_party/lk/dartino/project/stm32f746g-disco-dartino.mk.).

set -e

PROJECT=stm32f746g-disco-dartino make -C third_party/lk -j8

./tools/embedded/flash-image.sh out/build-stm32f746g-disco-dartino/lk.bin
