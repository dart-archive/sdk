// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc;

import 'dart:async';

import 'dart:io';

import 'compiler.dart' show
    FletchCompiler;

main(List<String> arguments) async {
  FletchCompiler compiler = new FletchCompiler(
      // options: ['--verbose'],
      script: arguments.single);
  List commands = await compiler.run();

  var server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);
  var portArgument = '--port=${server.port}';
  var bridgeArgument = "-Xbridge-connection";
  var connectionIterator = new StreamIterator(server);

  var vmProcess = await Process.start(
      compiler.fletchVm.toFilePath(), [portArgument, bridgeArgument]);
  vmProcess.stdout.listen(stdout.add);
  vmProcess.stderr.listen(stderr.add);

  bool hasValue = await connectionIterator.moveNext();
  assert(hasValue);
  var vmSocket = connectionIterator.current;
  server.close();
  commands.forEach((command) => command.addTo(vmSocket));
}
