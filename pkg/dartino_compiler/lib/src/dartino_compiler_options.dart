// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_compiler_options;

import 'dart:io' show
    File;

import 'package:compiler/src/options.dart' show
    CompilerOptions;

import 'package:compiler/compiler.dart' show
    PackagesDiscoveryProvider;

import 'guess_configuration.dart' show
    StringOrUri,
    computeValidatedUri,
    executable;

import 'package:compiler/src/filenames.dart' show
    appendSlash;

const String _UNDETERMINED_BUILD_ID = "build number could not be determined";

const String _LIBRARY_ROOT =
    const String.fromEnvironment("dartino_compiler-library-root");

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

class DartinoCompilerOptions implements CompilerOptions {
  @override final Uri libraryRoot;

  @override final Uri packageConfig;

  @override final Map<String, dynamic> environment;

  @override final bool analyzeAll;

  @override final bool analyzeMain;

  @override final bool analyzeOnly;

  @override final bool analyzeSignaturesOnly;

  @override final String buildId;

  @override final Uri platformConfigUri;

  @override final bool preserveUris;

  @override List<Uri> get resolutionInputs => null;
  @override Uri get resolutionOutput => null;
  @override bool get resolveOnly => false;

  @override final bool verbose;

  final Uri base;

  final IncrementalMode incrementalMode;

  DartinoCompilerOptions(
      this.libraryRoot,
      this.packageConfig,
      this.environment,
      this.analyzeAll,
      this.analyzeMain,
      this.analyzeOnly,
      this.analyzeSignaturesOnly,
      this.buildId,
      this.platformConfigUri,
      this.preserveUris,
      this.verbose,
      this.base,
      this.incrementalMode);

  @override bool get hasBuildId => buildId != _UNDETERMINED_BUILD_ID;

  @override Uri get entryPoint => _unsupported;

  @override Uri get packageRoot => null;

  @override PackagesDiscoveryProvider get packagesDiscoveryProvider => null;

  @override bool get allowMockCompilation => false;

  @override bool get allowNativeExtensions => false;

  @override Uri get deferredMapUri => null;

  @override bool get disableInlining => true;

  @override bool get disableTypeInference => true;

  @override bool get dumpInfo => false;

  @override bool get enableAssertMessage => false;

  @override bool get enableExperimentalMirrors => false;

  @override bool get enableMinification => false;

  @override bool get enableNativeLiveTypeAnalysis => false;

  @override bool get enableTypeAssertions => false;

  @override bool get enableUserAssertions => false;

  @override bool get generateCodeWithCompileTimeErrors => true;

  @override bool get generateSourceMap => false;

  @override bool get hasIncrementalSupport => true;

  @override Uri get outputUri => null;

  @override Uri get sourceMapUri => _unsupported;

  @override bool get testMode => false;

  @override bool get trustJSInteropTypeAnnotations => false;

  @override bool get trustPrimitives => false;

  @override bool get trustTypeAnnotations => false;

  @override bool get useContentSecurityPolicy => false;

  @override bool get useCpsIr => false;

  @override bool get useFrequencyNamer => false;

  @override bool get useNewSourceInfo => false;

  @override bool get useStartupEmitter => false;

  @override bool get preserveComments => false;

  @override bool get emitJavaScript => _unsupported;

  @override bool get dart2dartMultiFile => _unsupported;

  @override List<String> get strips => _unsupported;

  @override bool get enableGenericMethodSyntax => false;

  @override bool get fatalWarnings => false;

  @override bool get terseDiagnostics => false;

  @override bool get suppressWarnings => false;

  @override bool get suppressHints => false;

  @override bool get showAllPackageWarnings => true;

  @override bool get hidePackageWarnings => false;

  @override bool showPackageWarningsFor(Uri uri) => true;

  @override bool get enableInitializingFormalAccess => false;

