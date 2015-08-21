// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fletchc_incremental;

import 'dart:async' show
    EventSink,
    Future;

import 'dart:developer' show
    UserTag;

import 'package:compiler/src/apiimpl.dart' show
    Compiler;

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

import 'library_updater.dart' show
    IncrementalCompilerContext,
    LibraryUpdater,
    Logger;

import '../compiler.dart' show
    FletchCompiler;

import '../src/debug_info.dart' show
    DebugInfo;

import '../src/class_debug_info.dart' show
    ClassDebugInfo;

import '../src/fletch_selector.dart' show
    FletchSelector;

import '../src/fletch_compiler.dart' as implementation show
    FletchCompiler;

import '../fletch_system.dart';

import '../src/fletch_compiler.dart' show
    OutputProvider;

import '../src/fletch_backend.dart' show
    FletchBackend;

part 'caching_compiler.dart';

const List<String> INCREMENTAL_OPTIONS = const <String>[
    '--disable-type-inference',
    '--incremental-support',
    '--generate-code-with-compile-time-errors',
    '--no-source-maps', // TODO(ahe): Remove this.
];

class IncrementalCompiler {
  final Uri libraryRoot;
  final Uri packageRoot;
  final CompilerInput inputProvider;
  final List<String> options;
  final CompilerOutput outputProvider;
  final Map<String, dynamic> environment;
  final IncrementalCompilerContext _context;

  implementation.FletchCompiler _compiler;

  IncrementalCompiler(
      {this.libraryRoot,
       this.packageRoot,
       this.inputProvider,
       CompilerDiagnostics diagnosticHandler,
       this.options,
       this.outputProvider,
       this.environment})
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
    _context.incrementalCompiler = this;
  }

  LibraryElement get mainApp => _compiler.mainApp;

  implementation.FletchCompiler get compiler => _compiler;

  /// Perform a full compile of [script]. This will reset the incremental
  /// compiler.
  Future<bool> compile(Uri script) {
    _compiler = null;
    return _reuseCompiler(null).then((Compiler compiler) {
      _compiler = compiler;
      return compiler.run(script);
    });
  }

  Future<Compiler> _reuseCompiler(
      Future<bool> reuseLibrary(LibraryElement library)) {
    List<String> options = this.options == null
        ? <String> [] : new List<String>.from(this.options);
    options.addAll(INCREMENTAL_OPTIONS);
    return reuseCompiler(
        cachedCompiler: _compiler,
        libraryRoot: libraryRoot,
        packageRoot: packageRoot,
        inputProvider: inputProvider,
        diagnosticHandler: _context,
        options: options,
        outputProvider: outputProvider,
        environment: environment,
        reuseLibrary: reuseLibrary);
  }

  /// Perform an incremental compilation of [updatedFiles]. [compile] must have
  /// been called once before calling this method.
  Future<FletchDelta> compileUpdates(
      FletchSystem currentSystem,
      Map<Uri, Uri> updatedFiles,
      {Logger logTime,
       Logger logVerbose}) {
    if (logTime == null) {
      logTime = (_) {};
    }
    if (logVerbose == null) {
      logVerbose = (_) {};
    }
    Future mappingInputProvider(Uri uri) {
      Uri updatedFile = updatedFiles[uri];
      return inputProvider.readFromUri(updatedFile == null ? uri : updatedFile);
    }
    LibraryUpdater updater = new LibraryUpdater(
        _compiler,
        mappingInputProvider,
        logTime,
        logVerbose,
        _context);
    _context.registerUriWithUpdates(updatedFiles.keys);
    return _reuseCompiler(updater.reuseLibrary).then((Compiler compiler) {
      _compiler = compiler;
      return updater.computeUpdateFletch(currentSystem);
    });
  }

  FletchDelta computeInitialDelta() {
    FletchBackend backend = _compiler.backend;
    return backend.computeDelta();
  }

  String lookupFunctionName(FletchFunction function) {
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

  ClassDebugInfo createClassDebugInfo(FletchClass klass) {
    return _compiler.context.backend.createClassDebugInfo(klass);
  }

  String lookupFunctionNameBySelector(int selector) {
    int id = FletchSelector.decodeId(selector);
    return _compiler.context.symbols[id];
  }

  DebugInfo createDebugInfo(FletchFunction function) {
    return _compiler.context.backend.createDebugInfo(function);
  }

  DebugInfo debugInfoForPosition(String file, int position) {
    return _compiler.debugInfoForPosition(file, position);
  }

  int positionInFileFromPattern(String file, int line, String pattern) {
    return _compiler.positionInFileFromPattern(file, line, pattern);
  }

  int positionInFile(String file, int line, int column) {
    return _compiler.positionInFile(file, line, column);
  }
}

class IncrementalCompilationFailed {
  final String reason;

  const IncrementalCompilationFailed(this.reason);

  String toString() => "Can't incrementally compile program.\n\n$reason";
}
