// Copyright (c) 2015, the Dartino project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

// All the code in this file is a direct copy from dart:convert. It is
// here to remove the dependency on dart:convert which will not be
// part of the library set for embedded due to its dependency on
// dart:async.
part of dart.fletch.ffi;

/**
 * Converts [string] to its UTF-8 code units (a list of
 * unsigned 8-bit integers).
 *
 * If [start] and [end] are provided, only the substring
 * `string.substring(start, end)` is converted.
 */
List<int> _encodeUtf8(String string, [int start = 0, int end]) {
  int stringLength = string.length;
  RangeError.checkValidRange(start, end, stringLength);
  if (end == null) end = stringLength;
  int length = end - start;
  if (length == 0) return new Uint8List(0);
  // Create a new encoder with a length that is guaranteed to be big enough.
  // A single code unit uses at most 3 bytes, a surrogate pair at most 4.
  _Utf8Encoder encoder = new _Utf8Encoder.withBufferSize(length * 3);
  int endPosition = encoder._fillBuffer(string, start, end);
  assert(endPosition >= end - 1);
  if (endPosition != end) {
    // Encoding skipped the last code unit.
    // That can only happen if the last code unit is a leadsurrogate.
    // Force encoding of the lead surrogate by itself.
    int lastCodeUnit = string.codeUnitAt(end - 1);
    assert(_isLeadSurrogate(lastCodeUnit));
    // We use a non-surrogate as `nextUnit` so that _writeSurrogate just
    // writes the lead-surrogate.
    bool wasCombined = encoder._writeSurrogate(lastCodeUnit, 0);
    assert(!wasCombined);
  }
  return encoder._buffer.sublist(0, encoder._bufferIndex);
}

/** The Unicode Replacement character `U+FFFD` (�). */
const int UNICODE_REPLACEMENT_CHARACTER_RUNE = 0xFFFD;

/** The Unicode Byte Order Marker (BOM) character `U+FEFF`. */
const int UNICODE_BOM_CHARACTER_RUNE = 0xFEFF;

/**
 * This class encodes Strings to UTF-8 code units (unsigned 8 bit integers).
 */
// TODO(floitsch): make this class public.
class _Utf8Encoder {
  int _carry = 0;
  int _bufferIndex = 0;
  final List<int> _buffer;

  static const _DEFAULT_BYTE_BUFFER_SIZE = 1024;

  _Utf8Encoder() : this.withBufferSize(_DEFAULT_BYTE_BUFFER_SIZE);

  _Utf8Encoder.withBufferSize(int bufferSize)
      : _buffer = _createBuffer(bufferSize);

  /**
   * Allow an implementation to pick the most efficient way of storing bytes.
   */
  static List<int> _createBuffer(int size) => new Uint8List(size);

  /**
   * Tries to combine the given [leadingSurrogate] with the [nextCodeUnit] and
   * writes it to [_buffer].
   *
   * Returns true if the [nextCodeUnit] was combined with the
   * [leadingSurrogate]. If it wasn't then nextCodeUnit was not a trailing
   * surrogate and has not been written yet.
   *
   * It is safe to pass 0 for [nextCodeUnit] in which case only the leading
   * surrogate is written.
   */
  bool _writeSurrogate(int leadingSurrogate, int nextCodeUnit) {
    if (_isTailSurrogate(nextCodeUnit)) {
      int rune = _combineSurrogatePair(leadingSurrogate, nextCodeUnit);
      // If the rune is encoded with 2 code-units then it must be encoded
      // with 4 bytes in UTF-8.
      assert(rune > _THREE_BYTE_LIMIT);
      assert(rune <= _FOUR_BYTE_LIMIT);
      _buffer[_bufferIndex++] = 0xF0 | (rune >> 18);
      _buffer[_bufferIndex++] = 0x80 | ((rune >> 12) & 0x3f);
      _buffer[_bufferIndex++] = 0x80 | ((rune >> 6) & 0x3f);
      _buffer[_bufferIndex++] = 0x80 | (rune & 0x3f);
      return true;
    } else {
      // TODO(floitsch): allow to throw on malformed strings.
      // Encode the half-surrogate directly into UTF-8. This yields
      // invalid UTF-8, but we started out with invalid UTF-16.

      // Surrogates are always encoded in 3 bytes in UTF-8.
      _buffer[_bufferIndex++] = 0xE0 | (leadingSurrogate >> 12);
      _buffer[_bufferIndex++] = 0x80 | ((leadingSurrogate >> 6) & 0x3f);
      _buffer[_bufferIndex++] = 0x80 | (leadingSurrogate & 0x3f);
      return false;
    }
  }

  /**
   * Fills the [_buffer] with as many characters as possible.
   *
   * Does not encode any trailing lead-surrogate. This must be done by the
   * caller.
   *
   * Returns the position in the string. The returned index points to the
   * first code unit that hasn't been encoded.
   */
  int _fillBuffer(String str, int start, int end) {
    if (start != end && _isLeadSurrogate(str.codeUnitAt(end - 1))) {
      // Don't handle a trailing lead-surrogate in this loop. The caller has
      // to deal with those.
      end--;
    }
    int stringIndex;
    for (stringIndex = start; stringIndex < end; stringIndex++) {
      int codeUnit = str.codeUnitAt(stringIndex);
      // ASCII has the same representation in UTF-8 and UTF-16.
      if (codeUnit <= _ONE_BYTE_LIMIT) {
        if (_bufferIndex >= _buffer.length) break;
        _buffer[_bufferIndex++] = codeUnit;
      } else if (_isLeadSurrogate(codeUnit)) {
        if (_bufferIndex + 3 >= _buffer.length) break;
        // Note that it is safe to read the next code unit. We decremented
        // [end] above when the last valid code unit was a leading surrogate.
        int nextCodeUnit = str.codeUnitAt(stringIndex + 1);
        bool wasCombined = _writeSurrogate(codeUnit, nextCodeUnit);
        if (wasCombined) stringIndex++;
      } else {
        int rune = codeUnit;
        if (rune <= _TWO_BYTE_LIMIT) {
          if (_bufferIndex + 1 >= _buffer.length) break;
          _buffer[_bufferIndex++] = 0xC0 | (rune >> 6);
          _buffer[_bufferIndex++] = 0x80 | (rune & 0x3f);
        } else {
          assert(rune <= _THREE_BYTE_LIMIT);
          if (_bufferIndex + 2 >= _buffer.length) break;
          _buffer[_bufferIndex++] = 0xE0 | (rune >> 12);
          _buffer[_bufferIndex++] = 0x80 | ((rune >> 6) & 0x3f);
          _buffer[_bufferIndex++] = 0x80 | (rune & 0x3f);
        }
      }
    }
    return stringIndex;
  }
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

