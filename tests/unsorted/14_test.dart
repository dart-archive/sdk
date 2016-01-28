// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class Fna {
  var z = 2;

  call(y) {
    return () => 6 + y + z + this.z;
  }
}

foo(f) => f(3)();

void main() {
  var i = 1;
  var i1 = 1;
  var i2 = 1;
  var j = 2;
  (() {
   var q = j;
   Expect.equals(2, q);
  })();

  var x = 5;
  foo((y) {
    var z = 2;
    return () {
      x = 4 + y + z;
    };
  });
  Expect.equals(9, x);
  Expect.equals(13, foo(new Fna()));
}
