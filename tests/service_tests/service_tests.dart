// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show
    Directory,
    Platform,
    Process,
    ProcessResult;

import 'dart:async' show
    Future;

import 'package:expect/expect.dart' show
    Expect;

const SERVICE_TESTS = const <String>[
    'conformance',
    'performance',
];

/// Absolute path to the build directory.
const String buildDirectory =
    const String.fromEnvironment('test.dart.build-dir');

const String thisDirectory = 'tests/service_tests';

final String generatedDirectory = '$buildDirectory/generated_service_tests';

final String fletchExecutable = '$buildDirectory/fletch';

class ServiceTest {
  final String name;
  ServiceTest(this.name);

  String get serviceFile => '${name}_service_impl.dart';
  String get snapshotFile => '$name.snapshot';
  String get executableFile => 'service_${name}_test';

  String get inputDirectory => '$thisDirectory/$name';
  String get outputDirectory => '$generatedDirectory/$name';

  String get servicePath => '$inputDirectory/$serviceFile';
  String get snapshotPath => '$outputDirectory/$snapshotFile';
  String get executablePath => '$buildDirectory/$executableFile';
}

Future<ProcessResult> buildSnapshot(ServiceTest test) {
  return run(fletchExecutable, [
      'compile-and-run', test.servicePath,
      '-o', test.snapshotPath]);
}

Future<ProcessResult> runSnapshot(ServiceTest test) {
  return run(test.executablePath, [test.snapshotPath]);
}

Future<ProcessResult> run(String executable, List<String> arguments) async {
  print("Running: '$executable' $arguments");
  ProcessResult result = await Process.run(executable, arguments);
  print('stdout:');
  print(result.stdout);
  print('stderr:');
  print(result.stderr);
  Expect.equals(0, result.exitCode);
  return result;
}

Future<Directory> ensureDirectory(String path) {
  return new Directory(path).create(recursive: true);
}

Future<Null> performTest(ServiceTest test) async {
  await ensureDirectory(test.outputDirectory);
  await buildSnapshot(test);
  await runSnapshot(test);
}

// Test entry point.

typedef Future NoArgFuture();

Future<Map<String, NoArgFuture>> listTests() async {
  var tests = <String, NoArgFuture>{};
  for (var test in SERVICE_TESTS) {
    tests['service_tests/$test'] = () => performTest(new ServiceTest(test));
  }
  return tests;
}
