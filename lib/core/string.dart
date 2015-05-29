// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core_patch;

class _StringImpl implements String {
  static const int _MAX_CODE_UNIT = 0xFFFF;
  static const int _LEAD_SURROGATE_OFFSET = (0xD800 - (0x10000 >> 10));
  static const int _MAX_CHAR_CODE = 0x10FFFF;

  factory _StringImpl.fromCharCodes(
      Iterable<int> charCodes,
      [int start = 0,
       int end]) {
    if (end == null) end = charCodes.length;
    int length = end - start;
    if (start < 0 || length < 0) throw new RangeError.range(start, 0, length);
    var str = _create(_stringLength(charCodes, start, length));
    int offset = 0;
    if (charCodes is List) {
      List list = charCodes;
      for (int i = 0; i < length; i++) {
        offset += _encodeCharCode(str, list[start + i], offset);
      }
    } else {
      int i = -start;
      charCodes.forEach((value) {
        if (i >= 0 && i < length) {
          offset += _encodeCharCode(str, value, offset);
        }
        i++;
      });
    }
    return str;
  }

  factory _StringImpl.fromCharCode(int charCode) {
    _StringImpl result = _create(_charCodeLength(charCode));
    _encodeCharCode(result, charCode, 0);
    return result;
  }

  static int _stringLength(Iterable<int> charCodes, int start, int length) {
    int stringLength = 0;
    if (charCodes is List) {
      List list = charCodes;
      for (int i = 0; i < length; i++) {
        stringLength += _charCodeLength(list[start + i]);
      }
    } else {
      int i = -start;
      charCodes.forEach((value) {
        if (i >= 0 && i < length) stringLength += _charCodeLength(value);
        i++;
      });
      if (i < length) throw new RangeError.range(start, 0, length);
    }
    return stringLength;
  }

  String toString() => this;

  @fletch.native external int get length;

  bool get isEmpty => length == 0;

  bool get isNotEmpty => length != 0;

  int get hashCode => identityHashCode(this);

  @fletch.native external bool operator ==(Object other);

  @fletch.native String operator +(String other) {
    throw new ArgumentError(other);
  }

  String substring(int startIndex, [int endIndex]) {
    if (startIndex == null) startIndex == 0;
    if (endIndex == null) endIndex = length;
    return _substring(startIndex, endIndex);
  }

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

  String operator[](int index) {
    return _substring(index, index + 1);
  }

