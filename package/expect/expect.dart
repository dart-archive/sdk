// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

_identical(a, b) => identical(a, b);

class Expect {
  static void identical(expected, value) {
    if (!_identical(value, expected)) {
      throw "Expected '$expected' to be identical to '$value'";
    }
  }

  static void equals(expected, value) {
    if (value != expected) {
      throw "Expected '$expected' but got '$value'";
    }
  }

  static void notEquals(expected, value) {
    if (value == expected) {
      throw "Expected to not get '$expected'";
    }
  }

  static void isTrue(value) {
    equals(true, value);
  }

  static void isFalse(value) {
    equals(false, value);
  }

  static void isNull(value) {
    equals(null, value);
  }

  static void isNotNull(value) {
    notEquals(null, value);
  }

  static void listEquals(expected, list) {
    equals(expected.length, list.length);
    for (int i = 0; i < expected.length; i++) {
      equals(expected[i], list[i]);
    }
  }

  static void fail(msg) {
    throw msg;
  }

  static void throws(func(), [bool test(error)]) {
    try {
      func();
    } catch (error) {
      if (test != null && test(error) != true) {
        throw "Unexpected error in throws: '$error'";
      }
      return;
    }
    throw "Expected throw";
  }
}
