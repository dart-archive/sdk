// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

void main() {
  Expect.isTrue(null is dynamic);
  Expect.isTrue(1 is dynamic);
  Expect.isTrue(0.0 is dynamic);
  Expect.isTrue(true is dynamic);
  Expect.isTrue(new Object() is dynamic);
}
