// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';
import '../../src/tools/driver/properties.dart' as properies;
import '../../src/tools/driver/property_managers.dart' as managers;


main() {
  testGlobalProperties();
}

testGlobalProperties() {
  properies.global = new properies.Properties("/");
  properies.global.manager = new managers.MemoryBasedPropertyManager();

  Expect.isNull(properies.global.serverPortNumber);

  int value = 2000;
  properies.global.serverPortNumber = value;
  Expect.equals(value, properies.global.serverPortNumber);
}
