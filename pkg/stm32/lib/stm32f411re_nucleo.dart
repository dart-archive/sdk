// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.stm32f411re_nucleo;

import 'package:gpio/gpio.dart';
import 'package:stm32/gpio.dart';
//import 'package:stm32/uart.dart';
import 'package:stm32/src/constants.dart';

class STM32F411RENucleo {
  /// GPIO pin for on-board green LED.
  static const Pin LED2 = STM32Pin.PA5;
  /// GPIO pin for on-board blue button.
  static const Pin Button1 = STM32Pin.PC13;

  /// GPIO pins on the Arduino connector.
  static const Pin A0 = STM32Pin.PA0;
  static const Pin A1 = STM32Pin.PA1;
  static const Pin A2 = STM32Pin.PA4;
  static const Pin A3 = STM32Pin.PB0;
  static const Pin A4 = STM32Pin.PC1;
  static const Pin A5 = STM32Pin.PC0;

  STM32Gpio _gpio;

  STM32F411RENucleo();

  Gpio get gpio {
    if (_gpio == null) {
      _gpio = new STM32Gpio();
    }
    return _gpio;
  }
}
