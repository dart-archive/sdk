// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import '../service_tests.dart' show
    BuildSnapshotRule,
    CcRule,
    CompileServiceRule,
    CopyRule,
    RunSnapshotsRule,
    ServiceTest;

const String thisDirectory = 'tests/service_tests/multiple_services';

const List<String> sharedIdlFiles = const <String>[
  'service_one.idl',
  'service_two.idl',
];

const List<String> sharedDartFiles = const <String>[
  'service_one_impl.dart',
  'service_two_impl.dart',
];

const List<String> sharedCCFiles = const <String>[
  'cc/service_one.cc',
  'cc/service_two.cc',
  'cc/struct.cc',
  'cc/unicode.cc',
];

class MultipleServicesTest extends ServiceTest {
  MultipleServicesTest()
      : super('multiple_services');

  String get mainFile => 'multiple_services.dart';
  String get mainPath => '$outputDirectory/multiple_services.dart';
  String get snapshotPath => '$outputDirectory/multiple_services.snapshot';
  String get executablePath => '$outputDirectory/multiple_services';

  Future<Null> prepare() async {
    rules.add(new CopyRule(thisDirectory, outputDirectory, [mainFile]));
    rules.add(new CopyRule(thisDirectory, outputDirectory, sharedDartFiles));

    for (String idl in sharedIdlFiles) {
      rules.add(new CompileServiceRule('$thisDirectory/$idl', outputDirectory));
    }

    rules.add(new CcRule(
        executable: executablePath,
        includePaths: [outputDirectory],
        sources: ['$thisDirectory/multiple_services_test.cc']
            ..addAll(sharedCCFiles.map((path) => '$outputDirectory/$path'))));

    rules.add(new BuildSnapshotRule(mainPath, snapshotPath));

    rules.add(new RunSnapshotsRule(executablePath, [snapshotPath]));
  }
}

class MultipleSnapshotsTest extends ServiceTest {
  MultipleSnapshotsTest()
      : super('multiple_snapshots');

  String get serviceOnePath => '$outputDirectory/service_one_impl.dart';
  String get snapshotOnePath => '$outputDirectory/service_one.snapshot';

  String get serviceTwoPath => '$outputDirectory/service_two_impl.dart';
  String get snapshotTwoPath => '$outputDirectory/service_two.snapshot';

  String get executablePath => '$outputDirectory/multiple_snapshots';

  Future<Null> prepare() async {
    rules.add(new CopyRule(thisDirectory, outputDirectory, sharedDartFiles));

    for (String idl in sharedIdlFiles) {
      rules.add(new CompileServiceRule('$thisDirectory/$idl', outputDirectory));
    }

    rules.add(new CcRule(
        executable: executablePath,
        includePaths: [outputDirectory],
        sources: ['$thisDirectory/multiple_snapshots_test.cc']
            ..addAll(sharedCCFiles.map((path) => '$outputDirectory/$path'))));

    rules.add(new BuildSnapshotRule(serviceOnePath, snapshotOnePath));
    rules.add(new BuildSnapshotRule(serviceTwoPath, snapshotTwoPath));

    rules.add(new RunSnapshotsRule(
        executablePath, [snapshotOnePath, snapshotTwoPath]));
  }
}

final List<ServiceTest> serviceTests = <ServiceTest>[
  new MultipleServicesTest(),
  new MultipleSnapshotsTest(),
];
