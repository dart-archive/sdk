// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'session.dart';

const String BUILD_DIR = const String.fromEnvironment("build-dir");

const String BANNER = """
Starting session.

Commands:
  'r'    run main
  'd'    mark the process for debugging
  's'    step on bytecode in the process
  'c'    continue a stepping execution running to program completion
  'bt'   backtrace
  'quit' quit the session
""";

Session session;
String previousLine = '';

addCompilerOutput(stream) {
  return (d) {
    stream.write("compiler: ");
    stream.add(d);
  };
}

printPrompt() => stdout.write('> ');

onInput(String line) {
  if (line.isEmpty) line = previousLine;
  previousLine = line;
  switch (line) {
    case "quit":
      exit(0);
      break;
    case "r":
      session.run();
      break;
    case "d":
      session.debug();
      break;
    case "s":
      session.step();
      break;
    case "c":
      session.cont();
      break;
    case "bt":
      session.backtrace();
      break;
  }
  printPrompt();
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

  var scriptUri = Platform.script;
  var buildDir;
  if (BUILD_DIR == null) {
    // Locate the compiler and vm executables relative to this script's uri.
    buildDir = scriptUri.resolve("../../out/DebugIA32Clang").toFilePath();
  } else {
    buildDir = Uri.base.resolve(BUILD_DIR).toFilePath();
  }
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
              print(BANNER);
              session = new Session(compilerSocket, vmSocket);
              printPrompt();
              stdin.transform(new Utf8Decoder())
                   .transform(new LineSplitter())
                   .listen(onInput, onDone: () => session.end());
            });
          });
        });
      });
  });
}
