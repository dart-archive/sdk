// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino_compiler.test.incremental_test_runner;

import 'dart:io' hide
    exitCode,
    stderr,
    stdin,
    stdout;

import 'dart:async' show
    Future;

import 'package:expect/expect.dart' show
    Expect;

import 'package:dartino_compiler/incremental/scope_information_visitor.dart'
    show ScopeInformationVisitor;

import 'compiler_test_case.dart' show
    CompilerTestCase;

import 'package:compiler/src/elements/elements.dart' show
    Element,
    LibraryElement;

import 'package:compiler/src/compiler.dart' show
    Compiler;

import 'package:compiler/src/source_file_provider.dart' show
    FormattingDiagnosticHandler,
    SourceFileProvider;

import 'package:compiler/src/io/source_file.dart' show
    StringSourceFile;

import 'package:dartino_compiler/incremental/dartino_compiler_incremental.dart'
    show
        IncrementalCompiler,
        IncrementalMode;

import 'package:dartino_compiler/vm_commands.dart' show
    VmCommand;

import 'package:dartino_compiler/src/dartino_compiler_implementation.dart' show
    OutputProvider;

import 'package:dartino_compiler/dartino_system.dart' show
    DartinoDelta,
    DartinoFunction,
    DartinoSystem;

import 'program_result.dart' show
    EncodedResult,
    ProgramResult;

const String PACKAGE_SCHEME = 'org.dartlang.dartino.packages';

const String CUSTOM_SCHEME = 'org.dartlang.dartino.test-case';

final Uri customUriBase = new Uri(scheme: CUSTOM_SCHEME, path: '/');

abstract class IncrementalTestRunner {
  final String testName;

  final EncodedResult encodedResult;

  final IncrementalMode incrementalMode;

  final IncrementalTestHelper helper;

  ProgramResult program;

  int version = 1;

  bool hasCompileTimeError = false;

  bool isFirstProgram = true;

  IncrementalTestRunner(
      this.testName,
      this.encodedResult,
      IncrementalMode incrementalMode)
      : incrementalMode = incrementalMode,
        helper = new IncrementalTestHelper(incrementalMode);

  Future<Null> run() async {
    print("Test '$testName'");
    for (ProgramResult program in encodedResult.decode()) {
      this.program = program;
      hasCompileTimeError = program.hasCompileTimeError;
      await testProgramVersion();
      isFirstProgram = false;
      version++;
    }
    await tearDown();
  }

  Future<Null> testProgramVersion() async {
    print("Program version $version #$testName:");
    print(numberedLines(program.code));
    await runDelta(await compile());
  }

  Future<DartinoDelta> compile() async {
    DartinoDelta dartinoDelta;
    if (isFirstProgram) {
      // The first program is compiled "fully".
      dartinoDelta = await helper.fullCompile(program);
    } else {
      // An update to the first program, all updates are compiled as
      // incremental updates to the first program.
      dartinoDelta = await helper.incrementalCompile(program, version);
    }

    if (!isFirstProgram ||
        const bool.fromEnvironment("feature_test.print_initial_commands")) {
      for (VmCommand command in dartinoDelta.commands) {
        print(command);
      }
    }

    return dartinoDelta;
  }

  Future<Null> runDelta(DartinoDelta delta) async {
    // TODO(ahe): Enable SerializeScopeTestCase for multiple parts.
    if (!isFirstProgram && program.code is String) {
      await new SerializeScopeTestCase(
          program.code, helper.compiler.mainApp,
          helper.compiler.compiler).run();
    }
  }

  Future<Null> tearDown();
}

class SerializeScopeTestCase extends CompilerTestCase {
  final String source;

  final String scopeInfo;

  final Compiler compiler = null; // TODO(ahe): Provide a compiler.

  SerializeScopeTestCase(
      this.source,
      LibraryElement library,
      Compiler compiler)
      : scopeInfo = computeScopeInfo(compiler, library),
        super(library.canonicalUri);

  Future run() {
    if (true) {
      // TODO(ahe): Remove this. We're temporarily bypassing scope validation.
      return new Future.value(null);
    }
    return loadMainApp().then(checkScopes);
  }

  void checkScopes(LibraryElement library) {
    var compiler = null;
    Expect.stringEquals(computeScopeInfo(compiler, library), scopeInfo);
  }

  Future<LibraryElement> loadMainApp() async {
    LibraryElement library =
        await compiler.libraryLoader.loadLibrary(scriptUri);
    if (compiler.mainApp == null) {
      compiler.mainApp = library;
    } else if (compiler.mainApp != library) {
      throw "Inconsistent use of compiler (${compiler.mainApp} != $library).";
    }
    return library;
  }

