// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart/echo_service.dart';

class EchoImpl implements EchoService {
  int echo(int n) {
    print("Dart: echo called with argument $n");
    return n;
  }

  int sum(int x, int y) {
    print("Dart: sum called with $x and $y");
    return x + y;
  }
}

main() {
  var impl = new EchoImpl();
  EchoService.initialize(impl);
  while (EchoService.hasNextEvent()) {
    EchoService.handleNextEvent();
  }
}
