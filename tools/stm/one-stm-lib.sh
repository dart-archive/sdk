#!/bin/sh
# Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Temporary script to build one -a file for use bu the build-and-deploy.sh script.

pkill -9 dart
rm -rf out

set -e

ninja
ninja -C out/ReleaseX64
ninja -C out/ReleaseSTM disco_dartino
ninja -C out/DebugSTM disco_dartino

cd out/ReleaseSTM
../../third_party/gcc-arm-embedded/linux/gcc-arm-embedded/bin/arm-none-eabi-ar \
  -M < ../../tools/stm/one-stm-lib.ar
cd ../..
cd out/DebugSTM
../../third_party/gcc-arm-embedded/linux/gcc-arm-embedded/bin/arm-none-eabi-ar \
  -M < ../../tools/stm/one-stm-lib.ar
cd ../..
