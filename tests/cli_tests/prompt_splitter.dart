// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Modified version of LineSplitter.dart

import 'dart:convert' show
    Converter,
    StringConversionSink,
    StringConversionSinkBase;

// Character constants.
const int _LF = 10;
const int _CR = 13;
const int _GT = 62;
const int _SPACE = 32;

// TODO(zerny): This will match a '> ' delimiter at any position (ie, also at
// positions that are not the start of a line). We need to do so since the line
// break before a prompt is inserted on stdin and not on stdout.
bool isPrompt(String content, int index) {
  return content.codeUnitAt(index) == _GT
      && content.codeUnitAt(index + 1) == _SPACE;
}

/**
 * A [Converter] that splits a [String] into individual prompt-delimited lines.
 *
 * A prompt-delimeter is the sequence '> '.
 *
 * The returned lines are trimmed and do not contain the delimiters.
 */
class PromptSplitter extends Converter<String, List<String>> {

  const PromptSplitter();

  /// Split [lines] into individual lines.
  ///
  /// If [start] and [end] are provided, only split the contents of
  /// `lines.substring(start, end)`. The [start] and [end] values must
  /// specify a valid sub-range of [lines]
  /// (`0 <= start <= end <= lines.length`).
  static Iterable<String> split(String lines, [int start = 0, int end]) sync* {
    end = RangeError.checkValidRange(start, end, lines.length);
    int sliceStart = start;
    for (int i = start; i < end - 1; i++) {
      if (isPrompt(lines, i)) {
        yield lines.substring(sliceStart, i);
        sliceStart = i + 2;
      }
    }
    if (sliceStart < end) {
      yield lines.substring(sliceStart, end);
    }
  }

  List<String> convert(String data) => split(data).toList();

  StringConversionSink startChunkedConversion(Sink<String> sink) {
    if (sink is! StringConversionSink) {
      sink = new StringConversionSink.from(sink);
    }
    return new _PromptSplitterSink(sink);
  }
}

// TODO(floitsch): deal with utf8.
class _PromptSplitterSink extends StringConversionSinkBase {
  final StringConversionSink _sink;

  /// The carry-over from the previous chunk.
  ///
  /// If the previous slice ended in a line without a delimiter,
  /// then the next slice may continue the line.
  String _carry;

  _PromptSplitterSink(this._sink);

  void addSlice(String chunk, int start, int end, bool isLast) {
    end = RangeError.checkValidRange(start, end, chunk.length);
    // If the chunk is empty, it's probably because it's the last one.
    // Handle that here, so we know the range is non-empty below.
    if (start >= end) {
      if (isLast) close();
      return;
    }
    if (_carry != null) {
      chunk = _carry + chunk.substring(start, end);
      start = 0;
      end = chunk.length;
      _carry = null;
    }
    _addLines(chunk, start, end);
    if (isLast) close();
  }

  void close() {
    if (_carry != null) {
      _sink.add(_carry);
      _carry = null;
    }
    _sink.close();
  }

  void _addLines(String lines, int start, int end) {
    int sliceStart = start;
    for (int i = start; i < end - 1; i++) {
      if (isPrompt(lines, i)) {
        _sink.add(lines.substring(sliceStart, i).trim());
        sliceStart = i + 2;
      }
    }
    if (sliceStart < end) {
      _carry = lines.substring(sliceStart, end);
    }
  }
}