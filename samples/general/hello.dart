// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.
//
// Simple Hello program. Prints Hello, and an indication of which environment
// it was run in.
library helloSample;
import 'package:os/os.dart';

main() {
  SystemInformation si = sys.systemInformation();
  print('Hello from ${si.operatingSystemName} running on ${si.nodeName}.');
}
