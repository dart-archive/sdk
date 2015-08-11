// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import 'package:expect/expect.dart';
import 'package:servicec/compiler.dart' as servicec;
import 'package:servicec/errors.dart' as errors;

List<InputTest> SERVICEC_TESTS = <InputTest>[
    new Failure<errors.UndefinedServiceError>('empty_input', '''
'''),
    new Success('empty_service', '''
service EmptyService {}
'''),
];

abstract class InputTest {
  final String name;

  InputTest(this.name);

  Future perform();
}

class Success extends InputTest {
  final String input;

  Success(name, this.input)
      : super(name);

  Future perform() async {
    servicec.compileInput(input, name);
  }
}

class Failure<T> extends InputTest {
  final String input;
  final exception;

  Failure(name, this.input)
      : super(name);

  Future perform() async {
    Expect.throws(() => servicec.compileInput(input, name), (e) => e is T);
  }
}

// Test entry point.

typedef Future NoArgFuture();

Future<Map<String, NoArgFuture>> listTests() async {
  var tests = <String, NoArgFuture>{};
  for (InputTest test in SERVICEC_TESTS) {
    tests['servicec/${test.name}'] = test.perform;
  }
  return tests;
}
