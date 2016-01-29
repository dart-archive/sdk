#!/bin/sh
# Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# Temporary script for testing the compact malloc.
rm a.out

set -e

gcc \
  -g \
  -Og \
  -I. \
  -DFLETCH_TARGET_OS_POSIX \
  -DNO_NEWLIB_REENT \
  -std=gnu99  \
  platforms/stm/disco_fletch/src/cmpctmalloc.c \
  -c \
  -o cmpctmalloc.o

g++ \
  -g \
  -Og \
  -I. \
  -DFLETCH_TARGET_OS_POSIX \
  -DNO_NEWLIB_REENT \
  --std=gnu++11 \
  platforms/stm/disco_fletch/src/page_allocator.cc \
  platforms/stm/disco_fletch/src/cmpctmalloc_test.cc \
  src/shared/assert.cc \
  src/shared/platform_posix.cc src/shared/platform_linux.cc \
  src/shared/utils.cc \
  cmpctmalloc.o

./a.out
