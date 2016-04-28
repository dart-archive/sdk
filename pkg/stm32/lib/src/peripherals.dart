// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.src.peripherals;

import 'dart:dartino.ffi';

import 'package:stm32/src/constants.dart';

final ForeignMemory peripherals =
    new ForeignMemory.fromAddress(PERIPH_BASE, 0x20000000);
