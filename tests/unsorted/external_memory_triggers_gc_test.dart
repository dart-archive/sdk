// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:fletch.io';

import 'package:expect/expect.dart';

// This test:
//   * makes heap budget 1MB
//   * allocates 4 GB of external memory in chunks of 1MB
// Without tracking external memory, this test will consume 4 GB of memory and
// most likely run OOM. If external memory is correctly tracked, the test will
// end up using ~ 10 MB (depends on malloc implementation).
main() {
  const int kChunkSize = 1024 * 1024;
  const int kTotalSize = 4 * 1024 * 1024 * 1024;

  // We use at least 1MB of heap size, this means the budget will grow to at
  // least 1MB of heap size.
  var keepAllocationBudgetHigh = new List(256 * 1024);

  var file = new File.open('/dev/zero');

  int size = 0;
  while (size < kTotalSize) {
    var bytes = file.read(kChunkSize).asUint8List();
    Expect.equals(bytes.length, kChunkSize);
    size += bytes.length;
  }

  file.close();
}
