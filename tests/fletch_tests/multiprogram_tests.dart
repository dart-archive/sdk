// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import 'dart:io' show
    Directory,
    Process,
    ProcessResult;

import 'package:expect/expect.dart' show
    Expect;

import '../fletchc/run.dart' show
    export;

import 'utils.dart' show
    withTempDirectory;

const String buildDirectory =
    const String.fromEnvironment('test.dart.build-dir');

final String multiprogramRunner = '$buildDirectory/multiprogram_cc_test';

typedef Future NoArgFuture();

Future<Map<String, NoArgFuture>> listTests() async {
  var tests = <String, NoArgFuture>{
    'multiprogram_tests/should_fail':
        () => runTest('sequence', {'compiletime_error': 0}),
    'multiprogram_tests/parallel':
        () => runTest('parallel', {
            'process_links': 0,
            'compiletime_error': 254,
            'runtime_error': 255,
            'unhandled_signal': 255,
        }),
    'multiprogram_tests/sequence':
        () => runTest('sequence', {
            'process_links': 0,
            'compiletime_error': 254,
            'runtime_error': 255,
            'unhandled_signal': 255,
        }),
  };

  // Dummy use of [main] to make analyzer happy.
  main;

  return tests;
}

Future runTest(String mode, Map<String, int> testNamesWithExitCodes) {
  return withTempDirectory((Directory temp) async {
    List<List<String>> snapshotsExitcodeTuples = <List<String>>[];

    // Generate snapshots.
    for (var testName in testNamesWithExitCodes.keys) {
      int exitcode = testNamesWithExitCodes[testName];
      String snapshotFilename = '${temp.absolute.path}/$testName.snapshot';
      snapshotsExitcodeTuples.add([snapshotFilename, '$exitcode']);
      await export(testFilename(testName), snapshotFilename);
    }

    var arguments = []
        ..add(mode)
        ..addAll(snapshotsExitcodeTuples.expand((tuple) => tuple));

    // Run all the snapshots inside one fletch vm.
    ProcessResult result = await Process.run(multiprogramRunner, arguments);
    print("$multiprogramRunner result:");
    print("<STDOUT>:\n${result.stdout}\n");
    print("<STDERR>:\n${result.stderr}\n");
    print("<EXITCODE>:\n${result.exitCode}\n");

    // Validate the result.
    Expect.equals(0, result.exitCode);
  });
}

String testFilename(String name, [String generated = ''])
    => '${testDirectory(generated)}/${name}.dart';

String testDirectory([String generated = ''])
    => 'tests/multiprogram_tests$generated';

main() async {
  var tests = await listTests();
  for (var name in tests.keys) {
    print('Running test "$name".');
    await tests[name]();
  }
}
