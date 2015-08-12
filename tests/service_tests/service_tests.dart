// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show
    Directory,
    Process,
    ProcessResult;

import 'dart:async' show
    Future;

import 'package:expect/expect.dart' show
    Expect;

import '../../samples/todomvc/todomvc_service_tests.dart' as todomvc;

List<ServiceTest> SERVICE_TESTS = <ServiceTest>[
    new StandardServiceTest('conformance', ccSources: [
        'conformance_test.cc',
        'conformance_test_shared.cc',
        'cc/conformance_service.cc',
        'cc/struct.cc',
        'cc/unicode.cc',
    ]),
    new StandardServiceTest('performance', ccSources: [
        'performance_test.cc',
        'cc/performance_service.cc',
        'cc/struct.cc',
        'cc/unicode.cc',
    ]),
    todomvc.serviceTest,
];

const String thisDirectory = 'tests/service_tests';

/// Absolute path to the build directory used by test.py.
const String buildDirectory =
    const String.fromEnvironment('test.dart.build-dir');

/// Build architecture provided to test.py
const String buildArchitecture =
    const String.fromEnvironment('test.dart.build-arch');

/// Compiler configuration from test.py
const String buildCxxCompiler =
    const String.fromEnvironment('test.dart.build-cxx-compiler');

/// Host system configuration from test.py
const String buildSystem =
    const String.fromEnvironment('test.dart.build-system');

// TODO(zerny): Provide the below constants via configuration from test.py
final String generatedDirectory = '$buildDirectory/generated_service_tests';
final String fletchExecutable = '$buildDirectory/fletch';
final String fletchLibrary = '${buildDirectory}/libfletch.a';

abstract class ServiceTest {
  final String name;
  List<Rule> rules = [];
  String get outputDirectory => '$generatedDirectory/$name';

  ServiceTest(this.name);

  // Prepare the test prior to run.
  Future<Null> prepare();

  Future<Directory> ensureDirectory(String path) {
    return new Directory(path).create(recursive: true);
  }

  Future<Null> run() async {
    await ensureDirectory(outputDirectory);
    await prepare();
    for (Rule rule in rules) {
      await rule.build();
    }
  }
}

class StandardServiceTest extends ServiceTest {
  Iterable<String> ccSources;

  StandardServiceTest(name, {this.ccSources})
      : super(name);

  String get inputDirectory => '$thisDirectory/$name';

  String get servicePath => '${inputDirectory}/${name}_service_impl.dart';
  String get snapshotPath => '${outputDirectory}/${name}.snapshot';
  String get executablePath => '${outputDirectory}/service_${name}_test';

  Future<Null> prepare() async {
    rules.add(new CcRule(
        executable: executablePath,
        sources: ccSources.map((path) => '${inputDirectory}/${path}')));
    rules.add(new BuildSnapshotRule(servicePath, snapshotPath));
    rules.add(new RunSnapshotRule(executablePath, snapshotPath));
  }
}

abstract class Rule {

  Future<Null> build();

  static Future<ProcessResult> runCommand(String executable,
                                          List<String> arguments) async {
    print("Running: '$executable' $arguments");
    ProcessResult result = await Process.run(executable, arguments);
    print('stdout:');
    print(result.stdout);
    print('stderr:');
    print(result.stderr);
    Expect.equals(0, result.exitCode);
    return result;
  }
}

// TODO(zerny): Consider refactoring fletch specifics into a derived class.
// TODO(zerny): Find a way to obtain the fletch build configuration from gyp.
class CcRule extends Rule {
  final String language;
  final String executable;
  final Iterable<String> flags;
  final Iterable<String> sources;
  final Iterable<String> libraries;
  final Iterable<String> includePaths;
  final Iterable<String> libraryPaths;

  CcRule({
    this.executable,
    this.language: 'c++11',
    this.flags: const <String>[],
    this.sources: const <String>[],
    this.libraries: const <String>[],
    this.includePaths: const <String>[],
    this.libraryPaths: const <String>[]
  }) {
    if (executable == null) {
      throw "CcRule expects a valid output path for the executable";
    }
  }

