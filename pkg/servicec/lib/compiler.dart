// Copyright (c) 2015, the Dartino project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.compiler;

import 'dart:async' show
    Future;

import 'dart:io';

import 'package:compiler/src/tokens/token.dart' show
    Token;

import 'error_handling_listener.dart' show
    ErrorHandlingListener;

import 'errors.dart' show
    CompilationError,
    ErrorReporter,
    UndefinedServiceError,
    InternalCompilerError;

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

import 'converter.dart' show
    convert;

import 'package:old_servicec/compiler.dart' as old_servicec;
import 'package:old_servicec/src/parser.dart' show
    Unit;

// Temporary output type
Future<Iterable<CompilationError>> compile(
    String path,
    String resourcesDirectory,
    String outputDirectory,
    {Target target: Target.ALL}) async {
  String input = new File(path).readAsStringSync();
  return compileInput(input,
                      path,
                      resourcesDirectory,
                      outputDirectory,
                      target: target);
}

// Temporary output type
Future<Iterable<CompilationError>> compileInput(
    String input,
    String path,
    String resourcesDirectory,
    String outputDirectory,
    {Target target: Target.ALL}) async {
  if (input.isEmpty) {
    return [new UndefinedServiceError()];
  }

  Scanner scanner = new Scanner(input);
  Token tokens = scanner.tokenize();

  ErrorHandlingListener listener = new ErrorHandlingListener();
  Parser parser = new Parser(listener);
  parser.parseUnit(tokens);

  Iterable<CompilationError> errors = validate(listener.parsedUnitNode);

  if (errors.isEmpty) {
    Unit unit = convert(listener.parsedUnitNode);
    try {
      old_servicec.compile(path, unit, resourcesDirectory, outputDirectory);
    } catch (e, stackTrace) {
      String message = "Original error:\n$e\n$stackTrace";
      throw new InternalCompilerError(message);
    }
  }

  return errors;
}

Future<bool> compileAndReportErrors(
    String path,
    String relativePath,
    String resourcesDirectory,
    String outputDirectory,
    {Target target: Target.ALL}) async {
  String input = new File(path).readAsStringSync();
  Iterable<CompilationError> errors = await compileInput(
      input, path, resourcesDirectory, outputDirectory, target: target);
  if (errors.isNotEmpty) {
    new ErrorReporter(path, relativePath).report(errors);
    return false;
  }
  return true;
}
