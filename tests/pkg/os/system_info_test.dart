// Copyright (c) 2014, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'package:expect/expect.dart';
import 'package:os/os.dart' as os;

void main() {
  var systemInfo = os.sys.info();

  Expect.isTrue(systemInfo.operatingSystemName is String);
  Expect.isTrue(systemInfo.nodeName is String);
  Expect.isTrue(systemInfo.release is String);
  Expect.isTrue(systemInfo.version is String);
  Expect.isTrue(systemInfo.machine is String);
}
