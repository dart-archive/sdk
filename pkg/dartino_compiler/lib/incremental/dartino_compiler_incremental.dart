// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartino_compiler_incremental;

import 'dart:async' show
    EventSink,
    Future;

import 'dart:developer' show
    UserTag;

import 'package:compiler/src/apiimpl.dart' show
    CompilerImpl;

import 'package:compiler/compiler_new.dart' show
    CompilerDiagnostics,
    CompilerInput,
    CompilerOutput,
    Diagnostic;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    ConstructorElement,
    Element,
    FunctionElement,
    LibraryElement;

import 'package:compiler/src/library_loader.dart' show
    ReuseLibrariesFunction;

import 'dartino_reuser.dart' show
    IncrementalCompilerContext,
    DartinoReuser,
    Logger;

import '../dartino_compiler.dart' show
    DartinoCompiler;

import '../src/debug_info.dart' show
    DebugInfo;

import '../src/class_debug_info.dart' show
    ClassDebugInfo;

import '../src/dartino_selector.dart' show
    DartinoSelector;

import '../src/dartino_compiler_implementation.dart' show
    DartinoCompilerImplementation,
    OutputProvider;

import '../dartino_system.dart';

import '../dartino_class.dart' show
    DartinoClass;

import '../src/dartino_backend.dart' show
    DartinoBackend;

import '../src/hub/exit_codes.dart' as exit_codes;

import 'package:compiler/src/source_file_provider.dart' show
    SourceFileProvider;

import 'package:compiler/src/tokens/token.dart' show
    Token;

import 'package:compiler/src/diagnostics/source_span.dart' show
    SourceSpan;

part 'caching_compiler.dart';

const List<String> INCREMENTAL_OPTIONS = const <String>[
    '--disable-type-inference',
    '--incremental-support',
    '--generate-code-with-compile-time-errors',
    '--no-source-maps', // TODO(ahe): Remove this.
];

enum IncrementalMode {
  /// Incremental compilation is turned off
  none,

  /// Incremental compilation is turned on for a limited set of features that
  /// are known to be fully implemented. Initially, this limited set of
  /// features will be instance methods without signature changes. As other
  /// features mature, they will be enabled in this mode.
  production,

  /// All incremental features are turned on even if we know that we don't
  /// always generate correct code. Initially, this covers features such as
  /// schema changes.
  experimental,
}

class IncrementalCompiler {
  final Uri libraryRoot;
  final Uri nativesJson;
  final Uri packageConfig;
  final Uri dartinoVm;
  final CompilerInput inputProvider;
  final List<String> options;
  final CompilerOutput outputProvider;
  final Map<String, dynamic> environment;
  final IncrementalCompilerContext _context;
  final IncrementalMode support;
  final String platform;
  final Map<Uri, Uri> _updatedFiles = new Map<Uri, Uri>();

  DartinoCompilerImplementation _compiler;

  IncrementalCompiler(
      {this.libraryRoot,
       this.nativesJson,
       this.packageConfig,
       this.dartinoVm,
       this.inputProvider,
       CompilerDiagnostics diagnosticHandler,
       this.options,
       this.outputProvider,
       this.environment,
       this.support: IncrementalMode.none,
       this.platform})
      : _context = new IncrementalCompilerContext(diagnosticHandler) {
    // if (libraryRoot == null) {
    //   throw new ArgumentError('libraryRoot is null.');
    // }
    if (inputProvider == null) {
      throw new ArgumentError('inputProvider is null.');
    }
    if (outputProvider == null) {
      throw new ArgumentError('outputProvider is null.');
    }
    if (diagnosticHandler == null) {
      throw new ArgumentError('diagnosticHandler is null.');
    }
    if (platform == null) {
      throw new ArgumentError('platform is null.');
    }
    _context.incrementalCompiler = this;
  }

  bool get isProductionModeEnabled {
    return support == IncrementalMode.production ||
        support == IncrementalMode.experimental;
  }

  bool get isExperimentalModeEnabled {
    return support == IncrementalMode.experimental;
  }

  LibraryElement get mainApp => _compiler.mainApp;

  DartinoCompilerImplementation get compiler => _compiler;

  /// Perform a full compile of [script]. This will reset the incremental
  /// compiler.
  ///
  /// Error messages will be reported relative to [base].
  ///
  /// Notice: a full compile means not incremental. The part of the program
  /// that is compiled is determined by tree shaking.
  Future<bool> compile(Uri script, Uri base) {
    _compiler = null;
    _updatedFiles.clear();
    return _reuseCompiler(null, base: base).then((CompilerImpl compiler) {
      _compiler = compiler;
      return compiler.run(script);
    });
  }

  /// Perform a full analysis of [script]. This will reset the incremental
  /// compiler.
  ///
  /// Error messages will be reported relative to [base].
  ///
  /// Notice: a full analysis is analogous to a full compile, that is, full
  /// analysis not incremental. The part of the program that is analyzed is
  /// determined by tree shaking.
  Future<int> analyze(Uri script, Uri base) {
    _compiler = null;
    int initialErrorCount = _context.errorCount;
    int initialProblemCount = _context.problemCount;
    return _reuseCompiler(null, analyzeOnly: true, base: base).then(
        (CompilerImpl compiler) {
      // Don't try to reuse the compiler object.
      return compiler.run(script).then((_) {
        return _context.problemCount == initialProblemCount
            ? 0
            : _context.errorCount == initialErrorCount
                ? exit_codes.ANALYSIS_HAD_NON_ERROR_PROBLEMS
                : exit_codes.ANALYSIS_HAD_ERRORS;
      });
    });
  }

