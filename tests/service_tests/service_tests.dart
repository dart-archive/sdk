// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async' show
    Future;

import 'dart:convert' show
    LineSplitter,
    UTF8;

import 'dart:io' show
    Directory,
    File,
    FileSystemEntity,
    Platform,
    Process,
    ProcessResult;

import 'package:expect/expect.dart' show
    Expect;

import 'multiple_services/multiple_services_tests.dart' as multiple;
import '../../samples/todomvc/todomvc_service_tests.dart' as todomvc;
import '../../samples/simple_todo/simple_todo_service_tests.dart'
    as simple_todo;

import '../dartino_compiler/run.dart' show
    export;

import 'package:servicec/compiler.dart' as servicec;

List<ServiceTest> SERVICE_TESTS = <ServiceTest>[]
    ..add(todomvc.serviceTest)
    ..addAll(simple_todo.serviceTests)
    ..addAll(multiple.serviceTests)
    ..addAll(buildStandardServiceTests(
        'conformance',
        ccSources: [
          'conformance_test.cc',
          'conformance_test_shared.cc',
        ],
        javaSources: [
          'java/ConformanceTest.java',
          'java/DebugRunner.java',
          'java/SnapshotRunner.java',
        ],
        javaMainClass: 'ConformanceTest'))
    ..addAll(buildStandardServiceTests(
        'performance',
        ccSources: [
          'performance_test.cc',
        ],
        javaSources: [
          'java/PerformanceTest.java',
          'java/SnapshotRunner.java',
        ],
        javaMainClass: 'PerformanceTest'));

const String thisDirectory = 'tests/service_tests';

/// Absolute path to the build directory used by test.py.
const String buildDirectory =
    const String.fromEnvironment('test.dart.build-dir');

/// Build architecture provided to test.py
const String buildArchitecture =
    const String.fromEnvironment('test.dart.build-arch');

/// Use clang as configured by test.py
const bool buildClang =
    const bool.fromEnvironment('test.dart.build-clang');

/// Host system configuration from test.py
const String buildSystem =
    const String.fromEnvironment('test.dart.build-system');

/// Use asan as configured by test.py
const bool buildAsan =
    const bool.fromEnvironment('test.dart.build-asan');

/// servicec directory as configured by test.py.
final Uri servicecDirectory =
    new Uri(path: const String.fromEnvironment('test.dart.servicec-dir'));

/// Resources directory for servicec.
final Uri resourcesDirectory = servicecDirectory.resolve('lib/src/resources');

/// Temporary directory for test output.
const String tempTestOutputDirectory =
    const String.fromEnvironment("test.dart.temp-dir");

final String generatedDirectory = '$tempTestOutputDirectory/service_tests';

// TODO(zerny): Provide the below constants via configuration from test.py
final String dartinoExecutable = '$buildDirectory/dartino';
final String dartinoLibrary = '$buildDirectory/libdartino.a';

/// Location of JDK installation. Empty if no installation was found.
const String javaHome = const String.fromEnvironment('java-home');

const bool isAsan = buildAsan;
const bool isClang = buildClang;
const bool isGNU = !buildClang;
const bool isMacOS = buildSystem == 'macos';
const bool isLinux = buildSystem == 'linux';

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

abstract class StandardServiceTest extends ServiceTest {
  final String baseName;

  Iterable<String> ccSources;

  StandardServiceTest(name, type, ccSources)
      : super('${name}_${type}'),
        baseName = name {
    this.ccSources = ccSources.map((path) => '$inputDirectory/$path').toList()
        ..add('$outputDirectory/cc/${baseName}_service.cc')
        ..add('$outputDirectory/cc/struct.cc')
        ..add('$outputDirectory/cc/unicode.cc');
  }

  String get inputDirectory => '$thisDirectory/$baseName';

  String get idlPath => '$inputDirectory/${baseName}_service.idl';
  String get serviceImpl => '${baseName}_service_impl.dart';
  String get servicePath => '$outputDirectory/$serviceImpl';
  String get snapshotPath => '$outputDirectory/${baseName}.snapshot';
  String get executablePath => '$outputDirectory/service_${baseName}_test';

