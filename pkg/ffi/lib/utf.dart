// Copyright (c) 2015, the Fletch project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// All the code in this file is a direct copy from dart:convert. It is
// here to remove the dependency on dart:convert which will not be
// part of the library set for embedded due to its dependency on
// dart:async.

part of ffi;


/**
 * Converts the UTF-8 [codeUnits] (a list of unsigned 8-bit integers) to the
 * corresponding string.
 *
 * Uses the code units from [start] to, but no including, [end].
 * If [end] is omitted, it defaults to `codeUnits.length`.
 *
 * If the [codeUnits] start with a leading [UNICODE_BOM_CHARACTER_RUNE] this
 * character is discarded.
 */
String _decodeUtf8(List<int> codeUnits, [int start = 0, int end]) {
  int length = codeUnits.length;
  RangeError.checkValidRange(start, end, length);
  if (end == null) end = length;
  StringBuffer buffer = new StringBuffer();
  _Utf8Decoder decoder = new _Utf8Decoder(buffer, false);
  decoder.convert(codeUnits, start, end);
  decoder.close();
  return buffer.toString();
}

// UTF-8 constants.
const int _ONE_BYTE_LIMIT = 0x7f;   // 7 bits
const int _TWO_BYTE_LIMIT = 0x7ff;  // 11 bits
const int _THREE_BYTE_LIMIT = 0xffff;  // 16 bits
const int _FOUR_BYTE_LIMIT = 0x10ffff;  // 21 bits, truncated to Unicode max.

// UTF-16 constants.
const int _SURROGATE_MASK = 0xF800;
const int _SURROGATE_TAG_MASK = 0xFC00;
const int _SURROGATE_VALUE_MASK = 0x3FF;
const int _LEAD_SURROGATE_MIN = 0xD800;
const int _TAIL_SURROGATE_MIN = 0xDC00;

bool _isLeadSurrogate(int codeUnit) =>
    (codeUnit & _SURROGATE_TAG_MASK) == _LEAD_SURROGATE_MIN;
bool _isTailSurrogate(int codeUnit) =>
    (codeUnit & _SURROGATE_TAG_MASK) == _TAIL_SURROGATE_MIN;
int _combineSurrogatePair(int lead, int tail) =>
    0x10000 + ((lead & _SURROGATE_VALUE_MASK) << 10)
            | (tail & _SURROGATE_VALUE_MASK);

/**
 * Decodes UTF-8.
 *
 * The decoder handles chunked input.
 */
// TODO(floitsch): make this class public.
class _Utf8Decoder {
  final bool _allowMalformed;
  final StringSink _stringSink;
  bool _isFirstCharacter = true;
  int _value = 0;
  int _expectedUnits = 0;
  int _extraUnits = 0;

  _Utf8Decoder(this._stringSink, this._allowMalformed);

  bool get hasPartialInput => _expectedUnits > 0;

  // Limits of one through four byte encodings.
  static const List<int> _LIMITS = const <int>[
      _ONE_BYTE_LIMIT,
      _TWO_BYTE_LIMIT,
      _THREE_BYTE_LIMIT,
      _FOUR_BYTE_LIMIT ];

  void close() {
    flush();
  }

  /**
   * Flushes this decoder as if closed.
   *
   * This method throws if the input was partial and the decoder was
   * constructed with `allowMalformed` set to `false`.
   */
  void flush() {
    if (hasPartialInput) {
      if (!_allowMalformed) {
        throw new FormatException("Unfinished UTF-8 octet sequence");
      }
      _stringSink.writeCharCode(UNICODE_REPLACEMENT_CHARACTER_RUNE);
      _value = 0;
      _expectedUnits = 0;
      _extraUnits = 0;
    }
  }

