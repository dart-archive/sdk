// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc;

import 'dart:async';

import 'dart:io';

import 'compiler.dart' show
    FletchCompiler;

main(List<String> arguments) async {
  List<String> options = const bool.fromEnvironment("fletchc-verbose")
      ? <String>['--verbose'] : <String>[];
  FletchCompiler compiler =
      new FletchCompiler(options: options, script: arguments.single);
  List commands = await compiler.run().catchError((e, trace) {
    // TODO(ahe): Remove this catchError block when this bug is fixed:
    // https://code.google.com/p/dart/issues/detail?id=22437.
    print(e);
    print(trace);
    exit(1);
  });

  var server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);
  var portArgument = '--port=${server.port}';
  var connectionIterator = new StreamIterator(server);

  var vmProcess = await Process.start(
      compiler.fletchVm.toFilePath(), [portArgument]);

  vmProcess.stdout.listen(stdout.add);
  vmProcess.stderr.listen(stderr.add);

  bool hasValue = await connectionIterator.moveNext();
  assert(hasValue);
  var vmSocket = connectionIterator.current;
  server.close();

  vmSocket.listen(null);
  commands.forEach((command) => command.addTo(vmSocket));
  vmSocket.close();

  exitCode = await vmProcess.exitCode;
}
