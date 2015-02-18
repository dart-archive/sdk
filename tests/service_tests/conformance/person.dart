// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart/person_counter.dart';

// TODO(ager): Compiler doesn't like implements here.
class PersonCounterImpl extends PersonCounter {
  int getAge(Person person) {
    return person.age;
  }

  int getBoxedAge(PersonBox box) {
    return box.person.age;
  }

  int _sumAges(Person person) {
    int sum = getAge(person);
    List<Person> children = person.children;
    for (int i = 0; i < children.length; i++) {
      sum += _sumAges(children[i]);
    }
    return sum;
  }

  void getAgeStats(Person person, AgeStatsBuilder result) {
    int sum = _sumAges(person);
    int count = count(person);
    result.averageAge = (sum / count).round();
    result.sum = sum;
  }

  void createAgeStats(int avg, int sum, AgeStatsBuilder result) {
    result.averageAge = avg;
    result.sum = sum;
  }

  void createPerson(int numChildren, PersonBuilder result) {
    result.age = 42;
    List<PersonBuilder> children = result.initChildren(numChildren);
    for (int i = 0; i < children.length; ++i) {
      children[i].age = 12 + (i * 2);
    }
    List<int> name = result.initName(1);
    name[0] = 11;
  }

  void createNode(int depth, NodeBuilder result) {
    if (depth > 1) {
      ConsBuilder cons = result.initCons();
      createNode(depth - 1, cons.initFst());
      createNode(depth - 1, cons.initSnd());
    } else {
      result.cond = true;
      result.num = 42;
    }
  }

  int count(Person person) {
    int sum = 1;
    List<Person> children = person.children;
    for (int i = 0; i < children.length; i++) sum += count(children[i]);
    return sum;
  }

  int depth(Node node) {
    if (node.isNum) {
      if (node.isCond) throw new StateError("Cannot be both num and cond.");
      return 1;
    }
    int left = depth(node.cons.fst);
    int right = depth(node.cons.snd);
    return (left > right) ? left + 1 : right + 1;
  }

  void foo() {
    print('Foo!');
  }

  int ping() => 42;
}

main() {
  var impl = new PersonCounterImpl();
  PersonCounter.initialize(impl);
  while (PersonCounter.hasNextEvent()) {
    PersonCounter.handleNextEvent();
  }
}
