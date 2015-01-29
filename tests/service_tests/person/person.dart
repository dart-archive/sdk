// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart/person_counter.dart';

// TODO(ager): Compiler doesn't like implements here.
class PersonCounterImpl extends PersonCounter {
  int Count(Person person) {
    return 42;
  }
}

main() {
  var impl = new PersonCounterImpl();
  PersonCounter.initialize(impl);
  while (PersonCounter.hasNextEvent()) {
    PersonCounter.handleNextEvent();
  }
}
