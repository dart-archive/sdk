// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// FletchDebuggerCommands=b print,r,c,fibers,t internal,fibers,t internal,c,c,fibers,c

import 'dart:fletch';

run(marker) {
  for (int i = 0; i < 2; i++) {
    Fiber.yield();
    print('$marker ${i}');
  }
}

main() {
  Fiber.fork(() { run('a'); });
  Fiber.fork(() { run('b'); });
}
