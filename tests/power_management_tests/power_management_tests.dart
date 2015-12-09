// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';

import '../../pkg/power_management/test/disable_enable_test.dart'
    as disable_enable;

typedef Future NoArgFuture();

Future<Map<String, NoArgFuture>> listTests() async {
  var tests = <String, NoArgFuture>{};
  tests['power_management_tests/disable_enable'] = disable_enable.main;
  return tests;
}
