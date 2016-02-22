# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

include project/target/stm32f746g-disco.mk

MODULES += app/dartino app/shell lib/gfx

ARCH_arm_COMPILEFLAGS += -mfpu=fpv4-sp-d16 -mfloat-abi=hard

DARTINO_CONFIGURATION = LKFull
DARTINO_GYP_DEFINES = "LK_PROJECT=stm32f746g-disco-dartino LK_CPU=cortex-m4 LK_FPU=fpv4-sp-d16 LK_FLOAT-ABI=hard"

WITH_CPP_SUPPORT=true

# Console serial port is on pins PA9(TX) and PA10(RX)
