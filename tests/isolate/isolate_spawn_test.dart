// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';

isolateFunction() {
  return 5;
}

void main() {
  Isolate isolate = Isolate.spawn(isolateFunction);
  Expect.equals(5, isolate.wait());
}
