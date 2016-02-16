// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// This samples listens for 'turtle commands' being entered into a terminal
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
// 2. Run this sample. You should see the text 'Turtle is awake waiting for your
//    command!' in the terminal.
//
// 3. Type in turtle commands in the terminal.
//
// 4. See the resulting turtle graphics in the embedded device. This uses the
//    Turtle definition in turtle.dart.

import 'dart:typed_data';
import 'package:stm32f746g_disco/stm32f746g_disco.dart';
import 'package:stm32f746g_disco/lcd.dart';
import 'package:stm32f746g_disco/uart.dart';
import 'turtle.dart' show Turtle;

main() {
  Uart uart = new Uart();
  void writeMessage(String message) {
    uart.writeString('$message\r\n');
  }
  TurtleCommander turtleCommander =
      new TurtleCommander(new STM32F746GDiscovery().frameBuffer, writeMessage);

  while (true) {
    turtleCommander.processCommand(getNextCommand(uart));
  }
}

/// Read input from a Uart until a line feed is seen. Return result as a string.
String getNextCommand(Uart uart) {
  const int CR = 13;
  const int backSpace = 127;

  String result = "";
  while (true) {
    var data = new Uint8List.view(uart.readNext());
    for (int i = 0; i < data.length; i++) {
      var nextByte = data[i];

      if (nextByte == backSpace) {
        uart.writeString("\b");
        result = result.substring(0, result.length - 1);
      } else if (nextByte == CR) {
        uart.writeString('\r\n');
        return result;
      } else {
        result = result + new String.fromCharCode(nextByte);
        // TODO: Update this to the new API
        uart.writeByte(nextByte);
      }
    }
  }
}

class TurtleCommander {
  Turtle turtle;
  Function msg;

  TurtleCommander(FrameBuffer frameBuffer, this.msg) {
    turtle = new Turtle(frameBuffer, xPosition: 200, yPosition: 200);

    frameBuffer.writeText(10,10,
      "Connect a terminal, and enter turtle commands.");
    msg("Turtle is awake waiting for your command! Valid commands:\r\n");
    msg("f <distance>: forward <distance> pixels.");
    msg("t <degrees>: turn <degrees> left.");
    msg("Enter one command per line, or multiple seperated by commas.");
  }

  void processCommand(String command) {
    // Split string by ',' and process each seperately.
    command.split(',').forEach(_parseCommand);
  }

  void _parseCommand(String command) {
    List<String> commandParts = command.trim().split(' ');
    if (commandParts.length != 2) {
      msg("Unknown turtle command, please enter command and argument");
    } else {
      // Parse the argument.
      int arg = int.parse(commandParts[1], onError: (_) => null);
      if (arg == null) {
        msg("Unknown turtle command/argument '$command'");
      }

      // Parse the command.
      String cmd = commandParts[0];
      switch (cmd) {
        case 'f':
          msg("turtle: forward $arg");
          turtle.forward(arg);
          break;
        case 't':
          int arg = int.parse(commandParts[1]);
          msg("turtle: turn $arg");
          turtle.turnLeft(arg);
          break;
        default:
          msg("Unknown turtle command '$cmd'");
      }
    }
  }
}
