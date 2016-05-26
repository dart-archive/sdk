// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library dartino_compiler.debug_info;

import 'dart:math' show
    min;

import 'package:compiler/src/colors.dart' as colors;

import 'package:compiler/src/diagnostics/source_span.dart' show
    SourceSpan;

import 'package:compiler/src/elements/elements.dart';

import 'package:compiler/src/io/source_file.dart';

import 'package:compiler/src/tree/tree.dart' show
    Node,
    unparse;

import 'package:compiler/src/source_file_provider.dart' show
    SourceFileProvider;

import 'codegen_visitor.dart';
import '../dartino_system.dart';
import 'hub/session_manager.dart' show
    SessionState;

import 'dartino_compiler_implementation.dart' show
    DartinoCompilerImplementation;

class ScopeInfo {
  static const ScopeInfo sentinel = const ScopeInfo(0, null, null);

  final int bytecodeIndex;
  final LocalValue local;
  final ScopeInfo previous;
  const ScopeInfo(this.bytecodeIndex, this.local, this.previous);

  LocalValue lookup(String name) {
    for (ScopeInfo current = this;
         current != sentinel;
         current = current.previous) {
      Element element = current.local.element;
      if (element == null && name == 'this') {
        return current.local;
      }
      if (element != null && element.name == name) {
        return current.local;
      }
    }
    return null;
  }

  String get name {
    return (local.element == null) ? 'this' : local.element.name;
  }
}

class SourceLocation {
  final int bytecodeIndex;
  final Node node;
  final SourceSpan span;
  final SourceFile file;
  SourceLocation(this.bytecodeIndex, this.node, this.span, this.file);

  bool contains(SourceLocation other) {
    return span.begin <= other.span.begin && other.span.end <= span.end;
  }

  bool containsPosition(int position) {
    return span.begin <= position && position <= span.end;
  }

  bool isSameSourceLevelLocationAs(SourceLocation other) {
    if (other == null) return false;
    if (file != other.file) return false;
    if (span == null || other.span == null) return span == other.span;
    return span.begin == other.span.begin && span.end == other.span.end;
  }

  String toString() {
    return "SourceLocation(${file.filename} "
        "bytecodeIndex: $bytecodeIndex ${span.begin}-${span.end})";
  }
}

class DebugInfo {
  final DartinoFunction function;
  final List<SourceLocation> locations = <SourceLocation>[];
  final List<ScopeInfo> scopeInfos = <ScopeInfo>[ScopeInfo.sentinel];

  DebugInfo(this.function);

  void addLocation(
      DartinoCompilerImplementation compiler,
      int bytecodeIndex,
      Node node) {
    SourceSpan span = compiler.reporter.spanFromSpannable(node);
    SourceFile file = null;
    // TODO(ahe): What to do if compiler.provider isn't a SourceFileProvider?
    // Perhaps we can create a new type of diagnostic, see
    // package:compiler/compiler.dart. The class Diagnostic is an "extensible"
    // enum class. This way, the debugger doesn't hold on to files.
    // Alternatively, source files should be obtained by iterating through the
    // compilation units.
    if (span != null && compiler.provider is SourceFileProvider) {
      SourceFileProvider provider = compiler.provider;
      Uri resourceUri = compiler.translateUri(span, span.uri);
      file = provider.sourceFiles[resourceUri];
    }
    locations.add(new SourceLocation(bytecodeIndex, node, span, file));
  }

  void pushScope(int bytecodeIndex, LocalValue local) {
    scopeInfos.add(new ScopeInfo(bytecodeIndex,
                                 local,
                                 scopeInfos.last));
  }

  void popScope(int bytecodeIndex) {
    ScopeInfo previous = scopeInfos.last.previous;
    scopeInfos.add(new ScopeInfo(bytecodeIndex,
                                 previous.local,
                                 previous.previous));
  }

  ScopeInfo scopeInfoFor(int bytecodeIndex) {
    return scopeInfos.lastWhere(
        (location) => location.bytecodeIndex <= bytecodeIndex,
        orElse: () => ScopeInfo.sentinel);
  }

