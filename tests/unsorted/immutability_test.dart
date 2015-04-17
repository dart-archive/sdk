// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class Fisk {
  int age;
  Fisk(this.age);
}

class Hest {
  final int age;
  Hest(this.age);
}

class Hund {
  final int age;
  const Hund(this.age);
}

main() {
  /// Check for mutable objects
  Expect.isFalse(isImmutable(new Fisk(1)));
  Expect.isFalse(isImmutable(new Hest(1)));

  /// Check for immutable objects
  Expect.isTrue(isImmutable(null));
  Expect.isTrue(isImmutable(''));
  Expect.isTrue(isImmutable('hello world'));
  Expect.isTrue(isImmutable(1));
  Expect.isTrue(isImmutable(1.1));
  Expect.isTrue(isImmutable(true));
  Expect.isTrue(isImmutable(false));

  // TODO: Not working yet.
  Expect.isFalse(isImmutable(new Hund(1)));
  Expect.isFalse(isImmutable(bool));
  Expect.isFalse(isImmutable(String));
  Expect.isFalse(isImmutable(Hest));
  Expect.isFalse(isImmutable(main));

  // TODO: This causes an "class = class  - @0 = Overflow to big integer"
  // error for some reason.
  // Expect.isTrue(isImmutable(1 << 420));
}

