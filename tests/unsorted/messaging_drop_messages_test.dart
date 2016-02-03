// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:dartino';

import 'package:expect/expect.dart';

main(arguments) {
  var forceGC = (arguments.length == 1) ? arguments[0] : null;
  // Create a port but throw away the channel.
  var port = new Port(new Channel());
  if (forceGC != null) forceGC();
  // Send a number of messages to the port.
  for (int i = 0; i < 10; i++) port.send(i);
  // Create another port and send and receive a message.
  var channel = new Channel();
  port = new Port(channel);
  port.send(42);
  Expect.equals(42, channel.receive());
}
