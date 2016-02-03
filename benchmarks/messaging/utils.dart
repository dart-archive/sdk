// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library messaging.utils;

import 'dart:dartino';

const int DEFAULT_MESSAGES = 1000;

void channelResponder(Channel output) {
  Channel input = new Channel();
  output.send(input);
  int message;
  do {
    message = input.receive();
    output.send(message - 1);
  } while (message > 0);
}

void portResponder(Port output) {
  Channel input = new Channel();
  output.send(new Port(input));
  int message;
  do {
    message = input.receive();
    output.send(message - 1);
  } while (message > 0);
}
