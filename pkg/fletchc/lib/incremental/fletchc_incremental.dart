// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library fletchc_incremental;

import 'dart:async' show
    EventSink,
    Future;

import 'dart:profiler' show
    UserTag;

import 'package:compiler/src/apiimpl.dart' show
    Compiler;

import 'package:compiler/compiler_new.dart' show
    CompilerDiagnostics,
    CompilerInput,
    CompilerOutput,
    Diagnostic;

import 'package:compiler/src/elements/elements.dart' show
    LibraryElement;

import 'library_updater.dart' show
    IncrementalCompilerContext,
    LibraryUpdater,
    Logger;

import '../compiler.dart' show
    FletchCompiler;

import '../src/fletch_compiler.dart' as implementation show
    FletchCompiler;

import '../fletch_system.dart';

import 'compiler.dart' show
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
  final CompilerDiagnostics diagnosticHandler;
  final List<String> options;
  final CompilerOutput outputProvider;
  final Map<String, dynamic> environment;
  final IncrementalCompilerContext _context;

  implementation.FletchCompiler _compiler;

  IncrementalCompiler(
      bool useFletchSystem,
      {this.libraryRoot,
       this.packageRoot,
       this.inputProvider,
       this.diagnosticHandler,
       this.options,
       this.outputProvider,
       this.environment})
      : _context = new IncrementalCompilerContext(useFletchSystem) {
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
        diagnosticHandler: diagnosticHandler,
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
}

class IncrementalCompilationFailed {
  final String reason;

  const IncrementalCompilationFailed(this.reason);

  String toString() => "Can't incrementally compile program.\n\n$reason";
}
