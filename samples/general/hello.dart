// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// Simple Hello program. Prints Hello, and an indication of which environment
// it was run in.
library helloSample;
import 'package:os/os.dart';

main() {
  SystemInformation si = sys.info();
  String nodeInformation =
      si.nodeName.isEmpty ? '' : ' running on ${si.nodeName}';
  print('Hello from ${si.operatingSystemName}$nodeInformation.');
}