  static String computeScopeInfo(Compiler compiler, LibraryElement library) {
    ScopeInformationVisitor visitor =
        new ScopeInformationVisitor(compiler, library, 0);

    visitor.ignoreImports = true;
    visitor.sortMembers = true;
    visitor.indented.write('[\n');
    visitor.indentationLevel++;
    visitor.indented;
    library.accept(visitor, null);
    library.forEachLocalMember((Element member) {
      if (member.isClass) {
        visitor.buffer.write(',\n');
        visitor.indented;
        member.accept(visitor, null);
      }
    });
    visitor.buffer.write('\n');
    visitor.indentationLevel--;
    visitor.indented.write(']');
    return '${visitor.buffer}';
  }
}

void logger(x) {
  print(x);
}

String numberedLines(code) {
  if (code is! Map) {
    code = {'main.dart': code};
  }
  StringBuffer result = new StringBuffer();
  code.forEach((String fileName, String code) {
    result.writeln("==> $fileName <==");
    int lineNumber = 1;
    for (String text in splitLines(code)) {
      result.write("$lineNumber: $text");
      lineNumber++;
    }
  });
  return '$result';
}

List<String> splitLines(String text) {
  return text.split(new RegExp('^', multiLine: true));
}

class IncrementalTestHelper {
  final Uri packageConfig;

  final IoInputProvider inputProvider;

  final IncrementalCompiler compiler;

  DartinoSystem system;

  IncrementalTestHelper.internal(
      this.packageConfig,
      this.inputProvider,
      this.compiler);

  factory IncrementalTestHelper(IncrementalMode incrementalMode) {
    Uri packageConfig = Uri.base.resolve('.packages');
    IoInputProvider inputProvider = new IoInputProvider(packageConfig);
    FormattingDiagnosticHandler diagnosticHandler =
        new FormattingDiagnosticHandler(inputProvider);
    IncrementalCompiler compiler = new IncrementalCompiler(
        packageConfig: packageConfig,
        inputProvider: inputProvider,
        diagnosticHandler: diagnosticHandler,
        outputProvider: new OutputProvider(),
        support: incrementalMode,
        platform: "dartino_mobile.platform");
    return new IncrementalTestHelper.internal(
        packageConfig,
        inputProvider,
        compiler);
  }

  Future<DartinoDelta> fullCompile(ProgramResult program) async {
    Map<String, String> code = computeCode(program);
    inputProvider.sources.clear();
    code.forEach((String name, String code) {
      inputProvider.sources[customUriBase.resolve(name)] = code;
    });

    await compiler.compile(customUriBase.resolve('main.dart'), customUriBase);
    DartinoDelta delta = compiler.compiler.context.backend.computeDelta();
    system = delta.system;
    return delta;
  }

  Future<DartinoDelta> incrementalCompile(
      ProgramResult program,
      int version) async {
    Map<String, String> code = computeCode(program);
    Map<Uri, Uri> uriMap = <Uri, Uri>{};
    for (String name in code.keys) {
      Uri uri = customUriBase.resolve('$name?v$version');
      inputProvider.cachedSources[uri] = new Future.value(code[name]);
      uriMap[customUriBase.resolve(name)] = uri;
    }
    DartinoDelta delta = await compiler.compileUpdates(
        system, uriMap, logVerbose: logger, logTime: logger);
    system = delta.system;
    return delta;
  }

  Map<String, String> computeCode(ProgramResult program) {
    return program.code is String
        ? <String,String>{ 'main.dart': program.code }
        : program.code;
  }
}

/// An input provider which provides input via the class [File].  Includes
/// in-memory compilation units [sources] which are returned when a matching
/// key requested.
class IoInputProvider extends SourceFileProvider {
  final Map<Uri, String> sources = <Uri, String>{};

  final Uri packageConfig;

  final Map<Uri, Future> cachedSources = new Map<Uri, Future>();

  static final Map<Uri, String> cachedFiles = new Map<Uri, String>();

  IoInputProvider(this.packageConfig);

  Future readFromUri(Uri uri) {
    return cachedSources.putIfAbsent(uri, () {
      String text;
      String name;
      if (sources.containsKey(uri)) {
        name = '$uri';
        text = sources[uri];
      } else {
        if (uri.scheme == PACKAGE_SCHEME) {
          throw "packages not supported $uri";
        }
        text = readCachedFile(uri);
        name = new File.fromUri(uri).path;
      }
      sourceFiles[uri] = new StringSourceFile(uri, name, text);
      return new Future<String>.value(text);
    });
  }

  Future call(Uri uri) => readStringFromUri(uri);

  Future<String> readStringFromUri(Uri uri) {
    return readFromUri(uri);
  }

  Future<List<int>> readUtf8BytesFromUri(Uri uri) {
    throw "not supported";
  }

  static String readCachedFile(Uri uri) {
    return cachedFiles.putIfAbsent(
        uri, () => new File.fromUri(uri).readAsStringSync());
  }
}
