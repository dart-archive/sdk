// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import '../../tests/service_tests/service_tests.dart' show
    CompileServiceRule,
    ServiceTest,
    CopyRule,
    CcRule,
    BuildSnapshotRule,
    MakeDirectoryRule,
    RunSnapshotRule;

const String thisDirectory = 'samples/simple_todo';

class TodoServiceTest extends ServiceTest {
  TodoServiceTest()
      : super('simple_todo');

  String get idlPath => '$thisDirectory/simple_todo.idl';
  String get servicePath => '$outputDirectory/simple_todo.dart';
  String get snapshotPath => '$outputDirectory/simple_todo.snapshot';
  String get executablePath => '$outputDirectory/simple_todo_sample';
  String get generatedDirectory => '$outputDirectory/generated';

  Future<Null> prepare() async {
    rules.add(new CopyRule(thisDirectory, outputDirectory, [
      'simple_todo.dart',
      'simple_todo_impl.dart',
      'todo_model.dart',
    ]));
    rules.add(new MakeDirectoryRule(generatedDirectory));
    rules.add(new CompileServiceRule(idlPath, generatedDirectory));
    rules.add(new CcRule(
        executable: executablePath,
        includePaths: [generatedDirectory],
        sources: [
          '$thisDirectory/simple_todo_main.cc',
          '$generatedDirectory/cc/struct.cc',
          '$generatedDirectory/cc/unicode.cc',
          '$generatedDirectory/cc/simple_todo.cc']));
    rules.add(new BuildSnapshotRule(servicePath, snapshotPath));
    rules.add(new RunSnapshotRule(executablePath, snapshotPath));
  }
}

final ServiceTest serviceTest = new TodoServiceTest();
