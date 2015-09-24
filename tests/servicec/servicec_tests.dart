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
  new Failure("bad_field_1", [CompilerError.badField]),
  new Failure("bad_field_2", [CompilerError.badField]),
  new Failure("bad_field_3", [CompilerError.badField]),
  // bad_field_4 fails with more errors; TODO(stanm): fix
  new Failure("bad_field_4", [CompilerError.badField]),
  new Failure("bad_field_5", [CompilerError.badField]),
  new Failure("bad_field_6", [CompilerError.badField]),
  new Failure("bad_field_7", [CompilerError.badField]),
  // bad_field_4 fails with more errors; TODO(stanm): fix
  new Failure("bad_field_8", [CompilerError.badField]),
  new Success("good_field_1"),
  new Success("good_field_2"),
  new Success("good_field_3"),

  // bad_formal_1 fails with different errors; TODO(stanm): fix
  new Failure("bad_formal_1", [CompilerError.badFormal]),
  // bad_formal_2 fails with different errors; TODO(stanm): fix
  new Failure("bad_formal_2", [CompilerError.badFormal]),
  // bad_formal_3 fails with different errors; TODO(stanm): fix
  new Failure("bad_formal_3", [CompilerError.badFormal]),
  new Success("good_formal_1"),
  new Success("good_formal_2"),

  new Failure("bad_function_1", [CompilerError.badFunction]),
  new Failure("bad_function_2", [CompilerError.badFunction]),
  new Failure("bad_function_3", [CompilerError.badFunction]),
  // bad_function_4 fails with more errors; TODO(stanm): fix
  new Failure("bad_function_4", [CompilerError.badFunction]),
  new Failure("bad_function_5", [CompilerError.badFunction]),
  new Failure("bad_function_6", [CompilerError.badFunction]),
  // bad_function_7 fails with different errors; TODO(stanm): fix
  new Failure("bad_function_7",
              [CompilerError.badFunction,
               CompilerError.badFunction]),
  new Success("good_function"),

  new Failure("bad_list_type_1", [CompilerError.badListType]),
  // bad_list_type_2 fails; TODO(stanm): add < > recovery
  new Failure("bad_list_type_2", [CompilerError.badListType]),
  // bad_list_type_3 fails with different errors; TODO(stanm): fix
  new Failure("bad_list_type_3", [CompilerError.badListType]),
  // bad_list_type_4 fails with different errors; TODO(stanm): fix
  new Failure("bad_list_type_4", [CompilerError.badListType]),
  // bad_list_type_5 fails with different errors; TODO(stanm): fix
  new Failure("bad_list_type_5", [CompilerError.badListType]),
  new Success("good_list_type_1"),
  new Success("good_list_type_2"),
  new Success("good_list_type_3"),

  new Failure("bad_pointer_type_1", [CompilerError.badPointerType]),
  new Success("good_pointer_type_1"),

  new Failure("bad_return_type_1", [CompilerError.expectedPointerOrPrimitive]),
  new Failure("bad_return_type_2", [CompilerError.expectedPointerOrPrimitive]),
  new Failure("bad_return_type_3", [CompilerError.expectedPointerOrPrimitive]),
  new Failure("bad_return_type_4", [CompilerError.expectedPointerOrPrimitive]),
  new Success("good_return_type_1"),
  new Success("good_return_type_2"),

  new Failure("bad_service_definition_1", [CompilerError.badServiceDefinition]),
  new Success("good_service_definition_1"),

  new Failure("bad_simple_type_1", [CompilerError.badSimpleType]),
  new Success("good_simple_type_1"),
  new Success("good_simple_type_2"),

  new Failure("bad_struct_definition_1", [CompilerError.badStructDefinition]),
  new Success("good_struct_definition_1"),

  new Failure("bad_top_level_1", [CompilerError.badTopLevel]),
  new Failure("bad_top_level_2", [CompilerError.badTopLevel]),

  new Failure("bad_type_parameter_1", [CompilerError.badTypeParameter]),
  new Failure("bad_type_parameter_2", [CompilerError.badTypeParameter]),
  new Failure("bad_type_parameter_3", [CompilerError.badTypeParameter]),
  new Success("good_type_parameter_1"),
  new Success("good_type_parameter_2"),

  new Success("good_union_1"),
  new Success("good_union_2"),
  new Success("good_union_3"),

  new Failure("bad_single_formal_1",
              [CompilerError.expectedPointerOrPrimitive]),
  new Failure("bad_single_formal_2",
              [CompilerError.expectedPointerOrPrimitive]),
  new Failure("bad_single_formal_3",
              [CompilerError.expectedPointerOrPrimitive]),
  new Failure("bad_single_formal_4",
              [CompilerError.expectedPointerOrPrimitive]),
  new Success("good_single_formal_1"),

  new Failure("bad_multiple_formals_1",
              [CompilerError.expectedPrimitiveFormal]),
  new Failure("bad_multiple_formals_2",
              [CompilerError.expectedPrimitiveFormal]),
  new Failure("bad_multiple_formals_3",
              [CompilerError.expectedPrimitiveFormal]),
  new Failure("bad_multiple_formals_4",
              [CompilerError.expectedPrimitiveFormal]),
  new Failure("bad_multiple_formals_5",
              [CompilerError.expectedPrimitiveFormal]),
  new Failure("bad_multiple_formals_6",
              [CompilerError.expectedPrimitiveFormal]),
  new Failure("bad_multiple_formals_7",
              [CompilerError.expectedPrimitiveFormal]),
  new Failure("bad_multiple_formals_8",
              [CompilerError.expectedPrimitiveFormal]),
  new Success("good_multiple_formals_1"),
  new Success("good_multiple_formals_2"),
  new Success("good_multiple_formals_3"),

  new Failure("multiple_definitions_1", [CompilerError.multipleDefinitions]),
  new Failure("multiple_definitions_2", [CompilerError.multipleDefinitions]),
  // multiple_definitions_3 fails; TODO(stanm): no redefinitions of structs
  new Failure("multiple_definitions_3", [CompilerError.multipleDefinitions]),
  new Failure("multiple_definitions_4", [CompilerError.multipleDefinitions]),
  new Failure("multiple_definitions_5", [CompilerError.multipleDefinitions]),
  new Failure("multiple_definitions_6", [CompilerError.multipleDefinitions]),
  new Failure("multiple_definitions_7", [CompilerError.multipleDefinitions]),
  new Failure("multiple_definitions_8", [CompilerError.multipleDefinitions]),
  new Success("no_multiple_definitions_1"),
  new Success("no_multiple_definitions_2"),
  new Success("no_multiple_definitions_3"),
  new Success("no_multiple_definitions_4"),
  new Success("no_multiple_definitions_5"),
  new Success("no_multiple_definitions_6"),
  new Success("no_multiple_definitions_7"),

  new Failure("multiple_union_1", [CompilerError.multipleUnions]),
  new Success("no_multiple_union_1"),

  new Failure("undefined_service_1", [CompilerError.undefinedService]),
  new Failure("undefined_service_2", [CompilerError.undefinedService]),
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
