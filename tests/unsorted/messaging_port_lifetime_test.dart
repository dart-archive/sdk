// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';
import 'dart:fletch.io';

import 'package:expect/expect.dart';

main(arguments) {
  var forceGC = arguments.length == 1 ? arguments[0] : null;
  var channel = new Channel();
  var port = new Port(channel);
  Process.spawn(otherProcess, port);
  var replyPort = channel.receive();
  replyPort.send(forceGC);
  // Put references to the port into the message queue.
  var port2 = new Port(channel);
  for (int i = 0; i < 3; i++) {
    replyPort.send(port2);
  }
  // Get rid of all local references to the port.
  port2 = null;
  if (forceGC != null) forceGC();
  for (int i = 0; i < 3; i++) {
    Expect.equals(i, channel.receive());
  }
}

otherProcess(Port replyPort) {
  var channel = new Channel();
  replyPort.send(new Port(channel));
  // Give the main process a bit of time to get rid of all its references to
  // the port that is now in the queue so that the only references left to
  // the port are in the queue.
  sleep(10);
  var forceGC = channel.receive();
  for (int i = 0; i < 3; i++) {
    var port = channel.receive();
    port.send(i);
    port.close();
  }
  if (forceGC != null) forceGC();
}