  void prepareService() {
    rules.add(new CompileServiceRule(idlPath, outputDirectory));
  }

  void prepareSnapshot() {
    rules.add(new CopyRule(inputDirectory, outputDirectory, [serviceImpl]));
    rules.add(new BuildSnapshotRule(servicePath, snapshotPath));
  }
}

class StandardServiceCcTest extends StandardServiceTest {
  StandardServiceCcTest(name, ccSources)
      : super(name, 'cc', ccSources);

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

class StandardServiceJavaTest extends StandardServiceTest {
  final String mainClass;
  Iterable<String> javaSources;

  StandardServiceJavaTest(name, this.mainClass, this.javaSources, ccSources)
      : super(name, 'java', ccSources);

  String get javaDirectory => '$outputDirectory/java';
  String get classesDirectory => '$outputDirectory/classes';
  String get jarFile => '$outputDirectory/$baseName.jar';

  Future<Null> prepare() async {
    prepareService();
    prepareSnapshot();

    // Complete the test here if Java home is not set.
    if (javaHome.isEmpty) return;

    rules.add(new CcRule(
        sharedLibrary: '$outputDirectory/libdartino',
        includePaths: [
          'include',
          '$javaHome/include',
          '$javaHome/include/${isMacOS ? "darwin" : "linux"}',
          outputDirectory,
        ],
        sources: [
          '$javaDirectory/jni/dartino_api_wrapper.cc',
          '$javaDirectory/jni/dartino_service_api_wrapper.cc',
          '$javaDirectory/jni/${baseName}_service_wrapper.cc',
        ]..addAll(ccSources)));

    rules.add(new MakeDirectoryRule(classesDirectory));

    rules.add(new JavacRule(
        warningAsError: false,
        sources: ['$javaDirectory/dartino']
          ..addAll(javaSources.map((path) => '$inputDirectory/$path')),
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

List<ServiceTest> buildStandardServiceTests(
    name,
    {ccSources: const <String>[],
     javaSources: const <String>[],
     javaMainClass}) {
  return <ServiceTest>[
    new StandardServiceCcTest(name, ccSources),
    new StandardServiceJavaTest(name, javaMainClass, javaSources, ccSources),
  ];
}

abstract class Rule {

  Future<Null> build();

  static Future<int> runCommand(
      String executable,
      List<String> arguments,
      [Map<String,String> environment]) async {
    String environmentString = '';
    if (environment != null) {
      environmentString =
          environment.keys.map((k) => '$k=${environment[k]}').join(' ');
    }
    String cmdString = "$environmentString $executable ${arguments.join(' ')}";
    print('Running: $cmdString');

    Process process =
        await Process.start(executable, arguments, environment: environment);

    Future stdout = process.stdout.transform(UTF8.decoder)
        .transform(new LineSplitter())
        .listen(printOut)
        .asFuture()
        .then((_) => print('stdout done'));

    Future stderr = process.stderr.transform(UTF8.decoder)
        .transform(new LineSplitter())
        .listen(printErr)
        .asFuture()
        .then((_) => print('stderr done'));

    process.stdin.close();
    print('stdin closed');

    int exitCode = await process.exitCode;
    print('$cmdString exited with $exitCode');

    await stdout;
    await stderr;

    Expect.equals(0, exitCode);
    return exitCode;
  }

  static void printOut(String message) {
    print("stdout: $message");
  }

  static void printErr(String message) {
    print("stderr: $message");
  }
}

class MakeDirectoryRule extends Rule {
  final String directory;
  final bool recursive;

  MakeDirectoryRule(this.directory, {this.recursive: false});

  Future<Null> build() async {
    await new Directory(directory).create(recursive: recursive);
  }
}

class CopyRule extends Rule {
  String src;
  String dst;
  Iterable<String> files;

  CopyRule(this.src, this.dst, this.files);

  Future<Null> build() async {
    Directory dstDir = new Directory(dst);
    if (!await dstDir.exists()) {
      await dstDir.create(recursive: true);
    }
    Uri srcUri = new Uri.directory(src);
    for (String file in files) {
      File srcFile = new File.fromUri(srcUri.resolve(file));
      if (await srcFile.exists()) {
        await srcFile.copy(dstDir.uri.resolve(file).toFilePath());
      } else {
        throw "Could not find copy-rule source file '$src'.";
      }
    }
  }
}

class JarRule extends Rule {
  final String jar = "$javaHome/bin/jar";

  final String jarFile;
  final Iterable<String> sources;
  final String baseDirectory;

  JarRule(this.jarFile, {
    this.sources: const <String>[],
    this.baseDirectory
  });

  Future<Null> build() async {
    List<String> arguments = <String>["cf", jarFile];
    if (baseDirectory != null) {
      arguments.addAll(['-C', baseDirectory]);
    }
    arguments.addAll(sources);
    await Rule.runCommand(jar, arguments);
  }
}

class JavacRule extends Rule {
  final String javac = "$javaHome/bin/javac";

  final Iterable<String> sources;
  final Iterable<String> classpath;
  final Iterable<String> sourcepath;
  final String outputDirectory;
  final bool warningAsError;
  final bool lint;

  JavacRule({
    this.sources: const <String>[],
    this.classpath,
    this.sourcepath,
    this.outputDirectory,
    this.warningAsError: true,
    this.lint: true
  });

  Future<Null> build() async {
    List<String> arguments = <String>[];

    if (classpath != null) {
      arguments.addAll(['-classpath', classpath.join(':')]);
    }

    if (sourcepath != null) {
      arguments.addAll(['-sourcepath', sourcepath.join(':')]);
    }

    if (outputDirectory != null) {
      arguments.addAll(['-d', outputDirectory]);
    }

    if (warningAsError) arguments.add('-Werror');

    if (lint) arguments.add('-Xlint:all');

    for (String src in sources) {
      if (await FileSystemEntity.isDirectory(src)) {
        arguments.addAll(await new Directory(src)
            .list(recursive: true, followLinks: false)
            .where((entity) => entity is File && entity.path.endsWith('.java'))
            .map((entity) => entity.path)
            .toList());
      } else {
        arguments.add(src);
      }
    }

    await Rule.runCommand(javac, arguments);
  }
}

class JavaRule extends Rule {
  final String java = "$javaHome/bin/java";

  final String mainClass;
  final Iterable<String> arguments;
  final Iterable<String> classpath;
  final bool enableAssertions;
  final String libraryPath;

  JavaRule(this.mainClass, {
    this.arguments: const <String>[],
    this.classpath,
    this.enableAssertions: true,
    this.libraryPath
  });

  Future<Null> build() async {
    List<String> javaArguments = <String>[];
    Map<String, String> javaEnvironment;

    if (buildArchitecture == 'ia32') {
      javaArguments.add('-d32');
    } else if (buildArchitecture == 'x64') {
      javaArguments.add('-d64');
    } else {
      throw "Unsupported architecture $buildArchitecture";
    }

    if (enableAssertions) {
      javaArguments.add('-enableassertions');
    }

    if (classpath != null) {
      javaArguments.addAll(['-classpath', classpath.join(':')]);
    }

    if (libraryPath != null) {
      javaArguments.add('-Djava.library.path=$libraryPath');
      javaEnvironment = <String, String>{ 'LD_LIBRARY_PATH': libraryPath };
    }

    javaArguments.add(mainClass);

    if (arguments != null) {
      javaArguments.addAll(arguments);
    }

    await Rule.runCommand(java, javaArguments, javaEnvironment);
  }
}

// TODO(zerny): Consider refactoring dartino specifics into a derived class.
// TODO(zerny): Find a way to obtain the dartino build configuration from gyp.
class CcRule extends Rule {
  final String language;
  final String executable;
  final String sharedLibrary;
  final Iterable<String> flags;
  final Iterable<String> sources;
  final Iterable<String> libraries;
  final Iterable<String> includePaths;
  final Iterable<String> libraryPaths;

  CcRule({
    this.executable,
    this.sharedLibrary,
    this.language: 'c++11',
    this.flags: const <String>[],
    this.sources: const <String>[],
    this.libraries: const <String>[],
    this.includePaths: const <String>[],
    this.libraryPaths: const <String>[]
  }) {
    if (executable == null && sharedLibrary == null) {
      throw "CcRule expects a valid output path for an executable or library";
    }
    if (executable != null && sharedLibrary != null) {
      throw "CcRule expects either an executable or a library, not both";
    }
  }

  String get compiler => 'tools/cxx_wrapper.py';

  String get output {
    if (executable != null) return executable;
    String suffix = isMacOS ? 'jnilib' : 'so';
    return '$sharedLibrary.$suffix';
  }

  void addBuildFlags(List<String> arguments) {
    arguments.add('-std=${language}');
    arguments.add('-DDARTINO_ENABLE_FFI');
    arguments.add('-DDARTINO_ENABLE_LIVE_CODING');
    arguments.add('-DDARTINO_ENABLE_PRINT_INTERCEPTORS');
    arguments.add('-DDARTINO_ENABLE_NATIVE_PROCESSES');
    if (sharedLibrary != null) arguments.add('-shared');
    if (buildArchitecture == 'ia32') {
      arguments.add('-m32');
      arguments.add('-DDARTINO32');
      arguments.add('-DDARTINO_TARGET_IA32');
    } else if (buildArchitecture == 'x64') {
      arguments.add('-m64');
      arguments.add('-DDARTINO64');
      arguments.add('-DDARTINO_TARGET_X64');
      if (sharedLibrary != null) arguments.add('-fPIC');
    } else {
      throw "Unsupported architecture ${buildArchitecture}";
    }
  }

  void addHostFlags(List<String> arguments) {
    if (isMacOS) {
      arguments.add('-DDARTINO_TARGET_OS_MACOS');
      arguments.add('-DDARTINO_TARGET_OS_POSIX');
      arguments.addAll(['-framework', 'CoreFoundation']);
    } else if (isLinux) {
      arguments.add('-DDARTINO_TARGET_OS_LINUX');
      arguments.add('-DDARTINO_TARGET_OS_POSIX');
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
    arguments.add(dartinoLibrary);
    for (String lib in libraries) {
      arguments.add(lib.endsWith('.a') ? lib : '-l$lib');
    }
  }

  void addHostLibraries(List<String> arguments) {
    arguments.addAll([
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
    if (isClang) arguments.add('-DDARTINO_CLANG');
    if (isAsan) {
      arguments.add('-DDARTINO_ASAN');
      arguments.add('-L/DARTINO_ASAN');
    }
    addBuildFlags(arguments);
    addHostFlags(arguments);
    addUserFlags(arguments);
    addIncludePaths(arguments);
    addLibraryPaths(arguments);
    arguments.addAll(['-o', output]);
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

  Future<Null> build() async {
    await export(program, snapshot);
  }
}

class RunSnapshotsRule extends Rule {
  final String executable;
  final List<String> snapshots;

  RunSnapshotsRule(this.executable, this.snapshots);

  Future<Null> build() {
    Map<String, String> env;
    if (isMacOS && isAsan) {
      env = <String, String>{'DYLD_LIBRARY_PATH': buildDirectory};
    }
    return Rule.runCommand(executable, snapshots, env);
  }
}

class RunSnapshotRule extends RunSnapshotsRule {
  String get snapshot => snapshots[0];

  RunSnapshotRule(String executable, String snapshot)
      : super(executable, [snapshot]);
}

class CompileServiceRule extends Rule {
  final String idlFile;
  final String outputDirectory;

  CompileServiceRule(this.idlFile, this.outputDirectory);

  Future<Null> build() async {
    bool success = await servicec.compileAndReportErrors(
        idlFile, idlFile, resourcesDirectory.path, outputDirectory);
    Expect.isTrue(success);
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
