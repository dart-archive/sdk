// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future,
    Stream,
    StreamController;

import 'dart:io' show
    Directory,
    File,
    Process,
    ProcessResult;

import 'dart:convert' show
    UTF8;

import 'package:expect/expect.dart' show
    Expect;

import '../fletchc/run.dart' show
    export;

import 'package:fletchc/program_info.dart' as program_info;

import 'utils.dart' show
    withTempDirectory;

const String buildDirectory =
    const String.fromEnvironment('test.dart.build-dir');

const String buildArch =
    const String.fromEnvironment('test.dart.build-arch');

const String buildSystem =
    const String.fromEnvironment('test.dart.build-system');

final String fletchVM = '$buildDirectory/fletch-vm';

typedef Future NoArgFuture();

Future<Map<String, NoArgFuture>> listTests(
    [bool write_golden_files = false]) async {
  var tests = <String, NoArgFuture>{
    'snapshot_stacktrace_tests/uncaught_exception':
        () => runTest('uncaught_exception', write_golden_files),
    'snapshot_stacktrace_tests/nsm_exception':
        () => runTest('nsm_exception', write_golden_files),
    'snapshot_stacktrace_tests/coroutine_exception':
        () => runTest('coroutine_exception', write_golden_files),
  };


  // Dummy use of [main] to make analyzer happy.
  main;

  return tests;
}

Future runTest(String testName, bool write_golden_files) {
  return withTempDirectory((Directory temp) async {
    String snapshotFilename = '${temp.absolute.path}/test.snapshot';

    // Part 1: Generate snapshot.
    await export(
        testFilename(testName), snapshotFilename, binaryProgramInfo: true);

    // Part 2: Run VM.
    ProcessResult result = await Process.run(fletchVM, [snapshotFilename]);
    String expectationContent =
        await new File(testExpectationFilename(testName)).readAsString();

    // Part 3: Transform stdout via stack trace decoder.
    var stdin = new Stream.fromIterable([UTF8.encode(result.stdout)]);
    var stdout = new StreamController();
    Future<List> stdoutBytes =
        stdout.stream.fold([], (buffer, data) => buffer..addAll(data));
    var arguments = [
        buildArch.toLowerCase() == 'x64' ? '64' : '32',
        buildSystem.toLowerCase() == 'lk' ? 'float' : 'double',
        '${snapshotFilename}.info.bin',
    ];
    await program_info.decodeProgramMain(arguments, stdin, stdout);

    // Part 4: Build expectation string
    String stdoutString = UTF8.decode(await stdoutBytes);
    String actualOutput =
        '<STDOUT>:\n${stdoutString}\n'
        '<STDERR>:\n${result.stderr}\n'
        '<EXITCODE>:${result.exitCode}';

    // Part 5: Compare actual/expected or write to golden files.
    if (write_golden_files) {
      // Create golden file directory (if it doesn't exist).
      var dir = new Directory(testDirectory('_generated'));
      if (!await dir.exists()) await dir.create(recursive: true);

      // Copy test file.
      var testFileContent =
          await new File(await testFilename(testName)).readAsString();
      await new File(testFilename(testName, '_generated'))
          .writeAsString(testFileContent);

      // Write actual expectation output.
      await new File(testExpectationFilename(testName, '_generated'))
          .writeAsString(actualOutput);
    } else {
      Expect.stringEquals(expectationContent, actualOutput);
    }
  });
}

String testFilename(String name, [String generated = ''])
    => '${testDirectory(generated)}/${name}_test.dart';

String testExpectationFilename(String name, [String generated = ''])
    => '${testDirectory(generated)}/${name}_expected.txt';

String testDirectory([String generated = ''])
    => 'tests/snapshot_stacktrace_tests$generated';

main() async {
  var tests = await listTests(true);
  for (var name in tests.keys) {
    await tests[name]();
  }
}
