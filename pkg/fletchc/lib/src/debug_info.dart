// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

library fletchc.debug_info;

import 'dart:math' show
    min;

import 'package:compiler/src/colors.dart' as colors;

import 'package:compiler/src/dart2jslib.dart' show
    SourceSpan;


import 'package:compiler/src/io/source_file.dart';

import 'package:compiler/src/tree/tree.dart' show
    Node;

import 'fletch_compiler.dart' show
    FletchCompiler;

class SourceLocation {
  final int bytecodeIndex;
  final Node node;
  final SourceSpan span;
  final SourceFile file;
  SourceLocation(this.bytecodeIndex, this.node, this.span, this.file);
}

class DebugInfo {
  List<SourceLocation> locations = new List();

  void add(FletchCompiler compiler, int bytecodeIndex, Node node) {
    SourceSpan span = compiler.spanFromSpannable(node);
    SourceFile file = span != null
        ? compiler.provider.sourceFiles[span.uri]
        : null;
    locations.add(new SourceLocation(bytecodeIndex, node, span, file));
  }

  SourceLocation locationFor(int bytecodeIndex) {
    try {
      var location = locations.lastWhere(
          (location) => location.bytecodeIndex <= bytecodeIndex);
      return location;
    } catch (e) {
      return null;
    }
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
    if (location == null) return null;
    return '${location.node}';
  }

  // TODO(ager): Should something like this be upstreamed to dart2js?
  String sourceListStringFor(int bytecodeIndex, int contextLines) {
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
    int endLine = currentLine + contextLines;
    if (endLine >= file.lineStarts.length) endLine = file.lineStarts.length - 1;

    StringBuffer buffer = new StringBuffer();

    // Add contextLines lines before the breakpoint line.
    for (; startLine < currentLine; startLine++) {
      var l = file.slowSubstring(file.lineStarts[startLine],
                                 file.lineStarts[startLine + 1]);
      buffer.write('$startLine'.padRight(5) + l);
    }

    // Add the breakpoint line highlighting the actual breakpoint location.
    var l = file.slowSubstring(file.lineStarts[currentLine],
                               file.lineStarts[currentLine + 1]);
    var toColumn = min(column + (span.end - span.begin), l.length);
    var prefix = l.substring(0, column);
    var focus = l.substring(column, toColumn);
    var postfix = l.substring(toColumn);
    buffer.write('$currentLine'.padRight(5) + prefix);
    buffer.write(colors.red(focus));
    buffer.write(postfix);

    // Add contextLines lines before the breakpoint line.
    for (startLine = currentLine + 1; startLine < endLine; startLine++) {
      var lineEnd = file.lineStarts[startLine + 1];
      if (lineEnd >= file.length) --lineEnd;
      var l = file.slowSubstring(file.lineStarts[startLine], lineEnd);
      buffer.write('$startLine'.padRight(5) + l);
    }

    return buffer.toString();
  }

  SourceLocation sourceLocationFor(int bytecodeIndex) {
    return locationFor(bytecodeIndex);
  }
}
