// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'echo_service.dart';

// TODO(ager): Compiler doesn't like implements here.
class EchoImpl extends EchoService {
  int Echo(int i) {
    print("Dart: echo called with argument $i");
    return i;
  }
}

main() {
  var impl = new EchoImpl();
  EchoService.initialize(impl);
  while (EchoService.hasNextEvent()) {
    EchoService.handleNextEvent();
  }
}
