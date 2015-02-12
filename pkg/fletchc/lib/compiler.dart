// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.compiler;

import 'dart:io' show
    File,
    Link,
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

const String StringOrUri = "String or Uri";

class FletchCompiler {
  final implementation.FletchCompiler _compiler;

  final Uri script;

  FletchCompiler._(this._compiler, this.script);

  factory FletchCompiler(
      {CompilerInputProvider provider,
       CompilerOutputProvider outputProvider,
       DiagnosticHandler handler,
       @StringOrUri libraryRoot,
       @StringOrUri packageRoot,
       @StringOrUri script,
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

    libraryRoot = _computedValidatedUri(
        libraryRoot, name: 'libraryRoot', ensureTrailingSlash: true);
    if (libraryRoot == null) {
      libraryRoot = _guessLibraryRoot();
      if (libraryRoot == null) {
        throw new StateError("Unable to guess libraryRoot.");
      }
    } else if (!_looksLikeLibraryRoot(libraryRoot)) {
      throw new ArgumentError(
          "[libraryRoot]: Dart SDK library not found in '$libraryRoot'.");
    }

    script = _computedValidatedUri(script, name: 'script');

    packageRoot = _computedValidatedUri(
        packageRoot, name: 'packageRoot', ensureTrailingSlash: true);
    if (packageRoot == null) {
      if (script != null) {
        packageRoot = script.resolve('packages/');
      } else {
        packageRoot = Uri.base.resolve('packages/');
      }
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

    return new FletchCompiler._(compiler, script);
  }

  void run([@StringOrUri script]) {
    script = _computedValidatedUri(script, name: 'script');
    if (script == null) {
      script = this.script;
    }
    if (script == null) {
      throw new StateError("No [script] provided.");
    }
    _compiler.run(script);
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

Uri _computedValidatedUri(
    @StringOrUri stringOrUri,
    {String name,
     bool ensureTrailingSlash: false}) {
  assert(name != null);
  if (stringOrUri == null) {
    return null;
  } else if (stringOrUri is String) {
    if (ensureTrailingSlash) {
      stringOrUri = appendSlash(stringOrUri);
    }
    return Uri.base.resolve(stringOrUri);
  } else if (stringOrUri is Uri) {
    return Uri.base.resolveUri(stringOrUri);
  } else {
    throw new ArgumentError("[$name] should be a String or a Uri.");
  }
}

Uri _guessLibraryRoot() {
  Uri guess = _executable.resolve('../');
  if (_looksLikeLibraryRoot(guess)) {
    return _resolveSymbolicLinks(guess);
  }
  guess = guess.resolve('../sdk/');
  if (_looksLikeLibraryRoot(guess)) {
    return _resolveSymbolicLinks(guess);
  }
  return null;
}

Uri get _executable {
  // TODO(ajohnsen): This is a workaround for #16994. Clean up this code once
  // the bug is fixed.
  if (Platform.isLinux) {
    return new Uri.file(new Link('/proc/self/exe').targetSync());
  }
  new Uri.file(Platform.executable);
}