  SourceLocation locationFor(int bytecodeIndex) {
    return locations.lastWhere(
        (location) => location.bytecodeIndex <= bytecodeIndex,
        orElse: () => null);
  }

  SourceLocation locationForPosition(int position) {
    SourceLocation current;
    bool foundContaining = false;

    for (SourceLocation location in locations) {
      if (location.span == null) continue;
      if (location.containsPosition(position)) {
        if (foundContaining) {
          if (current.contains(location)) current = location;
        } else {
          foundContaining = true;
          current = location;
        }
      } else if (!foundContaining) {
        current = current != null ? current : location;
        if (location.span.begin > position &&
            (current.span.begin > location.span.begin ||
             current.span.begin < position)) {
          current = location;
        }
      }
    }

    return current;
  }

  // TODO(ager): Should this be upstreamed to dart2js?
  String fileAndLineStringFor(int bytecodeIndex) {
    SourceLocation location = locationFor(bytecodeIndex);
    if (location == null) return '';
    SourceSpan span = location.span;
    if (span == null) return '';
    SourceFile file = location.file;
    if (file == null) return '';
    int currentLine = file.getLine(span.begin);
    int column = file.getColumn(currentLine, span.begin);
    return '${file.filename}:${currentLine + 1}:${column + 1}';
  }

  String astStringFor(int bytecodeIndex) {
    SourceLocation location = locationFor(bytecodeIndex);
    if (location == null || location.node == null) return null;
    return unparse(location.node, minify: false);
  }

  // TODO(ager): Should something like this be upstreamed to dart2js?
  String sourceListStringFor(
      int bytecodeIndex,
      {int contextLines: 5,
       bool colorsDisabled}) {
    SourceLocation location = locationFor(bytecodeIndex);
    if (location == null) return '';
    SourceSpan span = location.span;
    if (span == null) return '';
    SourceFile file = location.file;
    if (file == null) return '';

    int currentLine = file.getLine(span.begin);
    int column = file.getColumn(currentLine, span.begin);
    int startLine = currentLine - contextLines;
    if (startLine < 0) startLine = 0;
    StringBuffer buffer = new StringBuffer();

    buffer.writeln(fileAndLineStringFor(bytecodeIndex));

    // Add contextLines before the breakpoint line.
    for (; startLine < currentLine; startLine++) {
      var l = file.slowSubstring(file.lineStarts[startLine],
                                 file.lineStarts[startLine + 1]);
      buffer.write('${startLine + 1}'.padRight(5) + l);
    }

    // Add the breakpoint line highlighting the actual breakpoint location.
    var l = file.slowSubstring(
        file.lineStarts[currentLine],
        min(file.lineStarts[currentLine + 1], file.length));
    var toColumn = min(column + (span.end - span.begin), l.length);
    var prefix = l.substring(0, column);
    var focus = highlight(l.substring(column, toColumn), colors.red,
        colorsDisabled: colorsDisabled);
    var postfix = l.substring(toColumn);
    buffer.write('${currentLine + 1}'.padRight(5) + prefix);
    buffer.write(focus);
    buffer.write(postfix);

    // Add contextLines after the breakpoint line.
    int endLine = currentLine + contextLines;
    if (endLine > file.lineStarts.length - 3) {
      endLine = file.lineStarts.length - 3;
    }
    for (startLine = currentLine + 1; startLine <= endLine; startLine++) {
      var lineEnd = file.lineStarts[startLine + 1];
      // For last line remove the newline.
      if (startLine == endLine) --lineEnd;
      var l = file.slowSubstring(file.lineStarts[startLine], lineEnd);
      buffer.write('${startLine + 1}'.padRight(5) + l);
    }

    return buffer.toString();
  }

  String highlight(
      String message,
      Function color,
      {bool colorsDisabled}) {
    return colorsDisabled ? message : color(message);
  }

  SourceLocation sourceLocationFor(int bytecodeIndex) {
    return locationFor(bytecodeIndex);
  }
}
