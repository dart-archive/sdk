// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

import 'package:gpio/gpio.dart';
import 'package:stm32/stm32f411re_nucleo.dart';

main() {
  STM32F411RENucleo board = new STM32F411RENucleo();
  GpioOutputPin pin = board.gpio.initOutput(STM32F411RENucleo.LED2);
  while (true) {
    pin.toggle();
    sleep(500);
  }
}
