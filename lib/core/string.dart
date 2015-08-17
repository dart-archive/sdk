// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

part of dart.core_patch;

class StringMatch implements Match {
  final int start;
  final String input;
  final String pattern;

  const StringMatch(this.start, this.input, this.pattern);

  int get end => start + pattern.length;
  String operator[](int g) => group(g);
  int get groupCount => 0;

  String group(int group) {
    if (group != 0) {
      throw new RangeError.value(group);
    }
    return pattern;
  }

  List<String> groups(List<int> groups) {
    List<String> result = new List<String>();
    for (int g in groups) {
      result.add(group(g));
    }
    return result;
  }
}

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

  bool startsWith(Pattern pattern, [int index = 0]) {
    return pattern.matchAsPrefix(this, index) != null;
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

  int indexOf(Pattern pattern, [int start = 0]) {
    if ((start < 0) || (start > this.length)) {
      throw new RangeError.range(start, 0, this.length);
    }

    if (pattern is! String) {
      Iterator<Match> iterator = pattern.allMatches(this, start).iterator;
      if (iterator.moveNext()) return iterator.current.start;
      return -1;
    }
    // For string, allMatches is implemented using indexOf, so we need a real
    // implementation here.
    String str = pattern;
    int length = this.length;
    if (str.isEmpty) return start;
    // TODO(ajohnsen): Inline the other loop.
    for (int i = start; i < length; i++) {
      if (startsWith(str, i)) return i;
    }
    return -1;
  }

  int lastIndexOf(Pattern pattern, [int start = null]) {
    int length = this.length;
    if (start == null) {
      start = length;
    } else if (start < 0 || start > length) {
      throw new RangeError.range(start, 0, length);
    }
    // TODO(ajohnsen): Inline the other looping.
    for (int i = start; i >= 0; i--) {
      if (startsWith(pattern, i)) return i;
    }
    return -1;
  }

  // Taken from the VM's implementation.  TODO(erikcorry): Update with a lazy
  // version once VM has that.
  Iterable<Match> allMatches(String string, [int start = 0]) {
    List<Match> result = new List<Match>();
    int length = string.length;
    int patternLength = this.length;
    int startIndex = start;
    while (true) {
      int position = string.indexOf(this, startIndex);
      if (position == -1) {
        break;
      }
      result.add(new StringMatch(position, string, this));
      int endIndex = position + patternLength;
      if (endIndex == length) {
        break;
      } else if (position == endIndex) {
        ++startIndex;  // empty match, advance and restart
      } else {
        startIndex = endIndex;
      }
    }
    return result;
  }

  Match matchAsPrefix(String string, [int start = 0]) {
    if (start < 0 || start > string.length) {
      throw new RangeError.range(start, 0, string.length);
    }
    if (start + this.length > string.length) return null;
    for (int i = 0; i < this.length; i++) {
      if (string.codeUnitAt(start + i) != this.codeUnitAt(i)) {
        return null;
      }
    }
    return new StringMatch(start, string, this);
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

  String padLeft(int width, [String padding = ' ']) {
    int delta = width - this.length;
    if (delta <= 0) return this;
    StringBuffer buffer = new StringBuffer();
    for (int i = 0; i < delta; i++) {
      buffer.write(padding);
    }
    buffer.write(this);
    return buffer.toString();
  }

  String padRight(int width, [String padding = ' ']) {
    int delta = width - this.length;
    if (delta <= 0) return this;
    StringBuffer buffer = new StringBuffer(this);
    for (int i = 0; i < delta; i++) {
      buffer.write(padding);
    }
    return buffer.toString();
  }

  bool contains(Pattern other, [int startIndex = 0]) {
    return indexOf(other, startIndex) >= 0;
  }

  String _replaceWithMatches(Iterable<Match> matches, String replace) {
    StringBuffer buffer = new StringBuffer();
    int endOfLast = 0;
    for (Match match in matches) {
      buffer.write(substring(endOfLast, match.start));
      buffer.write(replace);
      endOfLast = match.end;
    }
    buffer.write(substring(endOfLast));
    return buffer.toString();
  }

  String _replaceWithMatchesMapped(
      Iterable<Match> matches, String replace(Match)) {
    StringBuffer buffer = new StringBuffer();
    int endOfLast = 0;
    for (Match match in matches) {
      buffer.write(substring(endOfLast, match.start));
      buffer.write(replace(match));
      endOfLast = match.end;
    }
    buffer.write(substring(endOfLast));
    return buffer.toString();
  }

  replaceFirst(Pattern pattern, String replace, [int startIndex = 0]) {
    Iterator<Match> iterator = pattern.allMatches(this, startIndex).iterator;
    if (iterator.moveNext()) {
      return _replaceWithMatches([iterator.current], replace);
    }
    return this;
  }

  replaceFirstMapped(Pattern pattern, String replace(Match),
                     [int startIndex = 0]) {
    if (pattern == null) throw new ArgumentError.notNull("pattern");
    if (replace == null) throw new ArgumentError.notNull("replace");
    if (startIndex == null) throw new ArgumentError.notNull("startIndex");

    Iterator<Match> iterator = pattern.allMatches(this, startIndex).iterator;
    if (iterator.moveNext()) {
      return _replaceWithMatchesMapped([iterator.current], replace);
    }
    return this;
  }

  String replaceAll(Pattern pattern, String replace) {
    Iterable<Match> matches = pattern.allMatches(this);
    return _replaceWithMatches(matches, replace);
  }

  replaceAllMapped(Pattern pattern, String replace(Match)) {
    Iterable<Match> matches = pattern.allMatches(this);
    return _replaceWithMatchesMapped(matches, replace);
  }

  String replaceRange(int start, int end, String replacement) {
    if (end == null) end = length;
    // TODO(ajohnsen): Optimize.
    return substring(0, start) + replacement + substring(end);
  }

  List<String> split(Pattern pattern) {
    int length = this.length;
    if (pattern is String && pattern.isEmpty) {
      List<String> result = new List<String>(length);
      for (int i = 0; i < length; i++) {
        result[i] = this[i];
      }
      return result;
    }
    Iterator iterator = pattern.allMatches(this).iterator;
    if (length == 0 && iterator.moveNext()) {
      // A matched empty string input returns the empty list.
      return <String>[];
    }
    List<String> result = new List<String>();
    int startIndex = 0;
    int previousIndex = 0;
    while (true) {
      if (startIndex == length || !iterator.moveNext()) {
        result.add(this.substring(previousIndex, length));
        break;
      }
      Match match = iterator.current;
      if (match.start == length) {
        result.add(this.substring(previousIndex, length));
        break;
      }
      int endIndex = match.end;
      if (startIndex == endIndex && endIndex == previousIndex) {
        startIndex++;  // Empty match, advance and restart.
        continue;
      }
      result.add(this.substring(previousIndex, match.start));
      startIndex = previousIndex = endIndex;
    }
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
