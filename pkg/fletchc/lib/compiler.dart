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

import 'incremental/compiler.dart' show
    OutputProvider;

import 'package:compiler/src/source_file_provider.dart' show
    CompilerSourceFileProvider,
    FormattingDiagnosticHandler,
    SourceFileProvider;

import 'package:compiler/src/elements/elements.dart' show
    ClassElement,
    ConstructorElement,
    Element,
    FunctionElement;

import 'package:compiler/src/filenames.dart' show
    appendSlash;

import 'src/fletch_function_builder.dart' show
    FletchFunctionBuilder;

import 'src/debug_info.dart';

import 'src/fletch_native_descriptor.dart' show
    FletchNativeDescriptor;

import 'src/fletch_backend.dart' show
    FletchBackend;

import 'src/fletch_class_builder.dart' show
    FletchClassBuilder;

import 'package:compiler/src/apiimpl.dart' as apiimpl;

import 'src/fletch_compiler.dart' as implementation;

import 'bytecodes.dart' show
    Bytecode;

import 'fletch_system.dart';

import 'src/fletch_selector.dart';

const String _SDK_DIR = const String.fromEnvironment("dart-sdk");

const String _FLETCH_VM = const String.fromEnvironment("fletch-vm");

const String _PATCH_ROOT = const String.fromEnvironment("fletch-patch-root");

const List<String> _fletchVmSuggestions = const <String> [
    'out/DebugX64Clang/fletch-vm',
    'out/DebugX64/fletch-vm',
    'out/ReleaseX64Clang/fletch-vm',
    'out/ReleaseX64/fletch-vm',
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
       /// Location of fletch patch files.
       @StringOrUri patchRoot,
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
      handler = new FormattingDiagnosticHandler(sourceFileProvider)
          ..throwOnError = false
          ..verbose = isVerbose;
    }

    if (outputProvider == null) {
      outputProvider = new OutputProvider();
    }

    if (libraryRoot == null  && _SDK_DIR != null) {
      libraryRoot = Uri.base.resolve(appendSlash(_SDK_DIR));
    }
    libraryRoot = _computeValidatedUri(
        libraryRoot, name: 'libraryRoot', ensureTrailingSlash: true);
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

    if (fletchVm == null && _FLETCH_VM != null) {
      fletchVm = Uri.base.resolve(_FLETCH_VM);
    }
    if (fletchVm == null) {
      var path = _executable.resolve('fletch-vm');
      if (new File.fromUri(path).existsSync()) fletchVm = path;
    }
    fletchVm = _computeValidatedUri(
        fletchVm, name: 'fletchVm', ensureTrailingSlash: false);
    if (fletchVm == null) {
      fletchVm = _guessFletchVm();
      if (fletchVm == null) {
        throw new StateError("""
Unable to guess the location of the fletch VM (fletchVm).
Try adding command-line option '-Dfletch-vm=<path to fletch VM>.""");
      }
    } else if (!_looksLikeFletchVm(fletchVm)) {
      throw new ArgumentError("[fletchVm]: No fletch VM at '$fletchVm'.");
    }

    if (patchRoot == null  && _PATCH_ROOT != null) {
      patchRoot = Uri.base.resolve(appendSlash(_PATCH_ROOT));
    }
    patchRoot = _computeValidatedUri(
        patchRoot, name: 'patchRoot', ensureTrailingSlash: true);
    if (patchRoot == null) {
      patchRoot = _guessPatchRoot(libraryRoot);
      if (patchRoot == null) {
        throw new StateError("""
Unable to guess the location of the fletch patch files (patchRoot).
Try adding command-line option '-Dfletch-patch-root=<path to fletch patch>.""");
      }
    } else if (!_looksLikePatchRoot(patchRoot)) {
      throw new ArgumentError(
          "[patchRoot]: Fletch patches not found in '$patchRoot'.");
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
        patchRoot,
        options,
        environment,
        fletchVm);

    compiler.log("Using library root: $libraryRoot");
    compiler.log("Using package root: $packageRoot");

    var helper = new FletchCompiler._(compiler, script, isVerbose);
    compiler.helper = helper;
    return helper;
  }

  Future<FletchDelta> run([@StringOrUri script]) async {
    script = _computeValidatedUri(script, name: 'script');
    if (script == null) {
      script = this.script;
    }
    if (script == null) {
      throw new StateError("No [script] provided.");
    }
    await _inititalizeContext();
    FletchBackend backend = _compiler.backend;
    return _compiler.run(script).then((_) => backend.computeDelta());
  }

  Future _inititalizeContext() async {
    Uri nativesJson = _compiler.fletchVm.resolve("natives.json");
    var data = await _compiler.callUserProvider(nativesJson);
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
  }

  Uri get fletchVm => _compiler.fletchVm;

  String lookupFunctionName(FletchFunction function) {
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

  FletchClassBuilder lookupFletchClassBuilder(int classId) {
    FletchClassBuilder klass = _compiler.context.backend.classes[classId];
    assert(klass.classId == classId);
    return klass;
  }

  String lookupClassName(int classId) {
    FletchClassBuilder klass = lookupFletchClassBuilder(classId);
    if (klass.element != null) return klass.element.name;
    // TODO(ager): Provide better information for closures.
    if (_compiler.context.backend.closureClasses.values.contains(klass)) {
      return 'closure';
    }
    FletchFunctionBuilder function =
        _compiler.context.backend.functionBuilderFromTearoffClass(klass);
    if (function != null) return 'tearoff of ${function.name}';
    return 'unknown';
  }

  String lookupFieldName(int classId, int index) {
    FletchClassBuilder klass = lookupFletchClassBuilder(classId);
    return klass.fieldName(index);
  }

  String lookupFunctionNameBySelector(int selector) {
    int id = FletchSelector.decodeId(selector);
    return _compiler.context.symbols[id];
  }

  int mainMethodId() {
    FunctionElement mainFunctionElement = _compiler.mainFunction;
    FletchFunctionBuilder mainMethod =
        _compiler.context.backend.functionBuilders[mainFunctionElement];
    return mainMethod.methodId;
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

// Backdoor around Dart privacy. For now, certain components (in particular
// incremental compilation) need access to implementation details that shouldn't
// be part of the API of this file.
// TODO(ahe): Delete this class.
class Backdoor {
  final FletchCompiler _compiler;

  Backdoor(this._compiler);

  Future<implementation.FletchCompiler> get compilerImplementation async {
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

bool _containsFile(Uri uri, String expectedFile) {
  if (uri.scheme != 'file') return true;
  return new File.fromUri(uri.resolve(expectedFile)).existsSync();
}

bool _looksLikeLibraryRoot(Uri uri) {
  return _containsFile(uri, 'lib/_internal/libraries.dart');
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

Uri _guessPatchRoot(Uri libraryRoot) {
  Uri guess = libraryRoot.resolve('../../fletch/');
  if (_looksLikePatchRoot(guess)) return guess;
  return null;
}

bool _looksLikePatchRoot(Uri uri) {
  return _containsFile(uri, 'lib/core/core_patch.dart');
}
