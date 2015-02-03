// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart/person_counter.dart';

// TODO(ager): Compiler doesn't like implements here.
class PersonCounterImpl extends PersonCounter {
  int GetAge(Person person) {
    return person.age;
  }

  int Count(Person person) {
    int sum = 1;
    List<Person> children = person.children;
    for (int i = 0; i < children.length; i++) sum += Count(children[i]);
    return sum;
  }
}

main() {
  var impl = new PersonCounterImpl();
  PersonCounter.initialize(impl);
  while (PersonCounter.hasNextEvent()) {
    PersonCounter.handleNextEvent();
  }
}
