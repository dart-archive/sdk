// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32.stm32f746g_discovery;

import 'package:gpio/gpio.dart';
import 'package:stm32/gpio.dart';
import 'package:stm32/lcd.dart';
import 'package:stm32/ts.dart';
import 'package:stm32/uart.dart';

class STM32F746GDiscovery {
  /// GPIO pin for on-board green LED.
  static const Pin LED1 = STM32Pin.PI1;
  /// GPIO pin for on-board blue button.
  static const Pin Button1 = STM32Pin.PI11;

  /// GPIO pins on the Arduino connector.
  static const Pin A0 = STM32Pin.PA0;
  static const Pin A1 = STM32Pin.PF10;
  static const Pin A2 = STM32Pin.PF9;
  static const Pin A3 = STM32Pin.PF8;
  static const Pin A4 = STM32Pin.PF7;
  static const Pin A5 = STM32Pin.PF6;

  STM32Gpio _gpio;
  Uart _uart;
  FrameBuffer _frameBuffer;
  TouchScreen _touchScreen;

  STM32F746GDiscovery();

  Gpio get gpio {
    if (_gpio == null) {
      _gpio = new STM32Gpio();
    }
    return _gpio;
  }

  Uart get uart {
    if (_uart == null) {
      _uart = new Uart();
    }
    return _uart;
  }

  FrameBuffer get frameBuffer {
    if (_frameBuffer == null) {
      _frameBuffer = new FrameBuffer();
    }
    return _frameBuffer;
  }

  TouchScreen get touchScreen {
    if (_touchScreen == null) {
      _touchScreen =
        new TouchScreen.init(frameBuffer.width, frameBuffer.height);
    }
    return _touchScreen;
  }
}
