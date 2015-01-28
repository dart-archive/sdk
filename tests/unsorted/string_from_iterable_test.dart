// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

Sting fromIterable(List list, int start, int end) {
  return new String.fromCharCodes(list.where((_) => true), start, end);
}

bool isRangeError(e) => e is RangeError;

main() {
  Expect.equals("abc", fromIterable([97, 98, 99], 0, 3));
  Expect.equals("bc", fromIterable([97, 98, 99], 1, 3));
  Expect.equals("c", fromIterable([97, 98, 99], 2, 3));
  Expect.equals("a", fromIterable([97, 98, 99], 0, 1));
  Expect.equals("", fromIterable([97, 98, 99], 1, 1));
  Expect.equals("b", fromIterable([97, 98, 99], 1, 2));

  Expect.throws(() => fromIterable([97, 98, 99], 1, 0), isRangeError);
  Expect.throws(() => fromIterable([97, 98, 99], 2, 4), isRangeError);
  Expect.throws(() => fromIterable([97, 98, 99], 4, 4), isRangeError);
  Expect.throws(() => fromIterable([97, 98, 99], -1, 2), isRangeError);
}
