// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';

import 'package:expect/expect.dart';
import 'package:power_management/power_management.dart';

main() {
  testDisableEnable();
}

Future testDisableEnable() async {
  await initPowerManagement();
  int id = disableSleep('Some odd reason');
  enableSleep(id);
}
