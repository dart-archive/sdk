// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:dartino';

import 'package:isolate/process_runner.dart';
import 'package:expect/expect.dart';

main() {
  test(10, 0);
  test(10, 1);
  test(10, 9);
  test(10, 10);
}

test(int total, int failures) {
  var list = [];
  var exception;
  try {
    withProcessRunner((ProcessRunner runner) {
      for (int i = 0; i < total; i++) {
        bool fail = i < failures;
        var process = runner.run(() {
          if (fail) throw 'failing';
        });
        list.add(process);
      }
    });
  } catch (e) {
    exception = e;
  }

  // Ensure all processes are in fact done (then monitoring will fail).
  var port = new Port(new Channel());
  for (int i = 0; i < total; i++) {
    Expect.isFalse(list[i].monitor(port));
  }

  // Ensure we got an exception if there were any failures.
  if (failures == 0) {
    Expect.isNull(exception);
  } else {
    Expect.equals(
        'Exception: $failures out of $total processes did not terminate '
        'normally.', exception.toString());
  }
}
