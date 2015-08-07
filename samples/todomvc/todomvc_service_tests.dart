// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../tests/service_tests/service_tests.dart' show
  ServiceTest,
  buildDirectory;

const String thisDirectory = 'samples/todomvc';

class TodoMVCServiceTest extends ServiceTest {
  final String name = 'todomvc';
  String get servicePath => '$thisDirectory/todomvc.dart';
  String get snapshotPath => '$outputDirectory/todomvc.snapshot';
  String get executablePath => '$buildDirectory/todomvc_sample';
}

final ServiceTest serviceTest = new TodoMVCServiceTest();
