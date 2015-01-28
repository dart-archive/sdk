// Copyright (c) 2014, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core;

// Matches dart:core on Jan 21, 2015.
abstract class String implements Comparable<String>, Pattern {
  factory String.fromCharCodes(Iterable<int> charCodes,
                               [int start = 0, int end]) {
    if (end == null) end = charCodes.length;
    int length = end - start;
    if (start < 0 || length < 0) throw new RangeError.range(start, 0, length);
    var str = _create(length);
    if (charCodes is List) {
      for (int i = 0; i < length; i++) {
        str._setCodeUnitAt(i, charCodes[start + i]);
      }
    } else {
      int i = -start;
      charCodes.forEach((value) {
        if (i >= 0 && i < length) str._setCodeUnitAt(i, value);
        i++;
      });
      if (i < length) throw new RangeError.range(start, 0, length);
    }
    return str;
  }

  factory String.fromCharCode(int charCode) {
    throw new UnimplementedError("String.fromCharCode");
  }

  // TODO(kasperl): We cannot express this.
  // const String.fromEnvironment(String name, {String defaultValue});

  int compareTo(String other) {
    int thisLength = this.length;
    int otherLength = other.length;
    int length = (thisLength < otherLength) ? thisLength : otherLength;
    for (int i = 0; i < length; i++) {
      int thisCodeUnit = this.codeUnitAt(i);
      int otherCodeUnit = other.codeUnitAt(i);
      if (thisCodeUnit < otherCodeUnit) return -1;
      if (thisCodeUnit > otherCodeUnit) return 1;
    }
    if (thisLength < otherLength) return -1;
    if (thisLength > otherLength) return 1;
    return 0;
  }

  Iterable<Match> allMatches(String string, [int start=0]) {
    throw new UnimplementedError("String.allMatches");
  }

  Match matchAsPrefix(String string, [int start=0]) {
    throw new UnimplementedError("String.matchAsPrefix");
  }

  String operator[](int index) {
    return _substring(index, index + 1);
  }

  int codeUnitAt(int index) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        throw new ArgumentError();
      case _indexOutOfBounds:
        throw new IndexError(index, this);
    }
  }

  int get length native;

  // TODO(kasperl): This is a really bad hash code.
  int get hashCode => length;

  bool operator ==(Object other) native;

  bool endsWith(String other) {
    throw new UnimplementedError("String.endsWith");
  }

  bool startsWith(Pattern pattern, [int index = 0]) {
    throw new UnimplementedError("String.startsWith");
  }

  int indexOf(Pattern pattern, [int start]) {
    throw new UnimplementedError("String.indexOf");
  }

  int lastIndexOf(Pattern pattern, [int start]) {
    throw new UnimplementedError("String.lastIndexOf");
  }

  bool get isEmpty => length == 0;

  bool get isNotEmpty => length > 0;

  String operator +(String other) native;

  String substring(int startIndex, [int endIndex]) {
    if (startIndex == null) startIndex == 0;
    if (endIndex == null) endIndex = length;
    return _substring(startIndex, endIndex);
  }

  String trim() {
    throw new UnimplementedError("String.trim");
  }

  String trimLeft() {
    throw new UnimplementedError("String.trimLeft");
  }

  String trimRight() {
    throw new UnimplementedError("String.trimRight");
  }

  String operator *(int times) {
    throw new UnimplementedError("String.*");
  }

  String padLeft(int width, [String padding = ' ']) {
    throw new UnimplementedError("String.padLeft");
  }

  String padRight(int width, [String padding = ' ']) {
    throw new UnimplementedError("String.padRight");
  }

  bool contains(Pattern other, [int startIndex = 0]) {
    throw new UnimplementedError("String.contains");
  }

  String replaceFirst(Pattern from, String to, [int startIndex = 0]) {
    throw new UnimplementedError("String.replaceFirst");
  }

  String replaceAll(Pattern from, String replace) {
    throw new UnimplementedError("String.replaceAll");
  }

  String replaceAllMapped(Pattern from, String replace(Match match)) {
    throw new UnimplementedError("String.replaceAllMapped");
  }

  List<String> split(Pattern pattern) {
    throw new UnimplementedError("String.split");
  }

  String splitMapJoin(Pattern pattern,
                      {String onMatch(Match match),
                       String onNonMatch(String nonMatch)}) {
    throw new UnimplementedError("String.splitMapJoin");
  }

  List<int> get codeUnits {
    throw new UnimplementedError("String.codeUnits");
  }

  Runes get runes {
    throw new UnimplementedError("String.runes");
  }

  String toLowerCase() {
    throw new UnimplementedError("String.toLowerCase");
  }

  String toUpperCase() {
    throw new UnimplementedError("String.toUpperCase");
  }

  String toString() => this;

  String _substring(int start, int end) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        throw new ArgumentError();
      case _indexOutOfBounds:
        throw new IndexError(start, this);
    }
  }

  String _setCodeUnitAt(int index, int value) native catch (error) {
    switch (error) {
      case _wrongArgumentType:
        throw new ArgumentError();
      case _indexOutOfBounds:
        throw new IndexError(index, this);
    }
  }

  static String _create(int length) native;
}

// Matches dart:core on Jan 21, 2015.
class StringBuffer implements StringSink {
  var _buffer;
  StringBuffer([this._buffer = ""]);

  int get length => _buffer.length;
  bool get isEmpty => _buffer.isEmpty;
  bool get isNotEmpty => _buffer.isNotEmpty;

  void write(Object obj) {
    _buffer += obj.toString();
  }

  void writeAll(Iterable objects, [String separator=""]) {
    throw new UnimplementedError("StringBuffer.writeAll");
  }

  void writeCharCode(int charCode) {
    throw new UnimplementedError("StringBuffer.writeCharCode");
  }

  void writeln([Object obj=""]) {
    write(obj);
    write("\n");
  }

  void clear() {
    _buffer = "";
  }

  String toString() => _buffer;
}
