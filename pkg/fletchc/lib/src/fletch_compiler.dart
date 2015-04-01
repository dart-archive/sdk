// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_compiler;

import 'package:_internal/libraries.dart' show
    LIBRARIES,
    LibraryInfo;

import 'package:compiler/compiler.dart' as api;

import 'package:compiler/src/apiimpl.dart' as apiimpl;

import 'package:compiler/src/elements/modelx.dart' show
    LibraryElementX;

import 'package:compiler/src/util/uri_extras.dart' show
    relativize;

import 'fletch_context.dart';

part 'fletch_compiler_hack.dart';

const EXTRA_DART2JS_OPTIONS = const <String>[
    // TODO(ahe): This doesn't completely disable type inference. Investigate.
    '--disable-type-inference',
    '--output-type=dart',
];

const FLETCH_PATCHES = const <String, String>{
  "core": "core/core_patch.dart",
  "collection": "collection/collection_patch.dart",
  "typed_data": "typed_data/typed_data_patch.dart",
  "_internal": "internal/internal_patch.dart",
};

const FLETCH_PLATFORM = 3;

const Map<String, LibraryInfo> FLETCH_LIBRARIES = const {
  "_fletch_system": const LibraryInfo(
      "simple_system/system.dart",
      category: "Internal",
      documented: false,
      platforms: FLETCH_PLATFORM),

  // TODO(ahe): This library should be hidden from users: change category to
  // "Internal", and prefix name with "_".
  "fletch_natives": const LibraryInfo(
      "simple_system/fletch_natives.dart",
      category: "Shared",
      documented: false,
      platforms: FLETCH_PLATFORM),

  "ffi": const LibraryInfo(
      "ffi/ffi_fletchc.dart",
      category: "Shared",
      documented: false,
      platforms: FLETCH_PLATFORM),

  "service": const LibraryInfo(
      "service/service_fletchc.dart",
      category: "Shared",
      documented: false,
      platforms: FLETCH_PLATFORM),
};

class FletchCompiler extends FletchCompilerHack {
  final Map<String, LibraryInfo> fletchLibraries = <String, LibraryInfo>{};

  final Uri fletchVm;

  FletchContext internalContext;

  FletchCompiler(
      api.CompilerInputProvider provider,
      api.CompilerOutputProvider outputProvider,
      api.DiagnosticHandler handler,
      Uri libraryRoot,
      Uri packageRoot,
      List<String> options,
      Map<String, dynamic> environment,
      this.fletchVm)
      : super(
          provider, outputProvider, handler, libraryRoot, packageRoot,
          EXTRA_DART2JS_OPTIONS.toList()..addAll(options), environment);

  FletchContext get context {
    if (internalContext == null) {
      internalContext = new FletchContext(this);
    }
    return internalContext;
  }

  void onLibraryCreated(LibraryElementX library) {
    if (library.isPlatformLibrary &&
        Uri.parse('dart:fletch_natives') == library.canonicalUri) {
      // TODO(ahe): Remove this, no need to use native syntax, we can use:
      //   @native external nativeMethod();
      library.canUseNative = true;
    }
    super.onLibraryCreated(library);
  }

  String fletchPatchLibraryFor(String name) => FLETCH_PATCHES[name];

  LibraryInfo lookupLibraryInfo(String name) {
    return fletchLibraries.putIfAbsent(name, () {
      LibraryInfo info = LIBRARIES[name];
      if (info == null) {
        return computeFletchLibraryInfo(name);
      }
      return new LibraryInfo(
          info.path,
          category: info.category,
          dart2jsPath: info.dart2jsPath,
          dart2jsPatchPath: fletchPatchLibraryFor(name),
          implementation: info.implementation,
          documented: info.documented,
          maturity: info.maturity,
          platforms: info.platforms);
    });
  }

  LibraryInfo computeFletchLibraryInfo(String name) {
    LibraryInfo info = FLETCH_LIBRARIES[name];
    if (info == null) return null;
    // Since this LibraryInfo is completely internal to Fletch, there's no need
    // for dart2js extensions and patches.
    assert(info.dart2jsPath == null);
    assert(info.dart2jsPatchPath == null);
    String path = relativize(
        libraryRoot, Uri.base.resolve("lib/${info.path}"), false);
    return new LibraryInfo(
        '../$path',
        category: info.category,
        implementation: info.implementation,
        documented: info.documented,
        maturity: info.maturity,
        platforms: info.platforms);
  }

  Uri resolvePatchUri(String dartLibraryPath) {
    String patchPath = lookupPatchPath(dartLibraryPath);
    if (patchPath == null) return null;
    return Uri.base.resolve(patchPath);
  }

  bool inUserCode(element, {bool assumeInUserCode: false}) => true;
}
