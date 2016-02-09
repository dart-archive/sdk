// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:gpio/gpio.dart';

main() {
  var pin = new SysfsPin(1);
  var gpio = new SysfsGpio();
}
