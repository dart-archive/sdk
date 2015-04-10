// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.compiler;

import 'dart:async' show
    Future;

import 'dart:convert' show
    UTF8;

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

import 'src/compiled_function.dart' show
    CompiledFunction;

import 'src/fletch_native_descriptor.dart' show
    FletchNativeDescriptor;

import 'src/fletch_backend.dart' show
    FletchBackend;

import 'package:compiler/src/apiimpl.dart' as apiimpl;

import 'src/fletch_compiler.dart' as implementation;

import 'src/fletch_selector.dart';

const String _SDK_DIR = const String.fromEnvironment("dart-sdk");

const String _FLETCH_VM = const String.fromEnvironment("fletch-vm");

const List<String> _fletchVmSuggestions = const <String> [
    'out/DebugX64Clang/fletch',
    'out/DebugX64/fletch',
    'out/ReleaseX64Clang/fletch',
    'out/ReleaseX64/fletch',
];

const String StringOrUri = "String or Uri";

class FletchCompiler {
  final implementation.FletchCompiler _compiler;

  final Uri script;

  final bool verbose;

  FletchCompiler._(this._compiler, this.script, this.verbose);

  Backdoor get backdoor => new Backdoor(this);

  factory FletchCompiler(
      {CompilerInputProvider provider,
       CompilerOutputProvider outputProvider,
       DiagnosticHandler handler,
       @StringOrUri libraryRoot,
       @StringOrUri packageRoot,
       @StringOrUri script,
       @StringOrUri fletchVm,
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

    libraryRoot = _computeValidatedUri(
        libraryRoot, name: 'libraryRoot', ensureTrailingSlash: true);
    if (libraryRoot == null  && _SDK_DIR != null) {
      libraryRoot = Uri.base.resolve(appendSlash(_SDK_DIR));
    }
    if (libraryRoot == null) {
      libraryRoot = _guessLibraryRoot();
      if (libraryRoot == null) {
        throw new StateError("""
Unable to guess the location of the Dart SDK (libraryRoot).
Try adding command-line option '-Ddart-sdk=<location of the Dart sdk>'.""");
      }
    } else if (!_looksLikeLibraryRoot(libraryRoot)) {
      throw new ArgumentError(
          "[libraryRoot]: Dart SDK library not found in '$libraryRoot'.");
    }

    script = _computeValidatedUri(script, name: 'script');

    packageRoot = _computeValidatedUri(
        packageRoot, name: 'packageRoot', ensureTrailingSlash: true);
    if (packageRoot == null) {
      if (script != null) {
        packageRoot = script.resolve('packages/');
      } else {
        packageRoot = Uri.base.resolve('packages/');
      }
    }

    fletchVm = _computeValidatedUri(
        fletchVm, name: 'fletchVm', ensureTrailingSlash: false);
    if (fletchVm == null) {
      fletchVm = _guessFletchVm();
      if (fletchVm == null) {
        throw new StateError("""
Unable to guess the location of the fletch VM (fletchVm).
Try adding command-line option '-Dfletch-vm=<path to Dart sdk>.""");
      }
    } else if (!_looksLikeFletchVm(fletchVm)) {
      throw new ArgumentError("[fletchVm]: Fletch VM at '$fletchVm'.");
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
        environment,
        fletchVm);

    compiler.log("Using library root: $libraryRoot");
    compiler.log("Using package root: $packageRoot");

    return new FletchCompiler._(compiler, script, isVerbose);
  }

  Future run([@StringOrUri script]) {
    script = _computeValidatedUri(script, name: 'script');
    if (script == null) {
      script = this.script;
    }
    if (script == null) {
      throw new StateError("No [script] provided.");
    }

    Uri nativesJson = _compiler.fletchVm.resolve("natives.json");
    return _compiler.callUserProvider(nativesJson).then((data) {
      if (data is! String) {
        if (data.last == 0) {
          data = data.sublist(0, data.length - 1);
        }
        data = UTF8.decode(data);
      }
      Map<String, FletchNativeDescriptor> natives =
          <String, FletchNativeDescriptor>{};
      Map<String, String> names = <String, String>{};
      FletchNativeDescriptor.decode(data, natives, names);
      _compiler.context.nativeDescriptors = natives;
      _compiler.context.setNames(names);
      FletchBackend backend = _compiler.backend;
      return _compiler.run(script).then((_) => backend.commands);
    });
  }

  Uri get fletchVm => _compiler.fletchVm;

  CompiledFunction lookupCompiledFunction(int id) {
    CompiledFunction function = _compiler.backend.functions[id];
    assert(function.methodId == id);
    return function;
  }

  String lookupFunctionName(int id) {
    return lookupCompiledFunction(id).name;
  }

  String lookupFunctionNameBySelector(int selector) {
    int id = FletchSelector.decodeId(selector);
    return _compiler.context.symbols[id];
  }

  List<Bytecode> lookupFunctionBytecodes(int id) {
    return lookupCompiledFunction(id).builder.bytecodes;
  }

  Iterable<int> lookupFunctionIdsByName(String name) {
    return _compiler.backend.functions
        .where((f) => f.name == name)
        .map((f) => f.methodId);
  }
}

// In this library to allow access to privates.
// TODO(lukechurch): Delete this class.
class Backdoor {
  final FletchCompiler _compiler;

  Backdoor(this._compiler);

  functionElementFromName(String name) =>
        _compiler._compiler.backend.compiledFunctions.keys.where(
            (f) => f.name == name).single;
  indexForFunctionElement(var element) =>
        _compiler._compiler.backend.allocateMethodId(element);
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

Uri _computeValidatedUri(
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
  // When running from fletch-repo, [_executable] is
  // ".../fletch-repo/fletch/out/$CONFIGURATION/dart", which means that the
  // fletch-repo root is 3th parent directory (due to how URI resolution works,
  // the filename ("dart") is removed before resolving, for example,
  // ".../fletch-repo/fletch/out/$CONFIGURATION/../../../" becomes
  // ".../fletch-repo/").
  Uri fletchRepoRoot = _executable.resolve('../../../');
  Uri guess = fletchRepoRoot.resolve('dart/sdk/');
  if (_looksLikeLibraryRoot(guess)) {
    return _resolveSymbolicLinks(guess);
  }
  guess = _executable.resolve('../');
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
  return Uri.base.resolveUri(new Uri.file(Platform.executable));
}

Uri _guessFletchVm() {
  for (String suggestion in _fletchVmSuggestions) {
    Uri guess = Uri.base.resolve(suggestion);
    if (_looksLikeFletchVm(guess)) {
      return _resolveSymbolicLinks(guess);
    }
  }
  return null;
}

bool _looksLikeFletchVm(Uri uri) {
  if (!new File.fromUri(uri).existsSync()) return false;
  String expectedFile = 'natives.json';
  return new File.fromUri(uri.resolve(expectedFile)).existsSync();
}
