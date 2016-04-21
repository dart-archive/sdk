// Copyright (c) 2016, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.dartino_diagnostic_reporter;

import 'package:compiler/src/tokens/token.dart' show
    Token;

import 'package:compiler/src/compiler.dart' show
    CompilerDiagnosticReporter;

import 'package:compiler/src/diagnostics/spannable.dart' show
    Spannable;

import 'package:compiler/src/diagnostics/source_span.dart' show
    SourceSpan;

import 'package:compiler/src/diagnostics/diagnostic_listener.dart' show
    DiagnosticMessage;

import 'dartino_compiler_implementation.dart' show
    DartinoCompilerImplementation;

import 'package:compiler/src/diagnostics/messages.dart' show
    Message, MessageKind, MessageTemplate;

import 'please_report_crash.dart' show
    crashReportRequested,
    requestBugReportOnCompilerCrashMessage;

import 'dartino_compiler_options.dart' show
    DartinoCompilerOptions;

final String padding = MessageTemplate.MIRRORS_NOT_SUPPORTED_BY_BACKEND_PADDING;

/// Messages that have a specialized message-text in Dartino.
final Map<MessageKind, MessageTemplate> dartinoTemplates =
  <MessageKind, MessageTemplate>{
    MessageKind.DISALLOWED_LIBRARY_IMPORT:
      new MessageTemplate(MessageKind.DISALLOWED_LIBRARY_IMPORT,
          "Your app imports the unsupported library '#{uri}' via:"
          "$padding#{importChain}."),
    MessageKind.LIBRARY_NOT_SUPPORTED:
      new MessageTemplate(MessageKind.LIBRARY_NOT_SUPPORTED,
          "Library'#{resolvedUri}' not supported on the current device.",
          howToFix: "Try removing the dependency or enable support by changing "
                    "the device_type in your '.dartino-settings' file."),
    MessageKind.MIRRORS_LIBRARY_NOT_SUPPORT_BY_BACKEND:
      new MessageTemplate(
          MessageKind.MIRRORS_LIBRARY_NOT_SUPPORT_BY_BACKEND, """
Dartino doesn't support 'dart:mirrors'. See https://goo.gl/Kwrd0O.

Your app imports dart:mirrors via:$padding#{importChain}""")
};

class DartinoDiagnosticReporter extends CompilerDiagnosticReporter {
  DartinoDiagnosticReporter(
      DartinoCompilerImplementation compiler,
      DartinoCompilerOptions options)
      : super(compiler, options);

  DartinoCompilerImplementation get compiler => super.compiler;

  DiagnosticMessage createMessage(
      Spannable spannable,
      MessageKind messageKind,
      [Map arguments = const {}]) {
    SourceSpan span = spanFromSpannable(spannable);
    // Note: Except for the following statement, this method is copied from
    // third_party/dart/pkg/compiler/lib/src/compiler.dart
    MessageTemplate template =
        dartinoTemplates[messageKind] ?? MessageTemplate.TEMPLATES[messageKind];
    Message message = template.message(arguments, options.terseDiagnostics);
    return new DiagnosticMessage(span, spannable, message);
  }

  @override
  SourceSpan spanFromTokens(Token begin, Token end, [Uri uri]) {
    // Note: Except for last line, this method is copied from
    // third_party/dart/pkg/compiler/lib/src/compiler.dart
    if (begin == null || end == null) {
      // TODO(ahe): We can almost always do better. Often it is only
      // end that is null. Otherwise, we probably know the current
      // URI.
      throw 'Cannot find tokens to produce error message.';
    }
    if (uri == null && currentElement != null) {
      uri = currentElement.compilationUnit.script.resourceUri;
    }
    return compiler.incrementalCompiler.createSourceSpan(
        begin, end, uri, currentElement);
  }

  @override
  void pleaseReportCrash() {
    if (crashReportRequested) return;
    crashReportRequested = true;
    print(requestBugReportOnCompilerCrashMessage);
  }

  static DartinoDiagnosticReporter createInstance(
      DartinoCompilerImplementation compiler,
      DartinoCompilerOptions options) {
    return new DartinoDiagnosticReporter(compiler, options);
  }
}
