// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import '../../tests/service_tests/service_tests.dart' show
    ServiceTest,
    CcRule,
    BuildSnapshotRule,
    RunSnapshotRule;

const String thisDirectory = 'samples/todomvc';

class TodoMVCServiceTest extends ServiceTest {
  TodoMVCServiceTest()
      : super('todomvc');

  String get servicePath => '$thisDirectory/todomvc.dart';
  String get snapshotPath => '$outputDirectory/todomvc.snapshot';
  String get executablePath => '$outputDirectory/todomvc_sample';

  Future<Null> prepare() async {
    rules.add(new CcRule(
        executable: executablePath,
        sources: [
          '${thisDirectory}/todomvc.cc',
          '${thisDirectory}/todomvc_shared.cc',
          '${thisDirectory}/cc/struct.cc',
          '${thisDirectory}/cc/unicode.cc',
          '${thisDirectory}/cc/todomvc_presenter.cc',
          '${thisDirectory}/cc/todomvc_service.cc']));
    rules.add(new BuildSnapshotRule(servicePath, snapshotPath));
    rules.add(new RunSnapshotRule(executablePath, snapshotPath));
  }
}

final ServiceTest serviceTest = new TodoMVCServiceTest();
