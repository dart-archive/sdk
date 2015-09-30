// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_compiler_implementation;

import 'dart:async' show
    EventSink;

import 'package:sdk_library_metadata/libraries.dart' show
    libraries,
    LibraryInfo,
    shared,
    internal,
    Category;

import 'package:compiler/compiler_new.dart' as api;

import 'package:compiler/src/apiimpl.dart' as apiimpl;

import 'package:compiler/src/io/source_file.dart';

import 'package:compiler/src/source_file_provider.dart' show
    SourceFileProvider;

import 'package:compiler/src/elements/modelx.dart' show
    CompilationUnitElementX,
    LibraryElementX;

import 'package:compiler/compiler_new.dart' show
    CompilerOutput;

import 'package:compiler/src/util/uri_extras.dart' show
    relativize;

import 'package:compiler/src/dart2jslib.dart' show
    CodegenRegistry,
    Message,
    MessageKind,
    MessageTemplate;

import 'package:compiler/src/util/util.dart' show
    Spannable;

import 'fletch_registry.dart' show
    FletchRegistry;

import 'please_report_crash.dart' show
    crashReportRequested,
    requestBugReportOnCompilerCrashMessage;

import 'fletch_function_builder.dart';
import 'debug_info.dart';
import 'find_position_visitor.dart';
import 'fletch_context.dart';

import '../fletch_system.dart';

const EXTRA_DART2JS_OPTIONS = const <String>[
    // TODO(ahe): This doesn't completely disable type inference. Investigate.
    '--disable-type-inference',
    '--output-type=dart',
    // We want to continue generating code in the case of errors, to support
    // incremental fixes of erroneous code.
    '--generate-code-with-compile-time-errors',
];

const FLETCH_PATCHES = const <String, String>{
  "_internal": "internal/internal_patch.dart",
  "collection": "collection/collection_patch.dart",
  "convert": "convert/convert_patch.dart",
  "core": "core/core_patch.dart",
  "math": "math/math_patch.dart",
  "async": "async/async_patch.dart",
  "typed_data": "typed_data/typed_data_patch.dart",
};

const FLETCH_PLATFORM = 3;

const Map<String, LibraryInfo> FLETCH_LIBRARIES = const {
  "_fletch_system": const LibraryInfo(
      "system/system.dart",
      categories: internal,
      documented: false,
      platforms: FLETCH_PLATFORM),

  "fletch.ffi": const LibraryInfo(
      "ffi/ffi.dart",
      categories: shared,
      documented: false,
      platforms: FLETCH_PLATFORM),

  "fletch": const LibraryInfo(
      "fletch/fletch.dart",
      categories: shared,
      documented: false,
      platforms: FLETCH_PLATFORM),

  "fletch.io": const LibraryInfo(
      "io/io.dart",
      categories: shared,
      documented: false,
      platforms: FLETCH_PLATFORM),

  "system": const LibraryInfo(
      "io/system.dart",
      categories: internal,
      documented: false,
      platforms: FLETCH_PLATFORM),

  "service": const LibraryInfo(
      "service/service.dart",
      categories: shared,
      documented: false,
      platforms: FLETCH_PLATFORM),

  "fletch.os": const LibraryInfo(
      "os/os.dart",
      categories: shared,
      documented: false,
      platforms: FLETCH_PLATFORM),
};

class FletchCompilerImplementation extends apiimpl.Compiler {
  final Map<String, LibraryInfo> fletchLibraries = <String, LibraryInfo>{};

  final Uri fletchVm;

  /// Location of fletch patch files.
  final Uri patchRoot;

  Map<Uri, CompilationUnitElementX> compilationUnits;
  FletchContext internalContext;

  /// A reference to [../compiler.dart:FletchCompiler] used for testing.
  // TODO(ahe): Clean this up and remove this.
  var helper;

  FletchCompilerImplementation(
      api.CompilerInput provider,
      api.CompilerOutput outputProvider,
      api.CompilerDiagnostics handler,
      Uri libraryRoot,
      Uri packageConfig,
      this.patchRoot,
      List<String> options,
      Map<String, dynamic> environment,
      this.fletchVm)
      : super(
          provider, outputProvider, handler, libraryRoot, null,
          EXTRA_DART2JS_OPTIONS.toList()..addAll(options), environment,
          packageConfig, null, FletchBackend.newInstance) {
    CodegenRegistry global = globalDependencies;
    globalDependencies =
        new FletchRegistry(this, global.treeElements).asRegistry;
  }

  bool get showPackageWarnings => true;

  FletchContext get context {
    if (internalContext == null) {
      internalContext = new FletchContext(this);
    }
    return internalContext;
  }

  String fletchPatchLibraryFor(String name) => FLETCH_PATCHES[name];

