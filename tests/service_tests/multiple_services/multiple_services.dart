// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import "dart:fletch";

import 'package:expect/expect.dart';
import 'package:isolate/isolate.dart';

import "service_one_impl.dart" as one;
import "service_two_impl.dart" as two;

main() {
  var isolateOne = Isolate.spawn(one.main);
  var isolateTwo = Isolate.spawn(two.main);
  isolateOne.join();
  isolateTwo.join();
}
