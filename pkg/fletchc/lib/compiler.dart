// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.compiler;

import 'dart:io' show
    File,
    Platform;

import 'package:compiler/compiler.dart' show
    CompilerInputProvider,
    CompilerOutputProvider,
    DiagnosticHandler;

import 'package:dart2js_incremental/compiler.dart' show
    OutputProvider;

import 'package:compiler/src/source_file_provider.dart' show
    CompilerSourceFileProvider,
    FormattingDiagnosticHandler,
    SourceFileProvider;

import 'package:compiler/src/filenames.dart' show
    appendSlash;

import 'package:compiler/src/apiimpl.dart' as apiimpl;

import 'src/fletch_compiler.dart' as implementation;

class FletchCompiler {
  final implementation.FletchCompiler _compiler;

  FletchCompiler._(this._compiler);

  factory FletchCompiler(
      {CompilerInputProvider provider,
       CompilerOutputProvider outputProvider,
       DiagnosticHandler handler,
       /* String or Uri */ libraryRoot,
       /* String or Uri */ packageRoot,
       List<String> options,
       Map<String, dynamic> environment}) {
    if (options == null) {
      options = <String>[];
    }

    final bool isVerbose = apiimpl.Compiler.hasOption(options, '--verbose');

    if (provider == null) {
      provider = new CompilerSourceFileProvider();
    }

    if (handler == null) {
      SourceFileProvider sourceFileProvider = null;
      if (provider is SourceFileProvider) {
        sourceFileProvider = provider;
      }
      handler = new FormattingDiagnosticHandler(provider)
          ..throwOnError = false
          ..verbose = isVerbose;
    }

    if (outputProvider == null) {
      outputProvider = new OutputProvider();
    }

    if (libraryRoot == null) {
      libraryRoot = _guessLibraryRoot();
      if (libraryRoot == null) {
        throw new StateError("Unable to guess libraryRoot.");
      }
    }

    if (packageRoot == null) {
      packageRoot = Uri.base.resolve('packages/');
    }


    if (environment == null) {
      environment = <String, dynamic>{};
    }

    implementation.FletchCompiler compiler = new implementation.FletchCompiler(
        provider,
        outputProvider,
        handler,
        libraryRoot,
        packageRoot,
        options,
        environment);

    compiler.log("Using library root: $libraryRoot");
    compiler.log("Using package root: $packageRoot");

    return new FletchCompiler._(compiler);
  }

  void run(Uri script) {
    _compiler.run(script);
  }

  static Uri _guessLibraryRoot() {
    Uri guess = new Uri.file(Platform.executable).resolve('../');
    if (_looksLikeLibraryRoot(guess)) {
      return _resolveSymbolicLinks(guess);
    }
    guess = guess.resolve('../sdk/');
    if (_looksLikeLibraryRoot(guess)) {
      return _resolveSymbolicLinks(guess);
    }
    return null;
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

bool _looksLikeLibraryRoot(Uri uri) {
  String expectedFile = 'lib/_internal/libraries.dart';
  return new File.fromUri(uri.resolve(expectedFile)).existsSync();
}