  static DartinoCompilerOptions copy(
      CompilerOptions options,
      {Uri libraryRoot,
       Uri packageConfig,
       Map<String, dynamic> environment,
       bool analyzeAll,
       bool analyzeMain,
       bool analyzeOnly,
       bool analyzeSignaturesOnly,
       String buildId,
       Uri platformConfigUri,
       bool preserveUris,
       bool verbose,
       Uri base,
       IncrementalMode incrementalMode}) {
    return new DartinoCompilerOptions(
        libraryRoot ?? options.libraryRoot,
        packageConfig ?? options.packageConfig,
        environment ?? options.environment,
        analyzeAll ?? options.analyzeAll,
        analyzeMain ?? options.analyzeMain,
        analyzeOnly ?? options.analyzeOnly,
        analyzeSignaturesOnly ?? options.analyzeSignaturesOnly,
        buildId ?? options.buildId,
        platformConfigUri ?? options.platformConfigUri,
        preserveUris ?? options.preserveUris,
        verbose ?? options.verbose,
        base ?? Uri.base,
        incrementalMode ?? IncrementalMode.none);
  }

  static DartinoCompilerOptions parse(
      List<String> arguments,
      Uri base,
      {@StringOrUri script,
       @StringOrUri libraryRoot,
       @StringOrUri packageConfig,
       String platform,
       Map<String, dynamic> environment,
       IncrementalMode incrementalMode}) {

    if (base == null) {
      throw new ArgumentError("[base] is null");
    }
    if (platform == null) {
      throw new ArgumentError("[platform] is null");
    }

    if (script != null) {
      script = computeValidatedUri(script, name: 'script', base: base);
    }

    if (libraryRoot == null && _LIBRARY_ROOT != null) {
      libraryRoot = executable.resolve(appendSlash(_LIBRARY_ROOT));
    }
    libraryRoot = computeValidatedUri(
        libraryRoot, name: 'libraryRoot', ensureTrailingSlash: true,
        base: base);
    if (libraryRoot == null) {
      libraryRoot = _guessLibraryRoot(platform);
      if (libraryRoot == null) {
        throw new StateError("""
Unable to guess the location of the Dart SDK (libraryRoot).
Try adding command-line option '-Ddart-sdk=<location of the Dart sdk>'.""");
      }
    } else if (!_looksLikeLibraryRoot(libraryRoot, platform)) {
      throw new ArgumentError(
          "[libraryRoot]: Dart SDK library not found in '$libraryRoot'.");
    }

    packageConfig = computeValidatedUri(
        packageConfig, name: 'packageConfig', base: base);
    if (packageConfig == null) {
      if (script != null) {
        packageConfig = script.resolve('.packages');
      } else {
        packageConfig = base.resolve('.packages');
      }
    }

    if (environment == null) {
      environment = <String, dynamic>{};
    }

    Uri platformConfigUri =
        computeValidatedUri(platform, name: 'platform', base: libraryRoot);

    CompilerOptions options = new CompilerOptions.parse(
        entryPoint: null,
        libraryRoot: libraryRoot,
        packageRoot: null,
        packageConfig: packageConfig,
        packagesDiscoveryProvider: null,
        environment: environment,
        options: arguments);

    return copy(
        options, platformConfigUri: platformConfigUri,
        incrementalMode: incrementalMode);
  }
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

get _unsupported => throw "not supported";

Uri _guessLibraryRoot(String platform) {
  // When running from dartino, [executable] is
  // ".../dartino-repo/sdk/out/$CONFIGURATION/dart", which means that the
  // dartino root is the lib directory in the 2th parent directory (due to
  // how URI resolution works, the filename ("dart") is removed before
  // resolving, for example,
  // ".../dartino-repo/sdk/out/$CONFIGURATION/../../" becomes
  // ".../dartino-repo/sdk/").
  Uri guess = executable.resolve('../../lib/');
  if (_looksLikeLibraryRoot(guess, platform)) return guess;
  return null;
}

bool _looksLikeLibraryRoot(Uri uri, String platform) {
  return _containsFile(uri, platform);
}

bool _containsFile(Uri uri, String expectedFile) {
  if (uri.scheme != 'file') return true;
  return new File.fromUri(uri.resolve(expectedFile)).existsSync();
}
