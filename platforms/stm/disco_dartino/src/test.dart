// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';
import 'dart:typed_data';

import 'package:stm32/button.dart';
import 'package:stm32/uart.dart';
import 'package:stm32/stm32f746g_disco.dart';

main() {
  const int CR = 13;
  const int LF = 10;
  ByteData LFData = new ByteData(1);
  LFData.setUint8(0, LF);
  ByteBuffer LFBuffer = LFData.buffer;

  STM32F746GDiscovery disco = new STM32F746GDiscovery();
  Uart uart = disco.uart;

  Button button = new Button();

  Fiber.fork(() {
    while (true) {
      button.waitForPress();
      // Use print("...\n") to print to both the serial port and the LCD.
      uart.writeString("Button press received\r\n");
    }
  });

  // Use print("...\n") to print to both the serial port and the LCD.
  uart.writeString("\rWelcome to Dart UART echo!\r\n");
  uart.writeString("--------------------------\r\n");
  uart.write(LFBuffer);
  while (true) {
    ByteBuffer input = uart.readNext();
    // Map CR to CR+LF for nicer console output.
    int offset = 0;
    while (true) {
      int index = input.asUint8List().indexOf(CR, offset);
      if (index == -1) {
        uart.write(input, offset);
        break;
      }
      index += 1;
      uart.write(input, offset, index);
      uart.write(LFBuffer);
      offset = index;
    }
  }
}
