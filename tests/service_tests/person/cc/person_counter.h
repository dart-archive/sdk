// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// Generated file. Do not edit.

#ifndef PERSON_COUNTER_H
#define PERSON_COUNTER_H

class Person;

class PersonCounter {
 public:
  static void Setup();
  static void TearDown();

  static int Count(Person* person);
  // TODO(kasperl): Add async variant.
};

class Person {
};

#endif  // PERSON_COUNTER_H
