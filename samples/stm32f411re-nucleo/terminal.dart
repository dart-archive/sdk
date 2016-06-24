// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// This samples listens for 'terminal commands' being entered into a terminal
// on the PC which is connected to the embedded device.
//
// To run the sample:
//
// 1. Open a Terminal window, and connect to the embedded device:
//    - On a Mac (replace XXX with the current mount point)
//    $ screen /dev/tty.usbmodemXXX 115200
//    - On Linux (replace X with the current mount point)
//    $ screen /dev/ttyACMX 115200
//
// 2. Run this sample. You should see the text 'Welcome to the terminal!'
//    along with a list of commands in the terminal.
//
// 3. Type in terminal commands in the terminal.
//
// 4. See the result on the embedded device.

import 'dart:dartino';
import 'dart:typed_data';

import 'package:gpio/gpio.dart';
import 'package:stm32/stm32f411re_nucleo.dart';
import 'package:stm32/uart.dart';

main() {
  Terminal terminal = new Terminal();
  while (true) {
    terminal.processCommand(terminal.getNextCommand());
  }
}

class Terminal {
  GpioOutputPin pin;
  Uart uart;

  Terminal() {
    STM32F411RENucleo board = new STM32F411RENucleo();
    pin = board.gpio.initOutput(STM32F411RENucleo.LED2);
    uart = board.uart;
    _log("Welcome to the terminal!");
    help();
  }

  void _log(String msg) {
    uart.writeString('$msg\r\n');
  }

  void help() {
    _log("Valid commands:");
    _log("  t: toggle LED");
    _log("  s <time>: sleep for <time> milliseconds");
    _log("  h: show list of commands");
    _log("Enter one command per line, or multiple seperated by commas.");
  }

  /// Read input from a Uart until a line feed is seen.
  /// Return result as a string.
  String getNextCommand() {
    const int CR = 13;
    const int backSpace = 127;

    String result = "";
    while (true) {
      var data = new Uint8List.view(uart.readNext());
      for (int i = 0; i < data.length; i++) {
        var nextByte = data[i];

        if (nextByte == backSpace) {
          if (result.length > 0) {
            uart.writeString("\b");
            result = result.substring(0, result.length - 1);
          }
        } else if (nextByte == CR) {
          uart.writeString('\r\n');
          return result;
        } else {
          result = result + new String.fromCharCode(nextByte);
          uart.writeByte(nextByte);
        }
      }
    }
  }

  void processCommand(String command) {
    // Split string by ',' and process each seperately.
    command.split(',').forEach(_parseCommand);
  }

  void _parseCommand(String command) {
    List<String> commandParts = command.trim().split(' ');
    if (commandParts.length < 1 || commandParts.length > 2) {
      _log("Unknown terminal command/argument: '$command'");
      return;
    }

    // Parse the argument.
    int arg;
    if (commandParts.length > 1) {
      arg = int.parse(commandParts[1], onError: (_) => null);
      if (arg == null) {
        _log("Unknown terminal command/argument '$command'");
        return;
      }
    }

    // Parse the command.
    switch (commandParts[0]) {
      case 's':
        if (arg == null) {
          _log("Unknown terminal command/argument '$command'");
        } else {
          sleep(arg);
        }
        break;
      case 't':
        pin.toggle();
        break;
      case 'h':
        help();
        break;
      default:
        _log("Unknown terminal command '$command'");
        break;
    }
  }
}
