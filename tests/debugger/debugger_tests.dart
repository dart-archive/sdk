// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Modify this file to include more tests.
library fletch_tests.debugger;

import 'dart:async' show
    Stream,
    Future;

import 'dart:convert' show
    UTF8;

import 'dart:io' show
    Directory,
    FileSystemEntity,
    File;

import 'package:expect/expect.dart' show
    Expect;

import 'package:fletchc/src/verbs/infrastructure.dart' show
    fileUri;

import 'package:fletchc/src/driver/session_manager.dart';

import 'package:fletchc/src/driver/developer.dart';

const String testLocation = 'tests/debugger';

typedef Future NoArgFuture();

Future runTest(String name, Uri uri) async {
  print("$name: $uri");
  Settings settings = new Settings(
      fileUri(".packages", Uri.base),
      <String>[],
      <String, String>{},
      null);

  SessionState state = createSessionState("test", settings);

  Expect.equals(0, await compile(Uri.base.resolveUri(uri), state), "compile");

  await startAndAttachDirectly(state);

  List<int> output = <int>[];

  state.stdoutSink.attachCommandSender(output.addAll);
  state.stderrSink.attachCommandSender(output.addAll);

  String debuggerCommands = "";
  for (String line in await new File.fromUri(uri).readAsLines()) {
    const String commandsPattern = "// FletchDebuggerCommands=";
    if (line.startsWith(commandsPattern)) {
      debuggerCommands = line.substring(commandsPattern.length);
    }
  }

  Expect.equals(0, await run(state, testDebuggerCommands: debuggerCommands));

  int exitCode = await state.fletchVm.exitCode;

  state.stdoutSink.detachCommandSender();
  state.stderrSink.detachCommandSender();

  if (exitCode != 0) {
    output.addAll(
        UTF8.encode("Non-zero exit code from 'fletch-vm' ($exitCode).\n"));
  }

  String expectationsFile =
      name.substring(0, name.length - "_test".length) + "_expected.txt";
  Uri expectationsUri = uri.resolve(expectationsFile);
  String expectations = await new File.fromUri(expectationsUri).readAsString();

  Expect.stringEquals(
      expectations, UTF8.decode(output),
      "$uri doesn't match expected output $expectationsUri");
}

Future<Map<String, NoArgFuture>> listTests() async {
  Map<String, NoArgFuture> result = <String, NoArgFuture>{};
  Stream<FileSystemEntity> files =
      new Directory(testLocation).list(recursive: true, followLinks: false);
  await for (FileSystemEntity entity in files) {
    if (entity is File) {
      String name = entity.uri.path.substring(testLocation.length + 1);
      if (name.endsWith("_test.dart")) {
        name = name.substring(0, name.length - ".dart".length);
        result["debugger/$name"] = () => runTest(name, entity.uri);
      }
    }
  }
  if (false) main(); // Mark main as used for dart2js.
  return result;
}

main() async {
  Map<String, NoArgFuture> tests = await listTests();
  for (String name in tests.keys) {
    await tests[name]();
  }
}
