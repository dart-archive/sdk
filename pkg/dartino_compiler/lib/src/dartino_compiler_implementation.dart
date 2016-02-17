// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_compiler_implementation;

import 'dart:async' show
    EventSink,
    Future;

import 'package:compiler/compiler_new.dart' as api;

import 'package:compiler/src/apiimpl.dart' show
    CompilerImpl,
    makeDiagnosticOptions;

import 'package:compiler/src/io/source_file.dart';

import 'package:compiler/src/source_file_provider.dart' show
    SourceFileProvider;

import 'package:compiler/src/library_loader.dart' show
    LibraryLoader;

import 'package:compiler/src/elements/modelx.dart' show
    CompilationUnitElementX,
    LibraryElementX;

import 'package:compiler/compiler_new.dart' show
    CompilerOutput;

import 'package:compiler/src/diagnostics/messages.dart' show
    Message,
    MessageKind,
    MessageTemplate;

import 'package:compiler/src/diagnostics/source_span.dart' show
    SourceSpan;

import 'package:compiler/src/diagnostics/diagnostic_listener.dart' show
    DiagnosticMessage,
    DiagnosticReporter;

import 'package:compiler/src/diagnostics/spannable.dart' show
    Spannable;

import 'dartino_function_builder.dart';
import 'debug_info.dart';
import 'find_position_visitor.dart';
import 'dartino_context.dart';

import 'dartino_enqueuer.dart' show
    DartinoEnqueueTask;

import '../dartino_system.dart';
import 'package:compiler/src/diagnostics/diagnostic_listener.dart';
import 'package:compiler/src/elements/elements.dart';

import '../incremental/dartino_compiler_incremental.dart' show
    IncrementalCompiler;

import 'dartino_diagnostic_reporter.dart' show
    DartinoDiagnosticReporter;

const EXTRA_DART2JS_OPTIONS = const <String>[
    // TODO(ahe): This doesn't completely disable type inference. Investigate.
    '--disable-type-inference',
    '--output-type=dart',
    // We want to continue generating code in the case of errors, to support
    // incremental fixes of erroneous code.
    '--generate-code-with-compile-time-errors',
];

const DARTINO_PATCHES = const <String, String>{
  "_internal": "internal/internal_patch.dart",
  "collection": "collection/collection_patch.dart",
  "convert": "convert/convert_patch.dart",
  "math": "math/math_patch.dart",
  "async": "async/async_patch.dart",
  "typed_data": "typed_data/typed_data_patch.dart",
};

const DARTINO_PLATFORM = 3;

DiagnosticOptions makeDartinoDiagnosticOptions(
    {bool suppressWarnings: false,
     bool fatalWarnings: false,
     bool suppressHints: false,
     bool terseDiagnostics: false,
     bool showPackageWarnings: true}) {
  return makeDiagnosticOptions(
      suppressWarnings: suppressWarnings,
      fatalWarnings: fatalWarnings,
      suppressHints: suppressHints,
      terseDiagnostics: terseDiagnostics,
      showPackageWarnings: true);
}

class DartinoCompilerImplementation extends CompilerImpl {
  final Uri dartinoVm;

  final Uri nativesJson;

  final IncrementalCompiler incrementalCompiler;

  Map<Uri, CompilationUnitElementX> compilationUnits;
  DartinoContext internalContext;

  /// A reference to [../compiler.dart:DartinoCompiler] used for testing.
  // TODO(ahe): Clean this up and remove this.
  var helper;

  @override
  DartinoEnqueueTask get enqueuer => super.enqueuer;

  DartinoCompilerImplementation(
      api.CompilerInput provider,
      api.CompilerOutput outputProvider,
      api.CompilerDiagnostics handler,
      Uri libraryRoot,
      Uri packageConfig,
      this.nativesJson,
      List<String> options,
      Map<String, dynamic> environment,
      this.dartinoVm,
      this.incrementalCompiler)
      : super(
          provider, outputProvider, handler, libraryRoot, null,
          EXTRA_DART2JS_OPTIONS.toList()..addAll(options), environment,
          packageConfig, null, DartinoBackend.createInstance,
          DartinoDiagnosticReporter.createInstance,
          makeDartinoDiagnosticOptions);

  DartinoContext get context {
    if (internalContext == null) {
      internalContext = new DartinoContext(this);
    }
    return internalContext;
  }

  String dartinoPatchLibraryFor(String name) {
    // TODO(sigurdm): Try to remove this special casing.
    if (name == "core") {
      return platformConfigUri.path.endsWith("dartino_embedded.platform")
          ? "core/embedded_core_patch.dart"
          : "core/core_patch.dart";
    }
    return DARTINO_PATCHES[name];
  }

  @override
  Uri resolvePatchUri(String dartLibraryPath) {
    String path = dartinoPatchLibraryFor(dartLibraryPath);
    if (path == null) return null;
    // Dartino patches are located relative to [libraryRoot].
    return libraryRoot.resolve(path);
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
      Uri file,
      int position,
      DartinoSystem currentSystem) {
    Uri uri = Uri.base.resolveUri(file);
    CompilationUnitElementX unit = compilationUnitForUri(uri);
    if (unit == null) return null;
    FindPositionVisitor visitor = new FindPositionVisitor(position, unit);
    unit.accept(visitor, null);
    DartinoFunction function = currentSystem.lookupFunctionByElement(
        visitor.element);
    if (function == null) return null;
    return context.backend.createDebugInfo(function, currentSystem);
  }

  int positionInFileFromPattern(Uri file, int line, String pattern) {
    Uri uri = Uri.base.resolveUri(file);
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

  int positionInFile(Uri file, int line, int column) {
    Uri uri = Uri.base.resolveUri(file);
    SourceFile sourceFile = getSourceFile(provider, uri);
    if (sourceFile == null) return null;
    if (line >= sourceFile.lineStarts.length) return null;
    return sourceFile.lineStarts[line] + column;
  }

  Iterable<Uri> findSourceFiles(Pattern pattern) {
    SourceFileProvider provider = this.provider;
    return provider.sourceFiles.keys.where((Uri uri) {
      return pattern.matchAsPrefix(uri.pathSegments.last) != null;
    });
  }

  void reportVerboseInfo(
      Spannable node,
      String messageText,
      {bool forceVerbose: false}) {
    // TODO(johnniwinther): Use super.reportVerboseInfo once added.
    if (forceVerbose || verbose) {
      MessageTemplate template = MessageTemplate.TEMPLATES[MessageKind.GENERIC];
      SourceSpan span = reporter.spanFromSpannable(node);
      Message message = template.message({'text': messageText});
      reportDiagnostic(new DiagnosticMessage(span, node, message),
          [], api.Diagnostic.HINT);
    }
  }

  @override
  void compileLoadedLibraries() {
    // TODO(ahe): Ensure dartinoSystemLibrary is not null
    // (also when mainApp is null).
    if (mainApp == null) {
      return;
    }
    super.compileLoadedLibraries();
  }

  @override
  Future onLibraryScanned(LibraryElement library, LibraryLoader loader) {
    Uri uri = library.canonicalUri;
    if (uri.path == "dartino._system") {
      patchAnnotationClass = library.find("_Patch");
    }
    return super.onLibraryScanned(library, loader);
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
    return provider.getSourceFile(uri);
  } else {
    return null;
  }
}
