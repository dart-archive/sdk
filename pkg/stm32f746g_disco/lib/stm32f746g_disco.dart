// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library stm32f746g;

import 'lcd.dart';
import 'uart.dart';

class STM32F746GDiscovery {
  Uart _uart;
  FrameBuffer _frameBuffer;

  STM32F746GDiscovery();

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
}
