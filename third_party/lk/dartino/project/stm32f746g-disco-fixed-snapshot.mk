# Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE.md file.

include project/target/stm32f746g-disco.mk

MODULES += \
	app/dartino-fixed \
	lib/gfx

WITH_CPP_SUPPORT=true

# Console serial port is on pins PA9(TX) and PA10(RX)
