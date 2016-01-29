#!/bin/bash
# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Temporary script for testing the circular buffer.

g++ \
  -I. \
  -DFLETCH_TARGET_OS_POSIX \
  --std=gnu++11 \
  platforms/stm/disco_fletch/src/circular_buffer_test.cc \
  platforms/stm/disco_fletch/src/circular_buffer.cc \
  src/shared/assert.cc \
  src/shared/platform_posix.cc src/shared/platform_linux.cc \
  src/shared/utils.cc

./a.out
