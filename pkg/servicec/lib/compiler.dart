// Copyright (c) 2015, the Fletch project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library servicec.compiler;

import 'dart:async' show
    Future;

import 'dart:io';

import 'errors.dart';

import 'targets.dart' show
    Target;

Future compile(
    String path,
    String outputDirectory,
    {Target target: Target.ALL}) async {
  String input = new File(path).readAsStringSync();
  await compileInput(input, path, outputDirectory, target: target);
}

Future compileInput(
    String input,
    String path,
    String outputDirectory,
    {Target target: Target.ALL}) async {
  if (input.isEmpty) {
    throw new UndefinedServiceError(path);
  }
  // TODO(stanm): parse input

  // TODO(stanm): validate

  // TODO(stanm): generate output

  createDirectories(outputDirectory, target);

  // TODO(stanm): write files
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
