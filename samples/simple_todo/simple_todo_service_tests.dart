// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import '../../tests/service_tests/service_tests.dart' show
    BuildSnapshotRule,
    CcRule,
    CompileServiceRule,
    CopyRule,
    MakeDirectoryRule,
    RunSnapshotRule,
    ServiceTest,
    isMacOS,
    javaHome,
    JarRule,
    JavaRule,
    JavacRule;

const String baseName = 'simple_todo';
const String thisDirectory = 'samples/simple_todo';

abstract class TodoServiceTest extends ServiceTest {
  TodoServiceTest(String type)
      : super('${baseName}_${type}');

  String get idlPath => '$thisDirectory/simple_todo.idl';
  String get servicePath => '$outputDirectory/simple_todo.dart';
  String get snapshotPath => '$outputDirectory/simple_todo.snapshot';
  String get executablePath => '$outputDirectory/simple_todo_sample';
  String get generatedDirectory => '$outputDirectory/generated';

  List<String> get ccSources => <String>[
    '$thisDirectory/simple_todo_main.cc',
    '$generatedDirectory/cc/struct.cc',
    '$generatedDirectory/cc/unicode.cc',
    '$generatedDirectory/cc/simple_todo.cc',
  ];

  prepareService() {
    rules.add(new MakeDirectoryRule(generatedDirectory));
    rules.add(new CompileServiceRule(idlPath, generatedDirectory));
  }

  prepareSnapshot() {
    rules.add(new CopyRule(thisDirectory, outputDirectory, [
      'simple_todo.dart',
      'simple_todo_impl.dart',
      'todo_model.dart',
    ]));
    rules.add(new BuildSnapshotRule(servicePath, snapshotPath));
  }
}

class TodoServiceTestCc extends TodoServiceTest {
  TodoServiceTestCc()
      : super('cc');

  Future<Null> prepare() async {
    prepareService();
    prepareSnapshot();
    rules.add(new CcRule(
        executable: executablePath,
        includePaths: [outputDirectory],
        sources: ccSources));
    rules.add(new RunSnapshotRule(executablePath, snapshotPath));
  }
}

class TodoServiceTestJava extends TodoServiceTest {
  TodoServiceTestJava()
      : super('java');

  String get javaDirectory => '$generatedDirectory/java';
  String get classesDirectory => '$generatedDirectory/classes';
  String get jarFile => '$outputDirectory/$baseName.jar';
  String get mainClass => 'SimpleTodo';

  List<String> get javaSources => <String>[
    '$thisDirectory/java/SimpleTodo.java',
    '$thisDirectory/java/SnapshotRunner.java',
    '$thisDirectory/java/TodoController.java',
    '$thisDirectory/java/TodoView.java',
  ];

  Future<Null> prepare() async {
    prepareService();
    prepareSnapshot();

    if (javaHome.isEmpty) return;

    rules.add(new CcRule(
        sharedLibrary: '$outputDirectory/libfletch',
        includePaths: [
          'include',
          '$javaHome/include',
          '$javaHome/include/${isMacOS ? "darwin" : "linux"}',
          outputDirectory,
        ],
        sources: [
          '$javaDirectory/jni/fletch_api_wrapper.cc',
          '$javaDirectory/jni/fletch_service_api_wrapper.cc',
          '$javaDirectory/jni/${baseName}_wrapper.cc',
        ]..addAll(ccSources)));

    rules.add(new MakeDirectoryRule(classesDirectory));

    rules.add(new JavacRule(
        warningAsError: false,
        sources: ['$javaDirectory/fletch']..addAll(javaSources),
        outputDirectory: classesDirectory));

    rules.add(new JarRule(
        jarFile,
        sources: ['.'],
        baseDirectory: classesDirectory));

    rules.add(new JavaRule(
        mainClass,
        arguments: [snapshotPath],
        classpath: [jarFile],
        libraryPath: outputDirectory));
  }
}

final List<ServiceTest> serviceTests = <ServiceTest>[
  new TodoServiceTestCc(),
  new TodoServiceTestJava(),
];
