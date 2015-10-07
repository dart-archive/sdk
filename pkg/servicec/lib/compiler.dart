// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.compiler;

import 'dart:async' show
    Future;

import 'dart:io';

import 'package:compiler/src/scanner/scannerlib.dart' show
    Token;

import 'error_handling_listener.dart' show
    ErrorHandlingListener;

import 'errors.dart' show
    CompilationError,
    UndefinedServiceError;

import 'listener.dart' show
    DebugListener,
    Listener;

import 'parser.dart' show
    Parser;

import 'scanner.dart' show
    Scanner;

import 'targets.dart' show
    Target;

import 'validator.dart' show
    validate;

// Temporary output type
Future<Iterable<CompilationError>> compile(
    String path,
    String outputDirectory,
    {Target target: Target.ALL}) async {
  String input = new File(path).readAsStringSync();
  return compileInput(input, path, outputDirectory, target: target);
}

// Temporary output type
Future<Iterable<CompilationError>> compileInput(
    String input,
    String path,
    String outputDirectory,
    {Target target: Target.ALL}) async {
  if (input.isEmpty) {
    return [new UndefinedServiceError()];
  }

  Scanner scanner = new Scanner(input);
  Token tokens = scanner.tokenize();

  ErrorHandlingListener listener = new ErrorHandlingListener();
  Parser parser = new Parser(new DebugListener(listener));
  parser.parseUnit(tokens);

  Iterable<CompilationError> errors = validate(listener.parsedUnitNode);
  if (errors.length == 0) {
    // TODO(stanm): generate output
  }

  createDirectories(outputDirectory, target);

  return errors;
}

void createDirectories(String outputDirectory, Target target) {
  new Directory(outputDirectory).createSync(recursive: true);

  if (target.includes(Target.JAVA)) {
    createJavaDirectories(outputDirectory);
  }
  if (target.includes(Target.CC)) {
    createCCDirectories(outputDirectory);
  }
}

void createJavaDirectories(String outputDirectory) {
  new Directory("$outputDirectory/java").createSync(recursive: true);
}

void createCCDirectories(String outputDirectory) {
  new Directory("$outputDirectory/cc").createSync(recursive: true);
}