  @fletch.native int codeUnitAt(int index) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        throw new ArgumentError();
      case fletch.indexOutOfBounds:
        throw new IndexError(index, this);
    }
  }

  String operator *(int times) {
    if (times <= 0) return "";
    if (times == 1) return this;
    int length = this.length;
    _StringImpl str = _create(length * times);
    for (int i = 0; i < times; i++) {
      int offset = i * length;
      for (int j = 0; j < length; j++) {
        str._setCodeUnitAt(offset + j, codeUnitAt(j));
      }
    }
    return str;
  }

  startsWith(Pattern pattern, [int index]) {
    if (pattern is! String) {
      throw new UnimplementedError(
          "String.startsWith only accepts String patterns");
    }
    String other = pattern;
    if (index == null) index = 0;
    int otherLength = other.length;
    if (index + otherLength > length) return false;
    for (int i = index; i < otherLength; i++) {
      if (codeUnitAt(index + i) != other.codeUnitAt(i)) return false;
    }
    return true;
  }

  bool endsWith(String other) {
    int otherLength = other.length;
    int offset = length - otherLength;
    if (offset < 0) return false;
    for (int i = 0; i < otherLength; i++) {
      if (codeUnitAt(offset + i) != other.codeUnitAt(i)) return false;
    }
    return true;
  }

  allMatches(string, [start]) {
    throw "allMatches(string, [start]) isn't implemented";
  }

  indexOf(pattern, [start]) {
    throw "indexOf(pattern, [start]) isn't implemented";
  }

  lastIndexOf(pattern, [start]) {
    throw "lastIndexOf(pattern, [start]) isn't implemented";
  }

  matchAsPrefix(string, [start]) {
    throw "matchAsPrefix(string, [start]) isn't implemented";
  }

  trim() {
    throw "trim() isn't implemented";
  }

  trimLeft() {
    throw "trimLeft() isn't implemented";
  }

  trimRight() {
    throw "trimRight() isn't implemented";
  }

  padLeft(width, [padding]) {
    throw "padLeft(width, [padding]) isn't implemented";
  }

  padRight(width, [padding]) {
    throw "padRight(width, [padding]) isn't implemented";
  }

  contains(other, [startIndex]) {
    throw "contains(other, [startIndex]) isn't implemented";
  }

  replaceFirst(from, to, [startIndex]) {
    throw "replaceFirst(from, to, [startIndex]) isn't implemented";
  }

  replaceFirstMapped(from, replace, [startIndex]) {
    throw "replaceFirstMapped(from, replace, [startIndex]) isn't implemented";
  }

  replaceAll(from, replace) {
    throw "replaceAll(from, replace) isn't implemented";
  }

  replaceAllMapped(from, replace) {
    throw "replaceAllMapped(from, replace) isn't implemented";
  }

  replaceRange(start, end, replacement) {
    throw "replaceRange(start, end, replacement) isn't implemented";
  }

  List<String> split(Pattern pattern) {
    if (pattern is! String) {
      throw new UnimplementedError("String.split only accepts String patterns");
    }
    String stringPattern = pattern;
    List<String> result = new List<String>();
    int length = this.length;

    // If the pattern is empty, split all characters.
    if (stringPattern.isEmpty) {
      for (int i = 0; i < length; i++) result.add(this[i]);
      return result;
    }

    // If the string is empty, return it in a list.
    if (length == 0) return [this];

    int patternLength = stringPattern.length;
    int startIndex = 0;
    int i = 0;
    int limit = length - patternLength + 1;
    while (i < limit) {
      bool match = true;
      for (int j = 0; j < patternLength; j++) {
        if (codeUnitAt(i + j) != stringPattern.codeUnitAt(j)) {
          match = false;
          break;
        }
      }
      if (match) {
        result.add(substring(startIndex, i));
        startIndex = i + patternLength;
        i += patternLength;
      } else {
        i++;
      }
    }
    result.add(substring(startIndex, length));
    return result;
  }

  splitMapJoin(pattern, {onMatch, onNonMatch}) {
    throw "splitMapJoin(pattern, {onMatch, onNonMatch}) isn't implemented";
  }

  get codeUnits {
    throw "get codeUnits isn't implemented";
  }

  get runes {
    throw "get runes isn't implemented";
  }

  toLowerCase() {
    throw "toLowerCase() isn't implemented";
  }

  toUpperCase() {
    throw "toUpperCase() isn't implemented";
  }

  static int _charCodeLength(int charCode) {
    return (charCode <= _MAX_CODE_UNIT) ? 1 : 2;
  }

  static int _encodeCharCode(_StringImpl char, int charCode, int offset) {
    if (charCode < 0 || charCode > _MAX_CHAR_CODE) {
      throw new ArgumentError(charCode);
    }
    int length = _charCodeLength(charCode);
    if (length == 2) {
      char._setCodeUnitAt(offset, _LEAD_SURROGATE_OFFSET + (charCode >> 10));
      char._setCodeUnitAt(offset + 1, (0xDC00 + (charCode & 0x3FF)));
    } else {
      char._setCodeUnitAt(offset, charCode);
    }
    return length;
  }

  @fletch.native String _substring(int start, int end) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        throw new ArgumentError();
      case fletch.indexOutOfBounds:
        throw new IndexError(start, this);
    }
  }

  @fletch.native void _setCodeUnitAt(int index, int char) {
    switch (fletch.nativeError) {
      case fletch.wrongArgumentType:
        throw new ArgumentError();
      case fletch.indexOutOfBounds:
        throw new IndexError(index, this);
    }
  }

  @fletch.native external static _StringImpl _create(int length);
}
