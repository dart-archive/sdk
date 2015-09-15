// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import "dart:fletch";
import "service_one_impl.dart" as one;
import "service_two_impl.dart" as two;

main() {
  Process.spawn(one.main);
  Process.spawn(two.main);
}
