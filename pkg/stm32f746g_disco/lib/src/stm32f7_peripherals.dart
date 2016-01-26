// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32f746g.src.stm32f7_peripherals;

import 'dart:fletch.ffi';

import 'package:stm32f746g_disco/src/stm32f7_constants.dart';

final ForeignMemory peripherals =
    new ForeignMemory.fromAddress(PERIPH_BASE, 0x20000000);
