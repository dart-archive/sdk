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
  'r'                                   run main
  'b <method name> <bytecode index>'    set breakpoint
  'd <breakpoint id>'                   delete breakpoint
  'lb'                                  list breakpoints
  's'                                   step bytecode
  'so'                                  step over
  'c'                                   continue execution
  'bt'                                  backtrace
  'bt <n>'                              backtrace only expanding frame n
  'quit'                                quit the session
""";

class ConnectionHandler {
  final ServerSocket server;
  final StreamIterator iterator;

  ConnectionHandler._(this.server, this.iterator);

  static Future<ConnectionHandler> start() async {
    var server = await ServerSocket.bind(InternetAddress.LOOPBACK_IP_V4, 0);
    var iterator = new StreamIterator(server);
    return new ConnectionHandler._(server, iterator);
  }

  Future next() async {
    var hasNext = await iterator.moveNext();
    assert(hasNext);
    return iterator.current;
  }

  close()  => server.close();
  get port => server.port;
}

class InputHandler {
  final Session session;
  String previousLine = '';

  InputHandler(this.session);

  printPrompt() => stdout.write('> ');

  Future handleLine(String line) async {
    if (line.isEmpty) line = previousLine;
    previousLine = line;
    List<String> commandComponents =
        line.split(" ").where((s) => !s.isEmpty).toList();
    String command = commandComponents[0];
    switch (command) {
      case "quit":
        session.end();
        exit(0);
        break;
      case "r":
        await session.run();
        break;
      case "b":
        var method =
            (commandComponents.length > 1) ? commandComponents[1] : "main";
        var bci =
            (commandComponents.length > 2) ? commandComponents[2] : "0";
        try {
          bci = int.parse(bci);
        } catch(e) {
          print('### invalid bytecode index: $bci');
          break;
        }
        await session.setBreakpoint(method: method, bytecodeIndex: bci);
        break;
      case "d":
        var id = (commandComponents.length > 1) ? commandComponents[1] : null;
        try {
          id = int.parse(id);
        } catch(e) {
          print('### invalid breakpoint number: $id');
          break;
        }
        await session.deleteBreakpoint(id);
        break;
      case "lb":
        session.listBreakpoints();
        break;
      case "s":
        await session.step();
        break;
      case "so":
        await session.stepOver();
        break;
      case "c":
        await session.cont();
        break;
      case "bt":
        var frame =
            (commandComponents.length > 1) ? commandComponents[1] : "-1";
        try {
          frame = int.parse(frame);
        } catch(e) {
          print('### invalid frame number: $frame');
          break;
        }
        await session.backtrace(frame);
        break;
      default:
        print('### unknown command: $command');
        break;
    }
    printPrompt();
  }

  Future run() async {
    print(BANNER);
    printPrompt();
    var inputLineStream = stdin.transform(new Utf8Decoder())
                               .transform(new LineSplitter());
    await for(var line in inputLineStream) {
      await handleLine(line);
    }
  }
}

main(args) async {
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

  // Create server socket on which to listen for connection from compiler
  // and VM.
  ConnectionHandler connectionHandler = await ConnectionHandler.start();

  // Setup connection arguments to instruct compiler and VM to connect to the
  // bridge.
  var portArgument = '--port=${connectionHandler.port}';
  var bridgeArgument = "-Xbridge-connection";
  var debugArgument = "-Xdebugging";

  // Invoke compiler with the file and connection info and wait for the
  // compiler to connect to the bridge.
  var compilerArgs = [testFile, portArgument, bridgeArgument];
  if (SIMPLE_SYSTEM) compilerArgs.add("-Xsimple-system");
  var compilerProcess = await Process.start(compiler, compilerArgs);
  compilerProcess.stdout.listen(stdout.add);
  compilerProcess.stderr.listen(stderr.add);
  var compilerSocket = await connectionHandler.next();

  // Invoke VM with connection info and wait for it to connect to the bridge.
  var vmProcess = await Process.start(vm, [portArgument, debugArgument]);
  vmProcess.stdout.listen(stdout.add);
  vmProcess.stderr.listen(stderr.add);
  var vmSocket = await connectionHandler.next();

  // Stop accepting connections.
  connectionHandler.close();

  // Start the bridge session that communicates with both compiler and VM.
  var session = await Session.start(compilerSocket, vmSocket);

  // Start the command-line input handling.
  var inputHandler = new InputHandler(session);
  await inputHandler.run();
  session.end();
}
