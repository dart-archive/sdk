// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import '../../tests/service_tests/service_tests.dart' show
    CompileServiceRule,
    ServiceTest,
    CcRule,
    BuildSnapshotRule,
    RunSnapshotRule;

const String thisDirectory = 'samples/simple_todo';

class TodoServiceTest extends ServiceTest {
  TodoServiceTest()
      : super('simple_todo');

  String get idlPath => '$thisDirectory/simple_todo.idl';
  String get servicePath => '$thisDirectory/simple_todo.dart';
  String get snapshotPath => '$outputDirectory/simple_todo.snapshot';
  String get executablePath => '$outputDirectory/simple_todo_sample';

  Future<Null> prepare() async {
    rules.add(new CompileServiceRule(idlPath, thisDirectory));
    rules.add(new CcRule(
        executable: executablePath,
        sources: [
          '${thisDirectory}/simple_todo_main.cc',
          '${thisDirectory}/cc/struct.cc',
          '${thisDirectory}/cc/unicode.cc',
          '${thisDirectory}/cc/simple_todo.cc']));
    rules.add(new BuildSnapshotRule(servicePath, snapshotPath));
    rules.add(new RunSnapshotRule(executablePath, snapshotPath));
  }
}

final ServiceTest serviceTest = new TodoServiceTest();
