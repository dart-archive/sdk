// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import "dart/service_two.dart";

class ServiceTwoImpl implements ServiceTwo {
  int echo(int arg) => arg * arg;
}

main() {
  var impl = new ServiceTwoImpl();
  ServiceTwo.initialize(impl);
  while (ServiceTwo.hasNextEvent()) {
    ServiceTwo.handleNextEvent();
  }
}
