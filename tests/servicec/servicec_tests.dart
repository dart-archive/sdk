// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import 'dart:io' show
    File,
    Directory;

import 'package:expect/expect.dart';
import 'package:servicec/compiler.dart' as servicec;
import 'package:servicec/errors.dart' show
    CompilerError;

import 'package:servicec/targets.dart' show
    Target;

import 'scanner_tests.dart' show
    SCANNER_TESTS;

import 'test.dart' show
    Test;

List<InputTest> SERVICEC_TESTS = <InputTest>[
    new Failure('empty_input', [CompilerError.undefinedService]),
    new Success('empty_service'),
    new Failure('missing_semicolon',
                [CompilerError.syntax, CompilerError.syntax]),
    new Failure('mistyped_keyword', [CompilerError.syntax]),
    new Failure('unfinished_struct', [CompilerError.syntax]),
    new Failure('unmatched_curly',
                [CompilerError.syntax, CompilerError.syntax])
];

/// Absolute path to the build directory used by test.py.
const String buildDirectory =
    const String.fromEnvironment('test.dart.build-dir');

/// Relative path to the directory containing input files.
const String filesDirectory = "tests/servicec/input_files";

// TODO(zerny): Provide the below constant via configuration from test.py
final String generatedDirectory = '$buildDirectory/generated_servicec_tests';

abstract class InputTest extends Test {
  String _input;
  String get input {
    if (_input == null) {
      _input = new File("$filesDirectory/$name.idl").readAsStringSync();
    }
    return _input;
  }

  final String outputDirectory;

  InputTest(String name)
      : outputDirectory = "$generatedDirectory/$name",
        super(name);
}

class Success extends InputTest {
  final Target target;

  Success(String name, {this.target: Target.ALL})
      : super(name);

  Future perform() async {
    try {
      await servicec.compileInput(input, name, outputDirectory, target: target);
      await checkOutputDirectoryStructure(outputDirectory, target);
    } finally {
      nukeDirectory(outputDirectory);
    }
  }
}

class Failure extends InputTest {
  final List<CompilerError> errors;

  Failure(String name, this.errors)
      : super(name);

  Future perform() async {
    List<CompilerError> compilerErrors =
      await servicec.compileInput(input, name, outputDirectory);

    for (int i = 0; i < compilerErrors.length; ++i) {
      Expect.equals(errors[i], compilerErrors[i]);
    }
  }
}

// Helpers for Success.

Future checkOutputDirectoryStructure(String outputDirectory, Target target)
    async {
  // If the root out dir does not exist there is no point in checking the
  // children dirs.
  await checkDirectoryExists(outputDirectory);

  if (target.includes(Target.JAVA)) {
    await checkDirectoryExists(outputDirectory + '/java');
  }
  if (target.includes(Target.CC)) {
    await checkDirectoryExists(outputDirectory + '/cc');
  }
}

Future checkDirectoryExists(String dirName) async {
  var dir = new Directory(dirName);
  Expect.isTrue(await dir.exists(), "Directory $dirName does not exist");
}

// TODO(stanm): Move cleanup logic to fletch_tests setup
Future nukeDirectory(String dirName) async {
  var dir = new Directory(dirName);
  await dir.delete(recursive: true);
}

// Test entry point.

typedef Future NoArgFuture();

Future<Map<String, NoArgFuture>> listTests() async {
  var tests = <String, NoArgFuture>{};
  for (Test test in SERVICEC_TESTS) {
    tests['servicec/${test.name}'] = test.perform;
  }

  for (Test test in SCANNER_TESTS) {
    tests['servicec/scanner/${test.name}'] = test.perform;
  }
  return tests;
}
