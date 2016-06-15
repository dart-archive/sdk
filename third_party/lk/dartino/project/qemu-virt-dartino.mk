# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

# main project for qemu-arm
TARGET := qemu-virt
ARCH := arm
ARM_CPU := cortex-a15

MEMSIZE := 0x1000000  # 16MB

MODULES += \
	app/shell \
	app/dartino \
	lib/evlog \

GLOBAL_DEFINES += WITH_KERNEL_EVLOG=1 LOADER_BUFFER_SIZE=5000

DARTINO_CONFIGURATION = LKFull

WITH_CPP_SUPPORT=true

#WITH_LINKER_GC := 0