  LibraryInfo lookupLibraryInfo(String name) {
    return fletchLibraries.putIfAbsent(name, () {
      // Let FLETCH_LIBRARIES shadow libraries.
      if (FLETCH_LIBRARIES.containsKey(name)) {
        return computeFletchLibraryInfo(name);
      }
      LibraryInfo info = libraries[name];
      if (info == null) {
        return computeFletchLibraryInfo(name);
      }
      return new LibraryInfo(
          info.path,
          categories: info.categories,
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
        libraryRoot, patchRoot.resolve("lib/${info.path}"), false);
    return new LibraryInfo(
        '../$path',
        categories: info.categories,
        implementation: info.implementation,
        documented: info.documented,
        maturity: info.maturity,
        platforms: info.platforms);
  }

  Uri resolvePatchUri(String dartLibraryPath) {
    String patchPath = lookupPatchPath(dartLibraryPath);
    if (patchPath == null) return null;
    return patchRoot.resolve(patchPath);
  }

  CompilationUnitElementX compilationUnitForUri(Uri uri) {
    if (compilationUnits == null) {
      compilationUnits = <Uri, CompilationUnitElementX>{};
      libraryLoader.libraries.forEach((LibraryElementX library) {
        for (CompilationUnitElementX unit in library.compilationUnits) {
          compilationUnits[unit.script.resourceUri] = unit;
        }
      });
    }
    return compilationUnits[uri];
  }

  DebugInfo debugInfoForPosition(
      String file,
      int position,
      FletchSystem currentSystem) {
    // TODO(ahe): [file] should be a Uri.
    Uri uri = Uri.base.resolve(file);
    CompilationUnitElementX unit = compilationUnitForUri(uri);
    if (unit == null) return null;
    FindPositionVisitor visitor = new FindPositionVisitor(position, unit);
    unit.accept(visitor, null);
    FletchFunctionBuilder builder =
        context.backend.systemBuilder.lookupFunctionBuilderByElement(
            visitor.element);
    if (builder == null) return null;
    // TODO(ajohnsen): We need a mapping from element to functionId, that can
    // be looked up in the current fletch system.
    FletchFunction function = builder.finalizeFunction(context, []);
    return context.backend.createDebugInfo(function, currentSystem);
  }

  int positionInFileFromPattern(String file, int line, String pattern) {
    // TODO(ahe): [file] should be a Uri.
    Uri uri = Uri.base.resolve(file);
    SourceFile sourceFile = getSourceFile(provider, uri);
    if (sourceFile == null) return null;
    List<int> lineStarts = sourceFile.lineStarts;
    if (line >= lineStarts.length) return null;
    int begin = lineStarts[line];
    int end = line + 2 < lineStarts.length
        ? lineStarts[line + 1]
        : sourceFile.length;
    String lineText = sourceFile.slowSubstring(begin, end);
    int column = lineText.indexOf(pattern);
    if (column == -1) return null;
    return begin + column;
  }

  int positionInFile(String file, int line, int column) {
    // TODO(ahe): [file] should be a Uri.
    Uri uri = Uri.base.resolve(file);
    SourceFile sourceFile = getSourceFile(provider, uri);
    if (sourceFile == null) return null;
    if (line >= sourceFile.lineStarts.length) return null;
    return sourceFile.lineStarts[line] + column;
  }

  void reportVerboseInfo(
      Spannable node,
      String message,
      {bool forceVerbose: false}) {
    // TODO(johnniwinther): Use super.reportVerboseInfo once added.
    if (forceVerbose || verbose) {
      MessageTemplate template = MessageTemplate.TEMPLATES[MessageKind.GENERIC];
      reportDiagnostic(
          node, template.message({'text': message}, true), api.Diagnostic.HINT);
    }
  }

  void pleaseReportCrash() {
    crashReportRequested = true;
    print(requestBugReportOnCompilerCrashMessage);
  }

  void reportError(
      Spannable node,
      MessageKind messageKind,
      [Map arguments = const {}]) {
    if (messageKind == MessageKind.MIRRORS_LIBRARY_NOT_SUPPORT_BY_BACKEND) {
      const String noMirrors =
          "Fletch doesn't support 'dart:mirrors'. See https://goo.gl/Kwrd0O";
      messageKind = MessageKind.GENERIC;
      arguments = {'text': noMirrors};
    }
    super.reportError(node, messageKind, arguments);
  }
}

/// Output provider which collects output in [output].
class OutputProvider implements CompilerOutput {
  final Map<String, String> output = new Map<String, String>();

  EventSink<String> createEventSink(String name, String extension) {
    return new StringEventSink((String data) {
      output['$name.$extension'] = data;
    });
  }

  String operator[](String key) => output[key];
}

/// Helper class to collect sources.
class StringEventSink implements EventSink<String> {
  List<String> data = <String>[];

  final Function onClose;

  StringEventSink(this.onClose);

  void add(String event) {
    if (data == null) throw 'StringEventSink is closed.';
    data.add(event);
  }

  void addError(errorEvent, [StackTrace stackTrace]) {
    throw 'addError($errorEvent, $stackTrace)';
  }

  void close() {
    if (data != null) {
      onClose(data.join());
      data = null;
    }
  }
}

SourceFile getSourceFile(api.CompilerInput provider, Uri uri) {
  if (provider is SourceFileProvider) {
    return provider.sourceFiles[uri];
  } else {
    return null;
  }
}
