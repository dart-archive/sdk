// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:io';

import 'session.dart';

addCompilerOutput(stream) {
  return (d) {
    stream.write("compiler: ");
    stream.add(d);
  };
}

main(args) {
  if (SIMPLE_SYSTEM) {
    if (args.length != 0) {
      print('usage: fletch.dart');
      print("Don't pass a <file> when running the simple system.");
      exit(1);
    }
  } else if (args.length != 1) {
    print('usage: fletch.dart <file>');
    exit(1);
  }

  // Locate the compiler and vm executables relative to this script's uri.
  var scriptUri = Platform.script;
  var os = Platform.operatingSystem;
  var buildDir = scriptUri.resolve("../../build/${os}_debug_x86").toFilePath();
  var compiler = "$buildDir/fletchc";
  var vm = "$buildDir/fletch";

  var testFile = SIMPLE_SYSTEM ? '<dummy.dart>' : args[0];
  ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0).then((server) {
    var portArgument = '--port=${server.port}';
    var bridgeArgument = "-Xbridge-connection";
    var connectionIterator = new StreamIterator(server);
    var compilerArgs = [testFile, portArgument, bridgeArgument];
    if (SIMPLE_SYSTEM) compilerArgs.add("-Xsimple-system");
    Process.start(compiler, compilerArgs)
      .then((compilerProcess) {
        compilerProcess.stdout.listen(addCompilerOutput(stdout));
        compilerProcess.stderr.listen(addCompilerOutput(stderr));
        connectionIterator.moveNext().then((bool hasValue) {
          assert(hasValue);
          var compilerSocket = connectionIterator.current;
          Process.start(vm, [portArgument, bridgeArgument]).then((vmProcess) {
            vmProcess.stdout.listen(stdout.add);
            vmProcess.stderr.listen(stderr.add);
            connectionIterator.moveNext().then((bool hasValue) {
              assert(hasValue);
              var vmSocket = connectionIterator.current;
              server.close();
              print('\nStarting session. Ctrl-D to end session.\n');
              var session = new Session(compilerSocket, vmSocket);
              // TODO(ager): dart:io be zhe borken! No way to terminate
              // stdin nicely?
              stdin.listen((_) { exit(1); }, onDone: () => session.end());
            });
          });
        });
      });
  });
}