  Future<CompilerImpl> _reuseCompiler(
      ReuseLibrariesFunction reuseLibraries,
      {bool analyzeOnly: false,
       Uri base}) {
    List<String> options = this.options == null
        ? <String> [] : new List<String>.from(this.options);
    options.addAll(INCREMENTAL_OPTIONS);
    if (analyzeOnly) {
      options.add("--analyze-only");
    }
    return reuseCompiler(
        cachedCompiler: _compiler,
        libraryRoot: libraryRoot,
        packageConfig: packageConfig,
        nativesJson: nativesJson,
        dartinoVm: dartinoVm,
        inputProvider: inputProvider,
        diagnosticHandler: _context,
        options: options,
        outputProvider: outputProvider,
        environment: environment,
        reuseLibraries: reuseLibraries,
        platform: platform,
        base: base,
        incrementalCompiler: this);
  }

  void _checkCompilationFailed() {
    if (!isExperimentalModeEnabled && _compiler.compilationFailed) {
      throw new IncrementalCompilationFailed(
          "Unable to reuse compiler due to compile-time errors");
    }
  }

  /// Perform an incremental compilation of [updatedFiles]. [compile] must have
  /// been called once before calling this method.
  ///
  /// Error messages will be reported relative to [base], if [base] is not
  /// provided the previous set [base] will be used.
  Future<DartinoDelta> compileUpdates(
      DartinoSystem currentSystem,
      Map<Uri, Uri> updatedFiles,
      {Logger logTime,
       Logger logVerbose,
       Uri base}) {
    _checkCompilationFailed();
    if (logTime == null) {
      logTime = (_) {};
    }
    if (logVerbose == null) {
      logVerbose = (_) {};
    }
    updatedFiles.forEach((Uri from, Uri to) {
      _updatedFiles[from] = to;
    });
    Future mappingInputProvider(Uri uri) {
      Uri updatedFile = _updatedFiles[uri];
      return inputProvider.readFromUri(updatedFile == null ? uri : updatedFile);
    }
    DartinoReuser reuser = new DartinoReuser(
        _compiler,
        mappingInputProvider,
        logTime,
        logVerbose,
        _context);
    _context.registerUriWithUpdates(updatedFiles.keys);
    return _reuseCompiler(reuser.reuseLibraries, base: base).then(
        (CompilerImpl compiler) async {
          _compiler = compiler;
          DartinoDelta delta = await reuser.computeUpdateDartino(currentSystem);
          _checkCompilationFailed();
          return delta;
        });
  }

  DartinoDelta computeInitialDelta() {
    DartinoBackend backend = _compiler.backend;
    return backend.computeDelta();
  }

  String lookupFunctionName(DartinoFunction function) {
    if (function.isParameterStub) return "<parameter stub>";
    Element element = function.element;
    if (element == null) return function.name;
    if (element.isConstructor) {
      ConstructorElement constructor = element;
      ClassElement enclosing = constructor.enclosingClass;
      String name = (constructor.name == null || constructor.name.length == 0)
          ? ''
          : '.${constructor.name}';
      String postfix = function.isInitializerList ? ' initializer' : '';
      return '${enclosing.name}$name$postfix';
    }

    ClassElement enclosing = element.enclosingClass;
    if (enclosing == null) return function.name;
    return '${enclosing.name}.${function.name}';
  }

  ClassDebugInfo createClassDebugInfo(DartinoClass klass) {
    return _compiler.context.backend.createClassDebugInfo(klass);
  }

  String lookupFunctionNameBySelector(int selector) {
    int id = DartinoSelector.decodeId(selector);
    return _compiler.context.symbols[id];
  }

  DebugInfo createDebugInfo(
      DartinoFunction function,
      DartinoSystem currentSystem) {
    return _compiler.context.backend.createDebugInfo(function, currentSystem);
  }

  DebugInfo debugInfoForPosition(
      Uri file,
      int position,
      DartinoSystem currentSystem) {
    return _compiler.debugInfoForPosition(file, position, currentSystem);
  }

  int positionInFileFromPattern(Uri file, int line, String pattern) {
    return _compiler.positionInFileFromPattern(file, line, pattern);
  }

  int positionInFile(Uri file, int line, int column) {
    return _compiler.positionInFile(file, line, column);
  }

  Iterable<Uri> findSourceFiles(Pattern pattern) {
    return _compiler.findSourceFiles(pattern);
  }

  SourceSpan createSourceSpan(
      Token begin,
      Token end,
      Uri uri,
      Element element) {
    Uri update = _updatedFiles[uri];
    if (update != null) {
      // TODO(ahe): Compute updated position.
      return new SourceSpan(update, 0, 0);
    }
    return new SourceSpan.fromTokens(uri, begin, end);
  }
}

class IncrementalCompilationFailed {
  final String reason;

  const IncrementalCompilationFailed(this.reason);

  String toString() => "Can't incrementally compile program.\n\n$reason";
}

String unparseIncrementalMode(IncrementalMode mode) {
  switch (mode) {
    case IncrementalMode.none:
      return "none";

    case IncrementalMode.production:
      return "production";

    case IncrementalMode.experimental:
      return "experimental";
  }
  throw "Unhandled $mode";
}

IncrementalMode parseIncrementalMode(String text) {
  switch (text) {
    case "none":
      return IncrementalMode.none;

    case "production":
        return IncrementalMode.production;

    case "experimental":
      return IncrementalMode.experimental;

  }
  return null;
}
