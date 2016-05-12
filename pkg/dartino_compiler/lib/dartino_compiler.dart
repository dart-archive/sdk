// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_compiler;

import 'dart:async' show
    Future;

import 'dart:convert' show
    UTF8;

import 'dart:io' show
    File;

import 'package:compiler/compiler_new.dart' show
    CompilerInput,
    CompilerOutput,
    CompilerDiagnostics;

import 'package:compiler/src/source_file_provider.dart' show
    CompilerSourceFileProvider,
    FormattingDiagnosticHandler,
    SourceFileProvider;

import 'package:compiler/src/filenames.dart' show
    appendSlash;

import 'src/dartino_native_descriptor.dart' show
    DartinoNativeDescriptor;

import 'src/dartino_backend.dart' show
    DartinoBackend;

import 'src/dartino_compiler_implementation.dart' show
    DartinoCompilerImplementation,
    OutputProvider;

import 'dartino_system.dart';

import 'incremental/dartino_compiler_incremental.dart' show
    IncrementalCompiler;

import 'src/guess_configuration.dart' show
    StringOrUri,
    computeValidatedUri,
    executable,
    guessDartinoVm;

import 'src/dartino_compiler_options.dart' show
    DartinoCompilerOptions,
    IncrementalMode;

const String dartinoDeviceType =
    const String.fromEnvironment("dartino.device-type");
const String _NATIVES_JSON =
    const String.fromEnvironment("dartino-natives-json");

class DartinoCompiler {
  final DartinoCompilerImplementation _compiler;

  final Uri script;

  final bool verbose;

  final Uri nativesJson;

  DartinoCompiler._(
      this._compiler,
      this.script,
      this.verbose,
      this.nativesJson);

  Backdoor get backdoor => new Backdoor(this);

  factory DartinoCompiler(
      {CompilerInput provider,
       CompilerOutput outputProvider,
       CompilerDiagnostics handler,
       @StringOrUri script,
       @StringOrUri dartinoVm,
       @StringOrUri currentDirectory,
       @StringOrUri nativesJson,
       DartinoCompilerOptions options,
       IncrementalCompiler incrementalCompiler}) {

    Uri base = computeValidatedUri(
        currentDirectory, name: 'currentDirectory', ensureTrailingSlash: true);
    if (base == null) {
      base = Uri.base;
    }

    script = computeValidatedUri(script, name: 'script', base: base);

    if (options == null) {
      options = DartinoCompilerOptions.parse(<String>[], base, script: script);
    }

    final bool isVerbose = options.verbose;

    if (provider == null) {
      provider = new CompilerSourceFileProvider()
          ..cwd = base;
    }

    if (handler == null) {
      SourceFileProvider sourceFileProvider = null;
      if (provider is SourceFileProvider) {
        sourceFileProvider = provider;
      }
      handler = new FormattingDiagnosticHandler(sourceFileProvider)
          ..throwOnError = false
          ..verbose = isVerbose;
    }

    if (outputProvider == null) {
      outputProvider = new OutputProvider();
    }

    dartinoVm = guessDartinoVm(
        computeValidatedUri(dartinoVm, name: 'dartinoVm', base: base));

    if (nativesJson == null && _NATIVES_JSON != null) {
      nativesJson = base.resolve(_NATIVES_JSON);
    }
    nativesJson = computeValidatedUri(
        nativesJson, name: 'nativesJson', base: base);

    if (nativesJson == null) {
      nativesJson = _guessNativesJson();
      if (nativesJson == null) {
        throw new StateError(
"""
Unable to guess the location of the 'natives.json' file (nativesJson).
Try adding command-line option '-Ddartino-natives-json=<path to natives.json>.
"""
);
      }
    } else if (!_looksLikeNativesJson(nativesJson)) {
      throw new ArgumentError(
          "[nativesJson]: natives.json not found in '$nativesJson'.");
    }

    DartinoCompilerImplementation compiler = new DartinoCompilerImplementation(
        provider,
        outputProvider,
        handler,
        nativesJson,
        options,
        dartinoVm,
        incrementalCompiler);

    compiler.log("Using library root: ${options.libraryRoot}");
    compiler.log("Using package config: ${options.packageConfig}");

    var helper =
        new DartinoCompiler._(compiler, script, isVerbose, nativesJson);
    compiler.helper = helper;
    return helper;
  }

  Future<DartinoDelta> run([@StringOrUri script]) async {
    // TODO(ahe): Need a base argument.
    script = computeValidatedUri(script, name: 'script');
    if (script == null) {
      script = this.script;
    }
    if (script == null) {
      throw new StateError("No [script] provided.");
    }
    await _inititalizeContext();
    DartinoBackend backend = _compiler.backend;
    return _compiler.run(script).then((_) => backend.computeDelta());
  }

  Future _inititalizeContext() async {
    var data = await _compiler.callUserProvider(nativesJson);
    if (data is! String) {
      if (data.last == 0) {
        data = data.sublist(0, data.length - 1);
      }
      data = UTF8.decode(data);
    }
    Map<String, DartinoNativeDescriptor> natives =
        <String, DartinoNativeDescriptor>{};
    Map<String, String> names = <String, String>{};
    DartinoNativeDescriptor.decode(data, natives, names);
    _compiler.context.nativeDescriptors = natives;
    _compiler.context.backend.systemBuilder.setNames(names);
  }

  Uri get dartinoVm => _compiler.dartinoVm;

  /// Create a new instance of [IncrementalCompiler].
  IncrementalCompiler newIncrementalCompiler(IncrementalMode support) {
    return new IncrementalCompiler(
        dartinoVm: _compiler.dartinoVm,
        nativesJson: _compiler.nativesJson,
        inputProvider: _compiler.provider,
        diagnosticHandler: _compiler.handler,
        options: DartinoCompilerOptions.copy(
            _compiler.options, incrementalMode: support),
        outputProvider: _compiler.userOutputProvider);
  }
}

// Backdoor around Dart privacy. For now, certain components (in particular
// incremental compilation) need access to implementation details that shouldn't
// be part of the API of this file.
// TODO(ahe): Delete this class.
class Backdoor {
  final DartinoCompiler _compiler;

  Backdoor(this._compiler);

  Future<DartinoCompilerImplementation> get compilerImplementation async {
    await _compiler._inititalizeContext();
    return _compiler._compiler;
  }
}

/// Resolves any symbolic links in [uri] if its scheme is "file". Otherwise
/// return the given [uri].
Uri _resolveSymbolicLinks(Uri uri) {
  if (uri.scheme != 'file') return uri;
  File apparentLocation = new File.fromUri(uri);
  String realLocation = apparentLocation.resolveSymbolicLinksSync();
  if (uri.path.endsWith("/")) {
    realLocation = appendSlash(realLocation);
  }
  return new Uri.file(realLocation);
}

bool _looksLikeNativesJson(Uri uri) {
  return new File.fromUri(uri).existsSync();
}

Uri _guessNativesJson() {
  Uri uri = executable.resolve('natives.json');
  return _looksLikeNativesJson(uri) ? uri : null;
}
