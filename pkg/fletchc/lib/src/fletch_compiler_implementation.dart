// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_compiler_implementation;

import 'dart:async' show
    EventSink;

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

import 'please_report_crash.dart' show
    crashReportRequested,
    requestBugReportOnCompilerCrashMessage;

import 'fletch_function_builder.dart';
import 'debug_info.dart';
import 'find_position_visitor.dart';
import 'fletch_context.dart';

import 'fletch_enqueuer.dart' show
    FletchEnqueueTask;

import '../fletch_system.dart';
import 'package:compiler/src/diagnostics/diagnostic_listener.dart';
import 'package:compiler/src/elements/elements.dart';

const EXTRA_DART2JS_OPTIONS = const <String>[
    '--show-package-warnings',
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

class FletchCompilerImplementation extends apiimpl.CompilerImpl {
  final Uri fletchVm;

  final Uri nativesJson;

  Map<Uri, CompilationUnitElementX> compilationUnits;
  FletchContext internalContext;

  /// A reference to [../compiler.dart:FletchCompiler] used for testing.
  // TODO(ahe): Clean this up and remove this.
  var helper;

  @override
  FletchEnqueueTask get enqueuer => super.enqueuer;

  FletchDiagnosticReporter reporter;

  FletchCompilerImplementation(
      api.CompilerInput provider,
      api.CompilerOutput outputProvider,
      api.CompilerDiagnostics handler,
      Uri libraryRoot,
      Uri packageConfig,
      this.nativesJson,
      List<String> options,
      Map<String, dynamic> environment,
      this.fletchVm)
      : super(
          provider, outputProvider, handler, libraryRoot, null,
          EXTRA_DART2JS_OPTIONS.toList()..addAll(options), environment,
          packageConfig, null, FletchBackend.newInstance) {
    reporter = new FletchDiagnosticReporter(super.reporter);
  }

  bool get showPackageWarnings => true;

  FletchContext get context {
    if (internalContext == null) {
      internalContext = new FletchContext(this);
    }
    return internalContext;
  }

  String fletchPatchLibraryFor(String name) => FLETCH_PATCHES[name];

  Uri resolvePatchUri(String dartLibraryPath) {
    String path = fletchPatchLibraryFor(dartLibraryPath);
    if (path == null) return null;
    // Fletch patches are located relative to [libraryRoot].
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
      FletchSystem currentSystem) {
    Uri uri = Uri.base.resolveUri(file);
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

  void pleaseReportCrash() {
    if (crashReportRequested) return;
    crashReportRequested = true;
    print(requestBugReportOnCompilerCrashMessage);
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

/// A wrapper around a DiagnosticReporter, that customizes some messages to
/// Fletch.
class FletchDiagnosticReporter extends DiagnosticReporter {
  DiagnosticReporter _internalReporter;

  FletchDiagnosticReporter(this._internalReporter);

  @override
  DiagnosticMessage createMessage(Spannable spannable,
      MessageKind messageKind,
      [Map arguments = const {}]) {
    return _internalReporter.createMessage(spannable, messageKind, arguments);
  }

  @override
  internalError(Spannable spannable, message) {
    return _internalReporter.internalError(spannable, message);
  }

  @override
  void log(message) {
    _internalReporter.log(message);
  }

  @override
  DiagnosticOptions get options => _internalReporter.options;

  @override
  void reportError(DiagnosticMessage message,
      [List<DiagnosticMessage> infos = const <DiagnosticMessage> []]) {
    if (message.message.kind ==
        MessageKind.MIRRORS_LIBRARY_NOT_SUPPORT_BY_BACKEND) {
      const String noMirrors =
          "Fletch doesn't support 'dart:mirrors'. See https://goo.gl/Kwrd0O";
      message = createMessage(message.spannable,
          MessageKind.GENERIC,
          {'text': message});
    }
    _internalReporter.reportError(message, infos);
  }

  @override
  void reportHint(DiagnosticMessage message,
      [List<DiagnosticMessage> infos = const <DiagnosticMessage> []]) {
    _internalReporter.reportHint(message, infos);
  }

  @override
  void reportInfo(Spannable node,
      MessageKind errorCode,
      [Map arguments = const {}]) {
    _internalReporter.reportInfo(node, errorCode, arguments);
  }

  @override
  void reportWarning(DiagnosticMessage message,
      [List<DiagnosticMessage> infos = const <DiagnosticMessage> []]) {
    _internalReporter.reportWarning(message, infos);
  }

  @override
  SourceSpan spanFromSpannable(Spannable node) {
    return _internalReporter.spanFromSpannable(node);
  }

  @override
  withCurrentElement(Element element, f()) {
    return _internalReporter.withCurrentElement(element, f);
  }
}