  void convert(List<int> codeUnits, int startIndex, int endIndex) {
    int value = _value;
    int expectedUnits = _expectedUnits;
    int extraUnits = _extraUnits;
    _value = 0;
    _expectedUnits = 0;
    _extraUnits = 0;

    int scanOneByteCharacters(units, int from) {
      final to = endIndex;
      final mask = _ONE_BYTE_LIMIT;
      for (var i = from; i < to; i++) {
        final unit = units[i];
        if ((unit & mask) != unit) return i - from;
      }
      return to - from;
    }

    void addSingleBytes(int from, int to) {
      assert(from >= startIndex && from <= endIndex);
      assert(to >= startIndex && to <= endIndex);
      _stringSink.write(new String.fromCharCodes(codeUnits, from, to));
    }

    int i = startIndex;
    loop: while (true) {
      multibyte: if (expectedUnits > 0) {
        do {
          if (i == endIndex) {
            break loop;
          }
          int unit = codeUnits[i];
          if ((unit & 0xC0) != 0x80) {
            expectedUnits = 0;
            if (!_allowMalformed) {
              throw new FormatException(
                  "Bad UTF-8 encoding 0x${unit.toRadixString(16)}");
            }
            _isFirstCharacter = false;
            _stringSink.writeCharCode(UNICODE_REPLACEMENT_CHARACTER_RUNE);
            break multibyte;
          } else {
            value = (value << 6) | (unit & 0x3f);
            expectedUnits--;
            i++;
          }
        } while (expectedUnits > 0);
        if (value <= _LIMITS[extraUnits - 1]) {
          // Overly long encoding. The value could be encoded with a shorter
          // encoding.
          if (!_allowMalformed) {
            throw new FormatException(
                "Overlong encoding of 0x${value.toRadixString(16)}");
          }
          expectedUnits = extraUnits = 0;
          value = UNICODE_REPLACEMENT_CHARACTER_RUNE;
        }
        if (value > _FOUR_BYTE_LIMIT) {
          if (!_allowMalformed) {
            throw new FormatException("Character outside valid Unicode range: "
                                      "0x${value.toRadixString(16)}");
          }
          value = UNICODE_REPLACEMENT_CHARACTER_RUNE;
        }
        if (!_isFirstCharacter || value != UNICODE_BOM_CHARACTER_RUNE) {
          _stringSink.writeCharCode(value);
        }
        _isFirstCharacter = false;
      }

      while (i < endIndex) {
        int oneBytes = scanOneByteCharacters(codeUnits, i);
        if (oneBytes > 0) {
          _isFirstCharacter = false;
          addSingleBytes(i, i + oneBytes);
          i += oneBytes;
          if (i == endIndex) break;
        }
        int unit = codeUnits[i++];
        // TODO(floitsch): the way we test we could potentially allow
        // units that are too large, if they happen to have the
        // right bit-pattern. (Same is true for the multibyte loop above).
        // TODO(floitsch): optimize this loop. See:
        // https://codereview.chromium.org/22929022/diff/1/sdk/lib/convert/utf.dart?column_width=80
        if (unit < 0) {
          // TODO(floitsch): should this be unit <= 0 ?
          if (!_allowMalformed) {
            throw new FormatException(
                "Negative UTF-8 code unit: -0x${(-unit).toRadixString(16)}");
          }
          _stringSink.writeCharCode(UNICODE_REPLACEMENT_CHARACTER_RUNE);
        } else {
          assert(unit > _ONE_BYTE_LIMIT);
          if ((unit & 0xE0) == 0xC0) {
            value = unit & 0x1F;
            expectedUnits = extraUnits = 1;
            continue loop;
          }
          if ((unit & 0xF0) == 0xE0) {
            value = unit & 0x0F;
            expectedUnits = extraUnits = 2;
            continue loop;
          }
          // 0xF5, 0xF6 ... 0xFF never appear in valid UTF-8 sequences.
          if ((unit & 0xF8) == 0xF0 && unit < 0xF5) {
            value = unit & 0x07;
            expectedUnits = extraUnits = 3;
            continue loop;
          }
          if (!_allowMalformed) {
            throw new FormatException(
                "Bad UTF-8 encoding 0x${unit.toRadixString(16)}");
          }
          value = UNICODE_REPLACEMENT_CHARACTER_RUNE;
          expectedUnits = extraUnits = 0;
          _isFirstCharacter = false;
          _stringSink.writeCharCode(value);
        }
      }
      break loop;
    }
    if (expectedUnits > 0) {
      _value = value;
      _expectedUnits = expectedUnits;
      _extraUnits = extraUnits;
    }
  }
}
