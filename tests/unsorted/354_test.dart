// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

class Goo {
  static bar(a) {
    return a is String;
  }
}

class Zoo {
  bar(a) {
    return a is String;
  }
}

function bar(a) {
  return a is! String;
}

int main() {
  var gBar_tearOff = Goo.bar.call;
  Expect.isFalse(gBar_tearOff.call(1));
  var zBar_tearOff =  new Zoo().bar.call;
  Expect.isFalse(zBar_tearOff.call(1));
  var bar_tearOff = bar.call;
  Expect.isTrue(bar_tearOff.call(1));
}
