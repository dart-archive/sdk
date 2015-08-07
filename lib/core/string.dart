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
      throw new ArgumentError(
          "String.startsWith only accepts String patterns for now");
    }
    String other = pattern;
    if (index == null) index = 0;
    int otherLength = other.length;
    if (index + otherLength > length) return false;
    for (int i = 0; i < otherLength; i++) {
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

  int indexOf(Pattern pattern, [int start]) {
    if (pattern is! String) {
      throw new ArgumentError(
          "String.indexOf only accepts String patterns for now");
    }
    String str = pattern;
    int length = this.length;
    if (start == null) start = 0;
    if (str.isEmpty) return start;
    // TODO(ajohnsen): Inline the other loop.
    for (int i = start; i < length; i++) {
      if (startsWith(pattern, i)) return i;
    }
    return -1;
  }

  int lastIndexOf(Pattern pattern, [int start]) {
    if (pattern is! String) {
      throw new ArgumentError(
          "String.lastIndexOf only accepts String patterns for now");
    }
    int length = this.length;
    if (start == null) start = length;
    // TODO(ajohnsen): Inline the other looping.
    for (int i = start; i >= 0; i--) {
      if (startsWith(pattern, i)) return i;
    }
    return -1;
  }

  allMatches(string, [start]) {
    throw "allMatches(string, [start]) isn't implemented";
  }

  matchAsPrefix(string, [start]) {
    throw "matchAsPrefix(string, [start]) isn't implemented";
  }

  // Characters with Whitespace property (Unicode 6.2).
  // 0009..000D    ; White_Space # Cc       <control-0009>..<control-000D>
  // 0020          ; White_Space # Zs       SPACE
  // 0085          ; White_Space # Cc       <control-0085>
  // 00A0          ; White_Space # Zs       NO-BREAK SPACE
  // 1680          ; White_Space # Zs       OGHAM SPACE MARK
  // 180E          ; White_Space # Zs       MONGOLIAN VOWEL SEPARATOR
  // 2000..200A    ; White_Space # Zs       EN QUAD..HAIR SPACE
  // 2028          ; White_Space # Zl       LINE SEPARATOR
  // 2029          ; White_Space # Zp       PARAGRAPH SEPARATOR
  // 202F          ; White_Space # Zs       NARROW NO-BREAK SPACE
  // 205F          ; White_Space # Zs       MEDIUM MATHEMATICAL SPACE
  // 3000          ; White_Space # Zs       IDEOGRAPHIC SPACE
  //
  // BOM: 0xFEFF
  static bool _isWhitespace(int codeUnit) {
    if (codeUnit <= 32) {
      return (codeUnit == 32) ||
             ((codeUnit <= 13) && (codeUnit >= 9));
    }
    if (codeUnit < 0x85) return false;
    if ((codeUnit == 0x85) || (codeUnit == 0xA0)) return true;
    return (codeUnit <= 0x200A)
            ? ((codeUnit == 0x1680) ||
               (codeUnit == 0x180E) ||
               (0x2000 <= codeUnit))
            : ((codeUnit == 0x2028) ||
               (codeUnit == 0x2029) ||
               (codeUnit == 0x202F) ||
               (codeUnit == 0x205F) ||
               (codeUnit == 0x3000) ||
               (codeUnit == 0xFEFF));
  }

  String trim() {
    int length = this.length;
    int end = length - 1;
    int start = 0;
    while (end >= 0 && _isWhitespace(codeUnitAt(end))) end--;
    while (start < end && _isWhitespace(codeUnitAt(start))) start++;
    end++;
    if (start == 0 && end == length) return this;
    return substring(start, end);
  }

  String trimLeft() {
    int length = this.length;
    int i = 0;
    while (i < length && _isWhitespace(codeUnitAt(i))) i++;
    if (i == 0) return this;
    return substring(i);
  }

  String trimRight() {
    int end = this.length - 1;
    int i = end;
    while (i >= 0 && _isWhitespace(codeUnitAt(i))) i--;
    if (i == end) return this;
    return substring(0, i + 1);
  }

  padLeft(width, [padding]) {
    throw "padLeft(width, [padding]) isn't implemented";
  }

  padRight(width, [padding]) {
    throw "padRight(width, [padding]) isn't implemented";
  }

  bool contains(Pattern other, [int startIndex]) {
    return indexOf(other, startIndex) >= 0;
  }

  replaceFirst(from, to, [startIndex]) {
    throw "replaceFirst(from, to, [startIndex]) isn't implemented";
  }

  replaceFirstMapped(from, replace, [startIndex]) {
    throw "replaceFirstMapped(from, replace, [startIndex]) isn't implemented";
  }

  String replaceAll(Pattern from, String replace) {
    if (from is! String) {
      throw new ArgumentError(
          "String.replaceAll only accepts String patterns for now");
    }
    String str = from;
    StringBuffer buffer = new StringBuffer();
    int length = this.length;
    if (str.isEmpty) {
      // Special case the empty string.
      buffer.write(replace);
      for (int i = 0; i < length; i++) {
        buffer.write(this[i]);
        buffer.write(replace);
      }
      return buffer.toString();
    }
    int offset = 0;
    while(true) {
      int index = indexOf(str, offset);
      if (index < 0) {
        buffer.write(substring(offset));
        return buffer.toString();
      }
      buffer.write(substring(offset, index));
      buffer.write(replace);
      offset = index + str.length;
    }
  }

  replaceAllMapped(from, replace) {
    throw "replaceAllMapped(from, replace) isn't implemented";
  }

  String replaceRange(int start, int end, String replacement) {
    if (end == null) end = length;
    // TODO(ajohnsen): Optimize.
    return substring(0, start) + replacement + substring(end);
  }

  List<String> split(Pattern pattern) {
    if (pattern is! String) {
      throw new ArgumentError(
          "String.split only accepts String patterns for now");
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

  List<int> get codeUnits => new CodeUnits(this);

  Runes get runes => new Runes(this);

  String toLowerCase() => internalToLowerCase(this);

  String toUpperCase() => internalToUpperCase(this);

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
