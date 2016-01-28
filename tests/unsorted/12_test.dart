// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';


void main() {
  Expect.equals(0, [].length);
  Expect.equals(1, [1].length);
  Expect.equals(2, [1, "hej"].length);
}
