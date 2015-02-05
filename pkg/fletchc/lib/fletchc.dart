// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:io';

const String BUILD_DIR = const String.fromEnvironment("build-dir");

const List<int> HELLO_WORLD = const <int>[
    4, 0, 0, 0, 7, 1, 0, 0, 0, 4, 0, 0, 0, 7, 0, 0, 0, 0, 4, 0, 0, 0, 7, 2, 0,
    0, 0, 0, 0, 0, 0, 13, 0, 0, 0, 0, 13, 0, 0, 0, 0, 13, 43, 0, 0, 0, 20, 1,
    0, 0, 0, 3, 0, 0, 0, 31, 0, 0, 0, 9, 0, 0, 0, 0, 23, 1, 0, 0, 0, 45, 18,
    23, 2, 0, 0, 0, 45, 14, 46, 1, 1, 71, 22, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0,
    10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 25, 0, 0, 0, 20, 1, 0, 0, 0, 0, 0,
    0, 0, 13, 0, 0, 0, 26, 1, 0, 61, 71, 4, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0,
    10, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 25, 0, 0, 0, 20, 1, 0, 0, 0, 0, 0,
    0, 0, 13, 0, 0, 0, 26, 1, 1, 61, 71, 4, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0,
    10, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 30, 0, 0, 0, 0, 0, 0,
    0, 0, 13, 12, 0, 0, 0, 10, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0,
    14, 1, 12, 0, 0, 0, 10, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 14,
    0, 12, 0, 0, 0, 10, 2, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 16, 0, 0, 0, 17,
    12, 0, 0, 0, 72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 12, 0,
    0, 0, 10, 2, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0, 9, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0, 9, 2, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0,
    4, 0, 0, 0, 29, 0, 0, 0, 0, 12, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 12, 0, 0, 0, 9, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 29,
    1, 0, 0, 0, 12, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0,
    0, 9, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 29, 2, 0, 0, 0, 4, 0,
    0, 0, 31, 4, 0, 0, 0, 8, 0, 0, 0, 15, 0, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0,
    9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 2,
];

main(args) async {
  if (args.length != 0) {
    print('usage: fletchc.dart');
    exit(1);
  }

  var scriptUri = Platform.script;
  var buildDir;
  if (BUILD_DIR == null) {
    // Locate the vm executable relative to this script's uri.
    buildDir = scriptUri.resolve("../../../out/DebugIA32Clang").toFilePath();
  } else {
    buildDir = Uri.base.resolve(BUILD_DIR).toFilePath();
  }
  var vm = "$buildDir/fletch";

  var testFile = '<dummy.dart>';
  var server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);
  var portArgument = '--port=${server.port}';
  var bridgeArgument = "-Xbridge-connection";
  var connectionIterator = new StreamIterator(server);

  var vmProcess = await Process.start(vm, [portArgument, bridgeArgument]);
  vmProcess.stdout.listen(stdout.add);
  vmProcess.stderr.listen(stderr.add);

  bool hasValue = await connectionIterator.moveNext();
  assert(hasValue);
  var vmSocket = connectionIterator.current;
  server.close();
  vmSocket.add(HELLO_WORLD);
}
