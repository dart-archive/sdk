// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart/conformance_service.dart';

class ConformanceServiceImpl implements ConformanceService {
  int getAge(Person person) {
    return person.age;
  }

  int getBoxedAge(PersonBox box) {
    if (box.person.name != "fisk") {
      throw new Exception("Incorrect person name");
    }
    if (box.person.nameData.length != 4 ||
        box.person.nameData[0] != "f".codeUnitAt(0) ||
        box.person.nameData[3] != "k".codeUnitAt(0)) {
      throw new Exception("Incorrect person name data");
    }
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
    result.name = "person";
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
  }

  int bar(Empty empty) {
    return 24;
  }

  int ping() => 42;
}

main() {
  var impl = new ConformanceServiceImpl();
  ConformanceService.initialize(impl);
  while (ConformanceService.hasNextEvent()) {
    ConformanceService.handleNextEvent();
  }
}
