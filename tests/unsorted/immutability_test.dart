// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch';

import 'package:expect/expect.dart';

// This class is missing: final fields and const constructor.
class Fisk {
  int age;
  Fisk(this.age);
}

// This class is missing: const constructor.
class Hest {
  final int age;
  Hest(this.age);
}

class Hund {
  final int age;
  const Hund(this.age);
}

// This class has one (const) constructor which can be used for immutable
// objects. The other constructor is non-const and cannot be used ATM.
class Node {
  final Node left;
  final Node right;
  const Node(this.left, this.right);
  Node.nonConst(this.left, this.right);
}

main() {
  var string = 'abc';
  var leaf = new Node(null, null);
  var nonConstConstructorObj = new Node.nonConst(leaf, leaf);

  /// Check for immutable objects
  testImmutable(null);
  testImmutable('');
  testImmutable('hello world');
  testImmutable(1);
  testImmutable(0xFFFFFFFFFFFFFFFF * 0xFFFF);  // Bigint
  testImmutable(1.1);
  testImmutable(true);
  testImmutable(false);
  testImmutable('$string$string');

  testImmutable(new Hund(1));
  testImmutable(leaf);
  testImmutable(new Node(leaf, leaf));
  testImmutable(new Node(new Node(leaf, leaf), leaf));

  const constLeaf = const Node(null, null);
  testImmutable(const Hund(1));
  testImmutable(const Node(constLeaf, constLeaf));
  testImmutable(const Node(const Node(constLeaf, constLeaf), constLeaf));

  testImmutable(() {});
  int x;
  testImmutable(() { x; });
  testImmutable(main);

  /// Check for mutable objects
  testMutable(new Fisk(1));
  testMutable(new Hest(1));
  testMutable(nonConstConstructorObj);
  testMutable(new Node(leaf, nonConstConstructorObj));
  testMutable(new Node(nonConstConstructorObj, leaf));
  testMutable(new Node(new Node(leaf, nonConstConstructorObj), leaf));
  int y;
  testMutable(() { y = 4; });

  // TODO(kustermann): Runtime types are not working ATM.
  // Expect.isFalse(isImmutable(bool));
  // Expect.isFalse(isImmutable(String));
  // Expect.isFalse(isImmutable(Hest));

  // TODO(kustermann/fletchc-experts): Allow self recursive closures.
  // [The recursive reference causes a storeField instruction to be
  //  emitted which makes it mutable ATM.]
  void recurse(x) { if (x > 0) { return recurse(x - 1); } }
  Expect.isFalse(isImmutable(recurse));
}

testImmutable(obj) {
  Expect.isTrue(isImmutable(obj));
}

testMutable(obj) {
  Expect.isFalse(isImmutable(obj));
}

