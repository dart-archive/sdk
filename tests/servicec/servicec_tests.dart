// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import 'dart:io' show
    File,
    Directory;

import 'dart:math' show
    min;

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
                [CompilerError.badFunctionDeclaration,
                 CompilerError.badMemberDeclaration]),
    new Failure('mistyped_keyword',
                [CompilerError.badTopLevelDeclaration]),
    new Success('painter_service'),
    new Failure('unfinished_struct',
                [CompilerError.badStructDefinition]),
    new Failure('unmatched_curly',
                [CompilerError.badServiceDefinition,
                 CompilerError.badMemberDeclaration]),
    new Failure('unmatched_curly_2',
                [CompilerError.badServiceDefinition,
                 CompilerError.badMemberDeclaration]),
    new Failure('unmatched_curly_3',
                [CompilerError.badFunctionDeclaration,
                 CompilerError.badServiceDefinition,
                 CompilerError.badMemberDeclaration]),
    new Failure('unmatched_curly_4',
                [CompilerError.badFunctionDeclaration,
                 CompilerError.badServiceDefinition,
                 CompilerError.badMemberDeclaration]),
    new Failure('unmatched_curly_5',
                [CompilerError.badFunctionDeclaration,
                 CompilerError.badServiceDefinition,
                 CompilerError.badMemberDeclaration]),
    new Failure('unmatched_curly_6',
                [CompilerError.badFunctionDeclaration,
                 CompilerError.badServiceDefinition,
                 CompilerError.badMemberDeclaration]),
    new Failure('unmatched_curly_7',
                [CompilerError.badFunctionDeclaration,
                 CompilerError.badServiceDefinition,
                 CompilerError.badMemberDeclaration]),
    new Failure('unmatched_curly_8',
                [CompilerError.badFunctionDeclaration,
                 CompilerError.badServiceDefinition,
                 CompilerError.badMemberDeclaration]),
    new Failure('unmatched_parenthesis',
                [CompilerError.badFunctionDeclaration]),
    new Failure('unresolved_type',
                [CompilerError.unresolvedType,
                 CompilerError.unresolvedType,
                 CompilerError.unresolvedType])
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
      Iterable<CompilerError> compilerErrors =
        await servicec.compileInput(input,
                                    name,
                                    outputDirectory,
                                    target: target);

      Expect.equals(0, compilerErrors.length, "Expected no errors");
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
      (await servicec.compileInput(input, name, outputDirectory)).toList();

    int length = min(errors.length, compilerErrors.length);
    for (int i = 0; i < length; ++i) {
      Expect.equals(errors[i], compilerErrors[i]);
    }
    Expect.equals(errors.length, compilerErrors.length,
                  "Expected a different amount of errors");
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
