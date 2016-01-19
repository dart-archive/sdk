// Copyright (c) 2016, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.fletch_diagnostic_reporter;

import 'package:compiler/src/tokens/token.dart' show
    Token;

import 'package:compiler/src/compiler.dart' show
    CompilerDiagnosticReporter;

import 'package:compiler/src/diagnostics/diagnostic_listener.dart' show
    DiagnosticOptions;

import 'package:compiler/src/diagnostics/source_span.dart' show
    SourceSpan;

import 'package:compiler/src/diagnostics/diagnostic_listener.dart' show
    DiagnosticMessage;

import 'fletch_compiler_implementation.dart' show
    FletchCompilerImplementation;

import 'package:compiler/src/diagnostics/messages.dart' show
    MessageKind;

class FletchDiagnosticReporter extends CompilerDiagnosticReporter {
  FletchDiagnosticReporter(
      FletchCompilerImplementation compiler,
      DiagnosticOptions options)
      : super(compiler, options);

  FletchCompilerImplementation get compiler => super.compiler;

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
    super.reportError(message, infos);
  }

  static FletchDiagnosticReporter createInstance(
      FletchCompilerImplementation compiler,
      DiagnosticOptions options) {
    return new FletchDiagnosticReporter(compiler, options);
  }
}
