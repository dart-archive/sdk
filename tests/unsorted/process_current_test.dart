// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

main() {
  var channel = new Channel();
  var port = new Port(channel);

  var process = Process.spawnDetached(() {
    port.send(Process.current);
    port.send(Process.current);
  });

  var processCurrent1 = channel.receive();
  var processCurrent2 = channel.receive();

  Expect.equals(process, processCurrent1);
  Expect.equals(process, processCurrent2);
}
