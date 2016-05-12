// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

/// Modify this file to include more tests.
library dartino_tests.debugger;

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

import 'package:dartino_compiler/src/verbs/infrastructure.dart' show
    fileUri;

import 'package:dartino_compiler/src/hub/session_manager.dart';

import 'package:dartino_compiler/src/worker/developer.dart';

import '../cli_tests/cli_tests.dart' show
    dartinoVmBinary;

const String testLocation = 'tests/debugger';
const String generatedTestLocation = 'tests/debugger_generated';

typedef Future NoArgFuture();

/// Temporary directory for test output.
///
/// Snapshots will be put here.
const String tempTestOutputDirectory =
    const String.fromEnvironment("test.dart.temp-dir");

Future runTest(String name, Uri uri,
    {bool writeGoldenFiles, bool runFromSnapshot: false}) async {
  print("$name: $uri");
  Settings settings = new Settings(
      fileUri(".packages", Uri.base),
      <String>[],
      <String, String>{},
      <String>[],
      null,
      null,
      null,
      IncrementalMode.none);

  SessionState state = createSessionState("test", Uri.base, settings);
  SessionState.internalCurrent = state;

  Expect.equals(0, await compile(Uri.base.resolveUri(uri), state, Uri.base),
      "compile");

  DartinoVm vm;
  Uri snapshotPath;

  if (runFromSnapshot) {
    Uri snapshotDir =
        Uri.base.resolve("$tempTestOutputDirectory/cli_tests/${name}/");

    new Directory(snapshotDir.toFilePath()).create(recursive: true);
    snapshotPath = snapshotDir.resolve("out.snapshot");

    await startAndAttachDirectly(state, Uri.base);
    // Build a snapshot.
    int exportResult = await export(state, snapshotPath);

    Expect.equals(0, exportResult);

    // Start an interactive vm from a snapshot.
    vm = await DartinoVm.start(
        dartinoVmBinary.toFilePath(),
        arguments: ['--interactive', snapshotPath.toFilePath()]);

    // Attach to that VM
    await attachToVmTcp("localhost", vm.port, state);
  } else {
    await startAndAttachDirectly(state, Uri.base);
  }
  state.vmContext.hideRawIds = true;
  state.vmContext.colorsDisabled = true;

  List<int> output = <int>[];

  state.stdoutSink.attachCommandSender(output.addAll);
  state.stderrSink.attachCommandSender(output.addAll);

  List<String> debuggerCommands = <String>[];
  for (String line in await new File.fromUri(uri).readAsLines()) {
    const String commandsPattern = "// DartinoDebuggerCommands=";
    if (line.startsWith(commandsPattern)) {
      debuggerCommands.addAll(
          line.substring(commandsPattern.length).split(","));
    }
  }

  testDebugCommandStream(DartinoVmContext session) async* {
    yield 't verbose';
    yield 'b main';
    yield 'r';
    while (!session.terminated) {
      yield 's';
    }
  };

  int result = await state.vmContext.debug(
      debuggerCommands.isEmpty
        ? testDebugCommandStream
        : (DartinoVmContext _) => new Stream.fromIterable(debuggerCommands),
      Uri.base,
      state,
      state.stdoutSink,
      echo: true,
      snapshotLocation: snapshotPath);

  int exitCode = runFromSnapshot
      ? await vm.exitCode
      : await state.dartinoVm.exitCode;

  Expect.equals(exitCode, result);

  state.stdoutSink.detachCommandSender();
  state.stderrSink.detachCommandSender();

  if (exitCode != 0) {
    output.addAll(
        UTF8.encode("Non-zero exit code from 'dartino-vm' ($exitCode).\n"));
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
            () => runTest(
                name,
                entity.uri,
                writeGoldenFiles: writeGoldenFiles,
                runFromSnapshot: false);
        result["debugger_snapshot/$name"] =
            () => runTest(
                name,
                entity.uri,
                writeGoldenFiles: writeGoldenFiles,
                runFromSnapshot: true);
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
  args = args.map((a) => 'debugger/$a').toList();
  Map<String, NoArgFuture> tests = await listTestsInternal(true);
  for (String name in tests.keys) {
    if (args.isEmpty || args.contains(name)) await tests[name]();
  }
}
