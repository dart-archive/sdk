// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:fletch';
import "dart:math" show pow;

import "package:expect/expect.dart";

class Tuple {
  final first;
  final second;
  const Tuple(this.first, this.second);
  Tuple.nonConst(this.first, this.second);
}

class Mutable {
  var value;
  Mutable(this.value);
}

void mutableToImmutableObjects(bool useConstConstructor) {
  const int kNumber = 42;

  var mutable = new Mutable(14);
  var survivorContainer;
  if (useConstConstructor) {
    survivorContainer = new Tuple(mutable, 'number: $kNumber');
  } else {
    survivorContainer = new Tuple.nonConst(mutable, 'number: $kNumber');
  }

  Expect.isFalse(isImmutable(mutable));
  Expect.isFalse(isImmutable(survivorContainer));
  Expect.isTrue(isImmutable(survivorContainer.second));

  var abc = "abc";
  for (int i = 0; i < 500000; i++) {
    abc = '$abc$abc'.substring(0, 3);
    Expect.equals(abc, 'abc');
  }

  // [survivorContainer] was added to storebuffer and we therefore do not
  // collect [survivorContainer.second] as garbage.
  Expect.equals(survivorContainer.second, 'number: 42');
}

void immutableGarbage() {
  var abc = "abc";
  var survivor = '$abc$abc';
  for (int i = 0; i < 500000; i++) {
    abc = '$abc$abc'.substring(0, 3);
    Expect.equals(abc, 'abc');
  }
  // [survivor] was moved by GC and we should still be able to
  // access it.
  Expect.equals(survivor, 'abcabc');
}

void mutableGarbage() {
  var abc = "abc";
  var survivor = new Mutable('$abc$abc');
  for (int i = 0; i < 500000; i++) {
    Expect.equals(new Mutable(abc).value, 'abc');
  }
  // [survivor] was moved by GC and we should still be able to
  // access it.
  Expect.equals(survivor.value, 'abcabc');
}

void closuresGarbage() {
  var survivor = (i) => 'survivor $i';
  for (int i = 0; i < 500000; i++) {
    void closure(i) {
      return i + 1;
    }
    Expect.equals(closure(10), 11);
  }
  // [survivor] was moved by GC and we should still be able to
  // call the closure.
  Expect.equals(survivor(10), 'survivor 10');
}

void boxedObjectGarbage() {
  var survivorBox = 10;
  for (int i = 0; i < 500000; i++) {
    var box = 11;
    void closure() {
      survivorBox = i;
      box += survivorBox + i;
    };
    closure();
    Expect.equals(box, 11 + i + i);
  }
  // [survivorBox] was moved by GC and we should still be able to
  // access it.
  Expect.equals(survivorBox, 499999);
}

void arrayStores() {
  final kConst = 42;

  var survivorContainer = ['a', 'b'];

  // Put a survivor value into the array.
  survivorContainer[0] = '$kConst';

  for (int i = 0; i < 500000; i++) {
    survivorContainer[1] = '$i';
    Expect.equals(survivorContainer[1], '$i');
  }
  // [survivorContainer[0]] was moved by GC and we should still be able to
  // access it.
  Expect.equals(survivorContainer[0], '42');
}

var staticSurvivor;
void staticStores() {
  staticSurvivor = '${100}';
  for (int i = 0; i < 500000; i++) {
    Expect.equals('${i - i + 1}', '1');
    Expect.equals(new Mutable(10).value, 10);
  }
  Expect.equals(staticSurvivor, '100');
}

void main() {
  mutableToImmutableObjects(true);
  mutableToImmutableObjects(false);
  immutableGarbage();
  mutableGarbage();
  closuresGarbage();
  boxedObjectGarbage();
  arrayStores();
  staticStores();
}

