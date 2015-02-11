// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:io';

import 'hello_world_commands.dart' as hello_world show commands;

const String BUILD_DIR = const String.fromEnvironment("build-dir");

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
  hello_world.commands.forEach((command) => command.addTo(vmSocket));
}
