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

import '../dartino_compiler/run.dart' show
    export;

import 'utils.dart' show
    withTempDirectory;

const String buildDirectory =
    const String.fromEnvironment('test.dart.build-dir');

final String multiprogramRunner = '$buildDirectory/multiprogram_cc_test';

typedef Future NoArgFuture();

List duplicateList(List a, int n) {
  var result = new List(n * a.length);
  for (int i = 0; i < n; i++) {
    result.setRange(i * a.length, (i + 1) * a.length, a);
  }
  return result;
}

Future<Map<String, NoArgFuture>> listTests() async {
  var tests = <String, NoArgFuture>{
    'multiprogram_tests/should_fail':
        () => runTest('sequence', ['compiletime_error', 0]),

    'multiprogram_tests/parallel':
        () => runTest('parallel', [
            'process_links', 0,
            'compiletime_error', 254,
            'runtime_error', 255,
            'unhandled_signal', 255,
        ]),

    'multiprogram_tests/sequence':
        () => runTest('sequence', [
            'process_links', 0,
            'compiletime_error', 254,
            'runtime_error', 255,
            'unhandled_signal', 255,
        ]),

    'multiprogram_tests/many_programs':
        () => runTest('batch=50', [
            'process_links', 0,
            'compiletime_error', 254,
            'runtime_error', 255,
            'unhandled_signal', 255,
        ], duplicate: 200),

    'multiprogram_tests/immutable_gc':
        () => runTest('overlapped=11', [
            'immutable_gc', 0,
            'process_links', 0,
            'compiletime_error', 254,
            'runtime_error', 255,
            'unhandled_signal', 255,
        ], duplicate: 3),

    'multiprogram_tests/mutable_gc':
        () => runTest('overlapped=11', [
            'mutable_gc', 0,
            'process_links', 0,
            'compiletime_error', 254,
            'runtime_error', 255,
            'unhandled_signal', 255,
        ], duplicate: 3),

    'multiprogram_tests/stress_test':
        () => runTest('overlapped=3', [
            'mutable_gc', 0,
            'compute', 0,
            'immutable_gc', 0,
        ], duplicate: 2),

    'multiprogram_tests/mutable_gc_and_freeze':
        () => runTest('batch=6', [
            'mutable_gc', 0,
            'process_links', 0,
            'runtime_error', 255,
            'unhandled_signal', 255,
        ], duplicate: 3, freeze: true),

    'multiprogram_tests/stress_test_and_freeze':
        () => runTest('batch=6', [
            'mutable_gc', 0,
            'compute', 0,
            'immutable_gc', 0,
        ], duplicate: 2, freeze: true),
  };

  // Dummy use of [main] to make analyzer happy.
  main;

  return tests;
}

Future runTest(String mode, List testNamesWithExitCodes,
               {int duplicate, bool freeze: false}) {
  return withTempDirectory((Directory temp) async {
    List<String> snapshotsExitcodeTuples = <String>[];

    // Generate snapshots.
    for (int i = 0; i < testNamesWithExitCodes.length ~/2; i++) {
      String testName = testNamesWithExitCodes[2 * i];
      int exitcode = testNamesWithExitCodes[2 * i + 1];
      String snapshotFilename = '${temp.absolute.path}/$testName.snapshot';
      snapshotsExitcodeTuples.addAll([snapshotFilename, '$exitcode']);
      print('Making snapshot $snapshotFilename');
      await export(testFilename(testName), snapshotFilename);
      print('Making snapshot $snapshotFilename - done');
    }

    if (duplicate != null) {
      snapshotsExitcodeTuples = duplicateList(
          snapshotsExitcodeTuples, duplicate);
    }

    var arguments = [];
    if (freeze) arguments.add('--freeze-odd');
    arguments.add(mode);
    arguments.addAll(snapshotsExitcodeTuples);

    // Run all the snapshots inside one dartino vm.
    print("Running $multiprogramRunner ${arguments.join(' ')}");
    ProcessResult result = await Process.run(multiprogramRunner, arguments);
    print("Done running $multiprogramRunner ${arguments.join(' ')}:");
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