  bool get isClang => buildCxxCompiler == 'clang';
  bool get isGNU => buildCxxCompiler == 'g++';
  bool get isMacOS => buildSystem == 'macos';
  bool get isLinux => buildSystem == 'linux';
  bool get isWindows => buildSystem == 'windows';

  String get compiler => 'tools/cxx_wrapper.py';

  void addBuildFlags(List<String> arguments) {
    arguments.add('-std=${language}');
    if (buildArchitecture == 'ia32') {
      if (isGNU) arguments.add('-m32');
      if (isClang) arguments..add('-arch')..add('i386');
      arguments.add('-DFLETCH32');
      arguments.add('-DFLETCH_TARGET_IA32');
    } else if (buildArchitecture == 'X64') {
      if (isGNU) arguments.add('-m64');
      if (isClang) arguments..add('-arch')..add('x86_64');
      arguments.add('-DFLETCH64');
      arguments.add('-DFLETCH_TARGET_X64');
    } else {
      throw "Unsupported architecture ${buildArchitecture}";
    }
  }

  void addHostFlags(List<String> arguments) {
    if (isMacOS) {
      arguments.add('-DFLETCH_TARGET_OS_MACOS');
      arguments.add('-DFLETCH_TARGET_OS_POSIX');
      arguments..add('-framework')..add('CoreFoundation');
    } else if (isLinux) {
      arguments.add('-DFLETCH_TARGET_OS_LINUX');
      arguments.add('-DFLETCH_TARGET_OS_POSIX');
    } else {
      throw "Unsupported host ${buildSystem}";
    }
  }

  void addUserFlags(List<String> arguments) {
    arguments.addAll(flags);
  }

  void addIncludePaths(List<String> arguments) {
    arguments.add('-I.');
    arguments.addAll(includePaths.map((path) => '-I${path}'));
  }

  void addLibraryPaths(List<String> arguments) {
    String arch;
    if (buildArchitecture == 'ia32') {
      arch = 'x86';
    } else if (buildArchitecture == 'x64') {
      arch = 'x64';
    } else {
      throw "Unsupported host architecture ${buildArchitecture}";
    }
    if (isMacOS) arguments.add('-Lthird_party/libs/mac/$arch');
    if (isLinux) arguments.add('-Lthird_party/libs/linux/$arch');
    arguments.addAll(libraryPaths.map((path) => '-L${path}'));
  }

  void addLibraries(List<String> arguments) {
    arguments.add(fletchLibrary);
    for (String lib in libraries) {
      arguments.add(lib.endsWith('.a') ? lib : '-l$lib');
    }
  }

  void addHostLibraries(List<String> arguments) {
    arguments.addAll([
      '-ltcmalloc_minimal',
      '-lpthread',
      '-ldl',
      '-rdynamic',
    ]);
  }

  void addSources(List<String> arguments) {
    arguments.addAll(sources);
  }

  Future<Null> build() async {
    List<String> arguments = <String>[];
    addBuildFlags(arguments);
    addHostFlags(arguments);
    addUserFlags(arguments);
    addIncludePaths(arguments);
    addLibraryPaths(arguments);
    arguments..add('-o')..add(executable);
    if (isGNU) arguments.add('-Wl,--start-group');
    addSources(arguments);
    addLibraries(arguments);
    if (isGNU) arguments.add('-Wl,--end-group');
    addHostLibraries(arguments);
    await Rule.runCommand(compiler, arguments);
  }
}

class BuildSnapshotRule extends Rule {
  final String program;
  final String snapshot;

  BuildSnapshotRule(this.program, this.snapshot);

  Future<Null> build() {
    return Rule.runCommand(
        fletchExecutable, ['compile-and-run', program, '-o', snapshot]);
  }
}

class RunSnapshotRule extends Rule {
  final String executable;
  final String snapshot;

  RunSnapshotRule(this.executable, this.snapshot);

  Future<Null> build() {
    return Rule.runCommand(executable, [snapshot]);
  }
}

// Test entry point.

typedef Future NoArgFuture();

Future<Map<String, NoArgFuture>> listTests() async {
  var tests = <String, NoArgFuture>{};
  for (ServiceTest test in SERVICE_TESTS) {
    tests['service_tests/${test.name}'] = () => test.run();
  }
  return tests;
}
