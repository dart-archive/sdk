// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// DartinoOptions=-Xgc-on-delete

import 'dart:async';
import 'dart:dartino';

import 'package:expect/expect.dart';

List constList = const [1, 2, 3];

noop() { }

main() {
  var input = new Channel();
  var port = new Port(input);
  Process.spawnDetached(() => subProcess(port));
  // Wait while messages are enqueued and a program GC is forced with
  // messages in the queue.
  new Timer(const Duration(milliseconds: 100), () {
    var replyPort = input.receive();
    Expect.equals(input.receive(), constList);
    replyPort.send(constList);
    for (int i = 0; i < 10; i++) {
      Expect.equals(i, input.receive());
    }
  });
}

subProcess(Port replyPort) {
  var input = new Channel();
  var port = new Port(input);
  Process.spawnDetached(noop);
  // Put two messages in the queue.
  replyPort.send(port);
  replyPort.send(constList);
  // Spin up a process that will die immediately to force a program GC.
  Process.spawnDetached(noop);
  Expect.equals(input.receive(), constList);
  for (int i = 0; i < 10; i++) {
    Process.spawnDetached(noop);
    replyPort.send(i);
  }
}
