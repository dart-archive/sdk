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
    FileSystemException,
    File;

import 'package:expect/expect.dart' show
    Expect;

import 'package:fletchc/src/verbs/infrastructure.dart' show
    fileUri;

import 'package:fletchc/src/driver/session_manager.dart';

import 'package:fletchc/src/driver/developer.dart';

const String testLocation = 'tests/debugger';
const String generatedTestLocation = 'tests/debugger_generated';

typedef Future NoArgFuture();

Future runTest(String name, Uri uri, bool writeGoldenFiles) async {
  print("$name: $uri");
  Settings settings = new Settings(
      fileUri(".packages", Uri.base),
      <String>[],
      <String, String>{},
      null,
      null,
      IncrementalMode.none);

  SessionState state = createSessionState("test", settings);
  SessionState.internalCurrent = state;

  Expect.equals(0, await compile(Uri.base.resolveUri(uri), state, Uri.base),
      "compile");

  await startAndAttachDirectly(state, Uri.base);
  state.session.hideRawIds = true;
  state.session.colorsDisabled = true;

  List<int> output = <int>[];

  state.stdoutSink.attachCommandSender(output.addAll);
  state.stderrSink.attachCommandSender(output.addAll);

  List<String> debuggerCommands = <String>[];
  for (String line in await new File.fromUri(uri).readAsLines()) {
    const String commandsPattern = "// FletchDebuggerCommands=";
    if (line.startsWith(commandsPattern)) {
      debuggerCommands = line.substring(commandsPattern.length).split(",");
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
  if (!writeGoldenFiles) {
    Uri expectationsUri = uri.resolve(expectationsFile);
    String expectations =
        await new File.fromUri(expectationsUri).readAsString();

    Expect.stringEquals(
        expectations, UTF8.decode(output),
        "$uri doesn't match expected output $expectationsUri");
  } else {
    Directory generatedDirectory = new Directory(generatedTestLocation);
    if (!(await generatedDirectory.exists())) {
      try {
        await generatedDirectory.create();
      } on FileSystemException catch (_) {
        // Ignored, we assume the directory was created by another process.
        // Possibly assert that.
      }
    }

    Uri sourceTestUri = uri.resolve('$name.dart');

    Uri baseUri = generatedDirectory.uri;
    Uri destinationTestUri = baseUri.resolve('$name.dart');
    Uri destinationExpectationUri = baseUri.resolve(expectationsFile);

    await new File.fromUri(sourceTestUri).copy(destinationTestUri.path);
    await new File.fromUri(destinationExpectationUri).writeAsBytes(output);
  }
}

/// If [writeGoldenFiles] is
///    * `true` the test closures will generate new golden files.
///    * `false` the test closures will run tests and assert the result.
Future<Map<String, NoArgFuture>> listTestsInternal(
    bool writeGoldenFiles) async {
  Map<String, NoArgFuture> result = <String, NoArgFuture>{};
  Stream<FileSystemEntity> files =
      new Directory(testLocation).list(recursive: true, followLinks: false);
  await for (FileSystemEntity entity in files) {
    if (entity is File) {
      String name = entity.uri.path.substring(testLocation.length + 1);
      if (name.endsWith("_test.dart")) {
        name = name.substring(0, name.length - ".dart".length);
        result["debugger/$name"] =
            () => runTest(name, entity.uri, writeGoldenFiles);
      }
    }
  }
  return result;
}

Future<Map<String, NoArgFuture>> listTests() async {
  if (false) main([]); // Mark main as used for dart2js.
  return listTestsInternal(false);
}

main(List<String> args) async {
  args = args.map((a) => 'debugger/$a');
  Map<String, NoArgFuture> tests = await listTestsInternal(true);
  for (String name in tests.keys) {
    if (args.isEmpty || args.contains(name)) await tests[name]();
  }
}
