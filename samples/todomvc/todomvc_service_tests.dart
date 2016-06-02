// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import '../../tests/service_tests/service_tests.dart' show
    CompileServiceRule,
    ServiceTest,
    CcRule,
    CopyRule,
    BuildSnapshotRule,
    RunSnapshotRule;

const String thisDirectory = 'samples/todomvc';

class TodoMVCServiceTest extends ServiceTest {
  TodoMVCServiceTest()
      : super('todomvc');

  String get idlPath => '$thisDirectory/todomvc_service.idl';
  String get servicePath => '$outputDirectory/todomvc.dart';
  String get snapshotPath => '$outputDirectory/todomvc.snapshot';
  String get executablePath => '$outputDirectory/todomvc_sample';

  Future<Null> prepare() async {
    rules.add(new CompileServiceRule(idlPath, outputDirectory));
    rules.add(new CopyRule(thisDirectory, outputDirectory, [
      'model.dart',
      'todomvc.dart',
      'todomvc_impl.dart',
      'dart/presentation_graph.dart',
      'dart/todomvc_presenter.dart',
      'dart/todomvc_presenter_model.dart',
    ]));
    rules.add(new CcRule(
        executable: executablePath,
        includePaths: [outputDirectory, '$outputDirectory/cc'],
        sources: [
          '$thisDirectory/todomvc.cc',
          '$thisDirectory/todomvc_shared.cc',
          '$thisDirectory/cc/todomvc_presenter.cc',
          '$outputDirectory/cc/struct.cc',
          '$outputDirectory/cc/unicode.cc',
          '$outputDirectory/cc/todomvc_service.cc']));
    rules.add(new BuildSnapshotRule(servicePath, snapshotPath));
    rules.add(new RunSnapshotRule(executablePath, snapshotPath));
  }
}

final ServiceTest serviceTest = new TodoMVCServiceTest();
