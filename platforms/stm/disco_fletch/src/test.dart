// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:typed_data';

import 'package:stm32f746g_disco/uart.dart';
import 'package:stm32f746g_disco/stm32f746g_disco.dart';

main() {
  const int CR = 13;
  const int LF = 10;

  STM32F746GDiscovery disco = new STM32F746GDiscovery();
  Uart uart = disco.uart;

  uart.writeString("\rWelcome to Dart UART echo!\r\n");
  uart.writeString("--------------------------\r\n");
  while (true) {
    var data = new Uint8List.view(uart.readNext());
    // Map CR to CR+LF for nicer console output.
    if (data.indexOf(CR) != -1) {
      for (int i = 0; i < data.length; i++) {
        var byte = data[i];
        uart.writeByte(byte);
        if (byte == CR) {
          uart.writeByte(LF);
        }
      }
    } else {
      uart.write(data.buffer);
    }
  }
}
