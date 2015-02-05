// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart/person_counter.dart';

// TODO(ager): Compiler doesn't like implements here.
class PersonCounterImpl extends PersonCounter {
  int GetAge(Person person) {
    return person.age;
  }

  int GetBoxedAge(PersonBox box) {
    return box.person.age;
  }

  int _SumAges(Person person) {
    int sum = GetAge(person);
    List<Person> children = person.children;
    for (int i = 0; i < children.length; i++) {
      sum += _SumAges(children[i]);
    }
    return sum;
  }

  void GetAgeStats(Person person, AgeStatsBuilder result) {
    int sum = _SumAges(person);
    int count = Count(person);
    result.averageAge = (sum / count).round();
    result.sum = sum;
  }

  void CreateAgeStats(int avg, int sum, AgeStatsBuilder result) {
    result.averageAge = avg;
    result.sum = sum;
  }

  void CreatePerson(int numChildren, PersonBuilder result) {
    result.age = 42;
    List<PersonBuilder> children = result.NewChildren(numChildren);
    for (int i = 0; i < children.length; ++i) children[i].age = 12;
  }

  int Count(Person person) {
    int sum = 1;
    List<Person> children = person.children;
    for (int i = 0; i < children.length; i++) sum += Count(children[i]);
    return sum;
  }

  int Depth(Node node) {
    if (node.isNum) return 1;
    int left = Depth(node.cons.fst);
    int right = Depth(node.cons.snd);
    return (left > right) ? left + 1 : right + 1;
  }
}

main() {
  var impl = new PersonCounterImpl();
  PersonCounter.initialize(impl);
  while (PersonCounter.hasNextEvent()) {
    PersonCounter.handleNextEvent();
  }
}
